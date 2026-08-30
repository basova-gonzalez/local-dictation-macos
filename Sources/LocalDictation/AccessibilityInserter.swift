import AppKit
import ApplicationServices
import Foundation
import LocalDictationCore

// Real insertion for the public product flow. Independent of any debug
// harness. The focused element is captured BEFORE the overlay and recording
// start; the primary path writes only the transcript into the current
// selection/cursor via Accessibility. It never synthesizes Enter, never submits,
// never activates the app, and never replaces the whole field value.
//
// When the AX path is unavailable (no focused element, e.g. Chromium/Electron,
// or the selection set is rejected), it falls back to the guarded pasteboard +
// Command+V path in PasteboardFallbackInserter. All diagnostics are content-free
// (AXError codes, capability booleans, path taken) — no transcript, field
// content, app name, or PID is logged.
final class AccessibilityInserter: InsertionComponent, @unchecked Sendable {
    private struct FocusSnapshot: @unchecked Sendable {
        let element: AXUIElement
    }

    private let lock = NSLock()
    private var snapshot: FocusSnapshot?
    private var savedAppPID: pid_t?
    private var captureDiag: String?
    private var lastResult: String?
    private static let axPostconditionDelayNanoseconds: UInt64 = 80_000_000

    // Safe, content-free description of the last insertion outcome (path taken /
    // error class). Shown in the menu to classify target apps.
    var lastResultDescription: String? {
        lock.lock(); defer { lock.unlock() }
        return lastResult
    }

