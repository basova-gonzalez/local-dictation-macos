import Foundation

// Where the focused element came from. Kept in Core so the fallback precedence
// is explicit and unit-testable without any Accessibility APIs.
public enum FocusCaptureSource: Sendable, Equatable {
    case systemWide
    case application
    case none
}

public enum FocusCapturePolicy {
    // The system-wide focused element is preferred. The frontmost application's
    // focused element is used ONLY as a fallback when the system-wide capture
    // produced nothing (some Electron/Chromium apps expose focus only per app).
    public static func source(systemWidePresent: Bool, applicationPresent: Bool) -> FocusCaptureSource {
        if systemWidePresent { return .systemWide }
        if applicationPresent { return .application }
        return .none
    }
}
