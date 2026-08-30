import Foundation

// Pure, testable policy for the guarded pasteboard + Cmd+V fallback.
// The actual clipboard I/O and the single Cmd+V key synthesis live in the
// app-layer (the one privacy-scan-allowlisted file); this type only encodes the
// decisions so they can be unit-tested without AppKit.

// The only key the fallback may ever synthesize. There is deliberately no case
// for Enter/Return or any other key, so an Enter chord cannot even be expressed.
public enum PasteKey: Sendable, Equatable {
    case v
}

public struct KeyChord: Sendable, Equatable {
    public let key: PasteKey
    public let command: Bool
    public init(key: PasteKey, command: Bool) {
        self.key = key
        self.command = command
    }
}

public enum PasteboardFallbackPlan {
    // The single allowed chord: Command + V.
    public static let commandV = KeyChord(key: .v, command: true)
}

public enum PasteboardRestorePolicy {
    // Restore the previous clipboard only if it still holds exactly what we
    // injected (change count unchanged AND the injected text is still present).
    // Any external clipboard change → do not restore.
    public static func shouldRestore(
        injectedChangeCount: Int,
        currentChangeCount: Int,
        currentMatchesInjected: Bool
    ) -> Bool {
        currentChangeCount == injectedChangeCount && currentMatchesInjected
    }
}

public enum PasteGuard {
    // Paste only into the same application that was frontmost before recording,
    // and only while the flow is still valid. A changed active app, a cancel, or
    // a late completion forbids the paste.
    public static func shouldPaste(sameActiveApp: Bool, flowActive: Bool) -> Bool {
        sameActiveApp && flowActive
    }
}

public enum AXInsertionPostconditionDecision: Sendable, Equatable {
    case verifiedSuccess
    case provenUnchanged
    case failClosed
}

public enum AXInsertionPostcondition {
    // Decide whether a reported AX success really changed the text. The caller
    // must keep all values in memory only; this policy never logs or persists
    // field contents or transcripts.
    public static func evaluate(
        beforeValue: String?,
        selectedRange: NSRange?,
        afterValue: String?,
        insertedText: String
    ) -> AXInsertionPostconditionDecision {
        guard
            let beforeValue,
            let selectedRange,
            let afterValue,
            let expected = expectedValue(
                beforeValue: beforeValue,
                selectedRange: selectedRange,
                insertedText: insertedText
            )
        else {
            return .failClosed
        }

        // If replacing the selected range would not visibly change the value,
        // the postcondition cannot distinguish success from no-op. Do not risk
        // a second insertion.
        guard expected != beforeValue else { return .failClosed }

        if afterValue == expected { return .verifiedSuccess }
        if afterValue == beforeValue { return .provenUnchanged }
        return .failClosed
    }

    private static func expectedValue(
        beforeValue: String,
        selectedRange: NSRange,
        insertedText: String
    ) -> String? {
        guard selectedRange.location >= 0, selectedRange.length >= 0 else {
            return nil
        }
        let value = beforeValue as NSString
        guard selectedRange.location <= value.length else { return nil }
        guard selectedRange.length <= value.length - selectedRange.location else {
            return nil
        }
        return value.replacingCharacters(in: selectedRange, with: insertedText)
    }
}
