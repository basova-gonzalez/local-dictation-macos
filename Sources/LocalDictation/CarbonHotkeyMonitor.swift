import AppKit
import Carbon.HIToolbox
import LocalDictationCore

// Global hotkey monitor built on Carbon's RegisterEventHotKey. This API needs no
// Accessibility or Input Monitoring permission, does not intercept ordinary
// typing (only the registered combo is captured), and cannot synthesize keys.
// Press/release drive the pure HotkeyClassifier; the resulting gestures are
// forwarded to the coordinator. Verification temporarily registers a candidate
// combo so a new hotkey can be confirmed before it is saved.
@MainActor
final class CarbonHotkeyMonitor {
    private let signature: OSType = 0x4C444B59 // 'LDKY'
    private let mainHotkeyID: UInt32 = 1
    private let verifyHotkeyID: UInt32 = 2

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var classifier = HotkeyClassifier()
    private var doubleTimer: Timer?

    private(set) var combo: HotkeyCombo
    private let onGesture: (HotkeyGesture) -> Void

    private var verifying = false
    private var activeHotkeyID: UInt32 = 1
    private var onVerified: (() -> Void)?

    init(combo: HotkeyCombo, onGesture: @escaping (HotkeyGesture) -> Void) {
        self.combo = combo
        self.onGesture = onGesture
    }

    // Installs the shared handler and registers the current combo. Returns false
    // if the combo could not be registered (e.g. already taken system-wide) so
    // the UI can show a clear conflict state instead of silently doing nothing.
    @discardableResult
    func start() -> Bool {
        installHandlerIfNeeded()
        return register(combo, id: mainHotkeyID)
    }

    // Switches the active combo. Returns false on registration failure.
    @discardableResult
    func setCombo(_ newCombo: HotkeyCombo) -> Bool {
        verifying = false
        onVerified = nil
        unregister()
        combo = newCombo
        classifier = HotkeyClassifier()
        cancelDoubleTimer()
        return register(newCombo, id: mainHotkeyID)
    }

    var isVerifying: Bool { verifying }

    // Temporarily registers a candidate combo and reports the first press to
    // `onDetected`, without touching the coordinator. Returns false if the
    // candidate could not be registered.
    @discardableResult
    func beginVerification(of candidate: HotkeyCombo, onDetected: @escaping () -> Void) -> Bool {
        unregister()
        cancelDoubleTimer()
        verifying = true
        onVerified = onDetected
        return register(candidate, id: verifyHotkeyID)
    }

    // Ends verification and re-registers the saved main combo (unchanged).
    func cancelVerification() {
        verifying = false
        onVerified = nil
        unregister()
        _ = register(combo, id: mainHotkeyID)
    }

    func stop() {
        unregister()
        cancelDoubleTimer()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    // MARK: - Registration

    private func register(_ combo: HotkeyCombo, id: UInt32) -> Bool {
        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            combo.virtualKey,
            carbonModifiers(from: combo.modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else { return false }
        hotKeyRef = ref
        activeHotkeyID = id
        return true
    }

    private func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var specs = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]
        InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyEventHandlerUPP,
            specs.count,
            &specs,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    // MARK: - Event handling (called from the C handler on the main thread)

    fileprivate func handleCarbonEvent(kind: UInt32, id: UInt32) {
        guard id == activeHotkeyID else { return }

        if verifying {
            if kind == UInt32(kEventHotKeyPressed) { onVerified?() }
            return
        }

        let now = ProcessInfo.processInfo.systemUptime
        let gestures: [HotkeyGesture]
        if kind == UInt32(kEventHotKeyPressed) {
            gestures = classifier.handle(.pressed(isRepeat: false), at: now)
        } else if kind == UInt32(kEventHotKeyReleased) {
            gestures = classifier.handle(.released, at: now)
        } else {
            gestures = []
        }
        emit(gestures)
    }

    // Lets an on-screen action (e.g. Escape from the overlay) cancel a flow.
    func requestCancel() {
        emit(classifier.handle(.cancelRequested, at: ProcessInfo.processInfo.systemUptime))
    }

    private func emit(_ gestures: [HotkeyGesture]) {
        for gesture in gestures {
            switch gesture {
            case .holdDiscard:
                startDoubleTimer()
            case .holdEnd, .handsFreeStart, .handsFreeStop, .cancelled:
                cancelDoubleTimer()
            case .holdStart:
                break
            }
            onGesture(gesture)
        }
    }

    private func startDoubleTimer() {
        cancelDoubleTimer()
        doubleTimer = Timer.scheduledTimer(
            withTimeInterval: HotkeyThresholds.doublePressWindowSeconds,
            repeats: false
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let now = ProcessInfo.processInfo.systemUptime
                _ = self.classifier.timerFired(at: now)
            }
        }
    }

    private func cancelDoubleTimer() {
        doubleTimer?.invalidate()
        doubleTimer = nil
    }

    private func carbonModifiers(from modifiers: HotkeyModifiers) -> UInt32 {
        var result: UInt32 = 0
        if modifiers.contains(.command) { result |= UInt32(cmdKey) }
        if modifiers.contains(.option) { result |= UInt32(optionKey) }
        if modifiers.contains(.control) { result |= UInt32(controlKey) }
        if modifiers.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }
}

// C event handler. Extracts the hotkey identity and kind, then hops to the
// monitor on the main thread (Carbon hotkey events already dispatch there).
private func hotkeyEventHandlerUPP(
    _ next: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }

    var identity = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &identity
    )
    guard status == noErr else { return OSStatus(eventNotHandledErr) }

    let kind = GetEventKind(event)
    let monitor = Unmanaged<CarbonHotkeyMonitor>.fromOpaque(userData).takeUnretainedValue()
    MainActor.assumeIsolated {
        monitor.handleCarbonEvent(kind: kind, id: identity.id)
    }
    return noErr
}
