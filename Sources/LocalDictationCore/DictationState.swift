import Foundation

// The dictation pipeline states. Success and failure are transient terminal
// states that return to `idle` after a short display window.
public enum DictationState: String, Sendable, Equatable, CaseIterable {
    case idle
    case recording
    case transcribing
    case cleaning
    case inserting
    case success
    case failure
}

// Whether the current flow was started by a hold-to-talk press or a hands-free
// double-press. Only affects overlay wording and how the flow is stopped.
public enum DictationMode: Sendable, Equatable {
    case hold
    case handsFree
}

// A pure, side-effect-free state machine with an explicit allowed-transition
// table. The coordinator drives the async components; this type only guards
// which state changes are legal so forbidden transitions are rejected
// deterministically and are unit-testable without any AppKit or async work.
public struct DictationStateMachine: Sendable, Equatable {
    public private(set) var state: DictationState

    public init(state: DictationState = .idle) {
        self.state = state
    }

    public static func isAllowed(from: DictationState, to: DictationState) -> Bool {
        switch (from, to) {
        // Normal forward flow.
        case (.idle, .recording): return true
        case (.recording, .transcribing): return true
        case (.transcribing, .cleaning): return true
        case (.cleaning, .inserting): return true
        case (.inserting, .success): return true
        // Any active stage can fail.
        case (.recording, .failure): return true
        case (.transcribing, .failure): return true
        case (.cleaning, .failure): return true
        case (.inserting, .failure): return true
        // Cancellation returns any active stage to a consistent idle state.
        case (.recording, .idle): return true
        case (.transcribing, .idle): return true
        case (.cleaning, .idle): return true
        case (.inserting, .idle): return true
        // Terminal display states settle back to idle.
        case (.success, .idle): return true
        case (.failure, .idle): return true
        default: return false
        }
    }

    // Attempts a transition. Returns false and leaves the state unchanged when
    // the transition is not allowed.
    @discardableResult
    public mutating func transition(to newState: DictationState) -> Bool {
        guard Self.isAllowed(from: state, to: newState) else { return false }
        state = newState
        return true
    }
}