    // Captures the frontmost focused element and the frontmost app identity
    // (opaque PID, in-memory only) before the overlay and recording. Clears the
    // previous result so each flow reports its own outcome.
    func captureFocus() {
        let savedPID = NSWorkspace.shared.frontmostApplication?.processIdentifier

        // Primary: system-wide focused UI element. Content-free diagnostics only.
        let systemWide = AXUIElementCreateSystemWide()
        var focusedApp: CFTypeRef?
        let appErr = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp
        )
        var focused: CFTypeRef?
        let elemErr = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focused
        )
        let systemWidePresent = (elemErr == .success && focused != nil)
        let systemWideElement: AXUIElement? = systemWidePresent ? (focused as! AXUIElement) : nil

        // Fallback A: only when system-wide produced no element, ask the
        // frontmost application's AX element for its focused element.
        var appElementError: AXError?
        var applicationElement: AXUIElement?
        if !systemWidePresent, let pid = savedPID {
            let appElement = AXUIElementCreateApplication(pid)
            var appFocused: CFTypeRef?
            let err = AXUIElementCopyAttributeValue(
                appElement,
                kAXFocusedUIElementAttribute as CFString,
                &appFocused
            )
            appElementError = err
            if err == .success, let appFocused {
                applicationElement = (appFocused as! AXUIElement)
            }
        }

        let source = FocusCapturePolicy.source(
            systemWidePresent: systemWidePresent,
            applicationPresent: applicationElement != nil
        )
        let element: AXUIElement?
        switch source {
        case .systemWide: element = systemWideElement
        case .application: element = applicationElement
        case .none: element = nil
        }

        let snap = element.map { FocusSnapshot(element: $0) }
        let diag: String?
        if element != nil {
            diag = nil
        } else {
            var s = "focus: app=\(Self.errorName(appErr))(\(appErr.rawValue)); "
                + "element=\(Self.errorName(elemErr))(\(elemErr.rawValue)); "
            if let appElementError {
                s += "appElement=\(Self.errorName(appElementError))(\(appElementError.rawValue)); "
            }
            s += "present=нет"
            diag = s
        }

        lock.lock()
        snapshot = snap
        savedAppPID = savedPID
        captureDiag = diag
        lastResult = nil
        lock.unlock()
    }

    func discardFocus() {
        lock.lock(); snapshot = nil; lock.unlock()
    }

    private func currentSnapshot() -> FocusSnapshot? {
        lock.lock(); defer { lock.unlock() }
        return snapshot
    }

    private func currentCaptureDiag() -> String? {
        lock.lock(); defer { lock.unlock() }
        return captureDiag
    }

    private func currentSavedPID() -> pid_t? {
        lock.lock(); defer { lock.unlock() }
        return savedAppPID
    }

    private func setResult(_ value: String?) {
        lock.lock(); lastResult = value; lock.unlock()
    }

    func insert(_ text: CleanedText) async throws {
        let value = text.text

        // Primary path: Accessibility insertion into the saved selection/cursor.
        if let snap = currentSnapshot() {
            let outcome: (error: AXError, selSettable: Bool, valSettable: Bool, before: AXTextReadback) = await MainActor.run {
                let selSettable = Self.isSettable(snap.element, kAXSelectedTextAttribute)
                let valSettable = Self.isSettable(snap.element, kAXValueAttribute)
                let before = Self.readTextState(snap.element)
                let error = AXUIElementSetAttributeValue(
                    snap.element,
                    kAXSelectedTextAttribute as CFString,
                    value as CFString
                )
                return (error, selSettable, valSettable, before)
            }
            if outcome.error == .success {
                try? await Task.sleep(nanoseconds: Self.axPostconditionDelayNanoseconds)
                let after = await MainActor.run { Self.readTextState(snap.element) }
                switch AXInsertionPostcondition.evaluate(
                    beforeValue: outcome.before.value,
                    selectedRange: outcome.before.selectedRange,
                    afterValue: after.value,
                    insertedText: value
                ) {
                case .verifiedSuccess:
                    setResult("успех — AX verified")
                    return
                case .provenUnchanged:
                    try await runFallback(value, reason: "после AX success/no-op")
                    return
                case .failClosed:
                    setResult("ошибка — AX postcondition")
                    throw ComponentFailure("inserter-ax-postcondition")
                }
            }
            // AX rejected the selection insert → guarded pasteboard fallback.
            let reason = "после AX \(Self.classify(outcome.error, selSettable: outcome.selSettable, valSettable: outcome.valSettable))"
            try await runFallback(value, reason: reason)
            return
        }

        // No focused element at all (e.g. Chromium/Electron) → fallback.
        let reason = "нет AX-поля [\(currentCaptureDiag() ?? "нет диагностики")]"
        try await runFallback(value, reason: reason)
    }

    private func runFallback(_ text: String, reason: String) async throws {
        let pid = currentSavedPID()
        do {
            try await PasteboardFallbackInserter.paste(text, savedAppPID: pid)
            setResult("успех — pasteboard fallback (\(reason))")
        } catch {
            setResult("ошибка — pasteboard fallback (\(reason)): \(Self.fallbackErrorName(error))")
            throw ComponentFailure("inserter-fallback")
        }
    }

    // MARK: - Safe diagnostics

    private static func isSettable(_ element: AXUIElement, _ attribute: String) -> Bool {
        var settable: DarwinBoolean = false
        let err = AXUIElementIsAttributeSettable(element, attribute as CFString, &settable)
        return err == .success && settable.boolValue
    }

    private struct AXTextReadback: Sendable {
        let value: String?
        let selectedRange: NSRange?
    }

    private static func readTextState(_ element: AXUIElement) -> AXTextReadback {
        var valueRef: CFTypeRef?
        let valueErr = AXUIElementCopyAttributeValue(
            element,
            kAXValueAttribute as CFString,
            &valueRef
        )
        let value = (valueErr == .success) ? (valueRef as? String) : nil

        var rangeRef: CFTypeRef?
        let rangeErr = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &rangeRef
        )
        let selectedRange: NSRange?
        if rangeErr == .success,
           let rawRange = rangeRef,
           CFGetTypeID(rawRange) == AXValueGetTypeID() {
            let rangeValue = rawRange as! AXValue
            var cfRange = CFRange()
            if AXValueGetType(rangeValue) == .cfRange,
               AXValueGetValue(rangeValue, .cfRange, &cfRange) {
                selectedRange = NSRange(location: cfRange.location, length: cfRange.length)
            } else {
                selectedRange = nil
            }
        } else {
            selectedRange = nil
        }

        return AXTextReadback(value: value, selectedRange: selectedRange)
    }

    private static func classify(_ error: AXError, selSettable: Bool, valSettable: Bool) -> String {
        let sel = selSettable ? "settable" : "no"
        let val = valSettable ? "settable" : "no"
        return "\(errorName(error))(\(error.rawValue)); selectedText=\(sel); value=\(val)"
    }

    private static func fallbackErrorName(_ error: Error) -> String {
        if let e = error as? PasteboardFallbackInserter.FallbackError {
            switch e {
            case .activeAppChanged: return "активное приложение изменилось"
            case .guardFailed: return "guard"
            }
        }
        return "ошибка"
    }

    private static func errorName(_ error: AXError) -> String {
        switch error {
        case .success: return "success"
        case .failure: return "failure"
        case .illegalArgument: return "illegalArgument"
        case .invalidUIElement: return "invalidUIElement"
        case .invalidUIElementObserver: return "invalidUIElementObserver"
        case .cannotComplete: return "cannotComplete"
        case .attributeUnsupported: return "attributeUnsupported"
        case .actionUnsupported: return "actionUnsupported"
        case .notificationUnsupported: return "notificationUnsupported"
        case .notImplemented: return "notImplemented"
        case .notificationAlreadyRegistered: return "notificationAlreadyRegistered"
        case .notificationNotRegistered: return "notificationNotRegistered"
        case .apiDisabled: return "apiDisabled"
        case .noValue: return "noValue"
        case .parameterizedAttributeUnsupported: return "parameterizedAttributeUnsupported"
        case .notEnoughPrecision: return "notEnoughPrecision"
        @unknown default: return "unknown"
        }
    }
}
