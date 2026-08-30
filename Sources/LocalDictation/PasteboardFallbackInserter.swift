import AppKit
import CoreGraphics
import Foundation
import LocalDictationCore

// ALLOWLISTED FILE (privacy-scan.sh): this is the only place event synthesis is
// permitted, and only for the exact Command+V chord. No other key — in
// particular no submit/newline key — is ever synthesized here. This file must
// not gain a general key-synthesis API.
//
// Guarded pasteboard fallback used ONLY when the Accessibility insertion path is
// unavailable. It: verifies the same application that was frontmost before
// recording is still active, saves the previous clipboard, writes only the
// injected text, synthesizes exactly one Command+V down/up pair, then after a
// bounded delay restores the previous clipboard only if nothing external changed
// it. It logs nothing about the transcript, clipboard, app, or PID.
@MainActor
enum PasteboardFallbackInserter {
    enum FallbackError: Error, Equatable {
        case activeAppChanged
        case guardFailed
    }

    // Bounded delay to let the target app consume the paste before restoring.
    static let pasteSettleSeconds: TimeInterval = 0.4

    static func paste(_ text: String, savedAppPID: pid_t?) async throws {
        let sameApp = (savedAppPID != nil)
            && (savedAppPID == NSWorkspace.shared.frontmostApplication?.processIdentifier)
        guard PasteGuard.shouldPaste(sameActiveApp: sameApp, flowActive: true) else {
            throw FallbackError.activeAppChanged
        }

        let pasteboard = NSPasteboard.general
        let savedItems = snapshotItems(pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let injectedChangeCount = pasteboard.changeCount

        // Re-verify the same app is active immediately before synthesizing the
        // keystroke; if it changed, restore and abort without pasting.
        guard savedAppPID == NSWorkspace.shared.frontmostApplication?.processIdentifier else {
            restoreIfUnchanged(pasteboard, savedItems, injectedChangeCount: injectedChangeCount, injectedText: text)
            throw FallbackError.activeAppChanged
        }

        synthesizeCommandV()

        try? await Task.sleep(nanoseconds: UInt64(pasteSettleSeconds * 1_000_000_000))
        restoreIfUnchanged(pasteboard, savedItems, injectedChangeCount: injectedChangeCount, injectedText: text)
    }

    // MARK: - Clipboard save/restore

    private static func snapshotItems(_ pasteboard: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
        (pasteboard.pasteboardItems ?? []).map { item in
            var stored: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { stored[type] = data }
            }
            return stored
        }
    }

    private static func restoreIfUnchanged(
        _ pasteboard: NSPasteboard,
        _ savedItems: [[NSPasteboard.PasteboardType: Data]],
        injectedChangeCount: Int,
        injectedText: String
    ) {
        let currentMatches = (pasteboard.string(forType: .string) == injectedText)
        guard PasteboardRestorePolicy.shouldRestore(
            injectedChangeCount: injectedChangeCount,
            currentChangeCount: pasteboard.changeCount,
            currentMatchesInjected: currentMatches
        ) else {
            return // external clipboard change → restore nothing
        }
        pasteboard.clearContents()
        for stored in savedItems {
            let item = NSPasteboardItem()
            for (type, data) in stored { item.setData(data, forType: type) }
            pasteboard.writeObjects([item])
        }
    }

    // MARK: - The single permitted synthesis: Command + V

    private static func synthesizeCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let pasteVirtualKey: CGKeyCode = 9 // 'v'
        let down = CGEvent(keyboardEventSource: source, virtualKey: pasteVirtualKey, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: source, virtualKey: pasteVirtualKey, keyDown: false)
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
