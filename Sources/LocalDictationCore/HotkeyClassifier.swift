import Foundation

public enum HotkeyThresholds {
    // A press/release shorter than this is treated as a tap (a candidate first
    // tap of a double-press) rather than a hold-to-talk gesture.
    public static let tapMaxSeconds: TimeInterval = 0.35
    // After a tap, a second press within this window starts hands-free mode.
    public static let doublePressWindowSeconds: TimeInterval = 0.40
}

// Raw input into the classifier. `isRepeat` marks an auto-repeated key-down that
// must be ignored.
public enum HotkeyInput: Sendable, Equatable {
    case pressed(isRepeat: Bool)
    case released
    case cancelRequested
}

// The gestures the classifier emits. The driver maps these to coordinator calls.
public enum HotkeyGesture: Sendable, Equatable {
    case holdStart      // begin a provisional hold recording
    case holdEnd        // hold released after the tap threshold → process
    case holdDiscard    // released within tap threshold → provisional recording is discarded; a second press may follow
    case handsFreeStart // second tap arrived within the double-press window
    case handsFreeStop  // press while hands-free is active → process
    case cancelled
}

// Pure, deterministic gesture classifier. It takes explicit timestamps and a
// separate `timerFired` call so the double-press window can be unit-tested
// without real time. The driver owns the timer.
public struct HotkeyClassifier: Sendable, Equatable {
    public enum Phase: Sendable, Equatable {
        case inactive
        case holding
        case awaitingSecondTap
        case handsFree
    }

    public private(set) var phase: Phase = .inactive
    private var pressTime: TimeInterval = 0
    private let tapMax: TimeInterval
    private let doubleWindow: TimeInterval

    public init(
        tapMax: TimeInterval = HotkeyThresholds.tapMaxSeconds,
        doubleWindow: TimeInterval = HotkeyThresholds.doublePressWindowSeconds
    ) {
        self.tapMax = tapMax
        self.doubleWindow = doubleWindow
    }

    // Advances the classifier for one input at time `now`. Returns the gestures
    // produced (usually zero or one).
    public mutating func handle(_ input: HotkeyInput, at now: TimeInterval) -> [HotkeyGesture] {
        switch input {
        case .pressed(let isRepeat):
            if isRepeat { return [] } // key repeat is always ignored
            return handlePress(at: now)
        case .released:
            return handleRelease(at: now)
        case .cancelRequested:
            guard phase != .inactive else { return [] }
            phase = .inactive
            return [.cancelled]
        }
    }

    // Called by the driver when the double-press window elapses.
    public mutating func timerFired(at now: TimeInterval) -> [HotkeyGesture] {
        if phase == .awaitingSecondTap {
            // A lone quick tap: nothing to process, the provisional recording
            // was already discarded.
            phase = .inactive
        }
        return []
    }

    private mutating func handlePress(at now: TimeInterval) -> [HotkeyGesture] {
        switch phase {
        case .inactive:
            phase = .holding
            pressTime = now
            return [.holdStart]
        case .holding:
            // A press without an intervening release (e.g. a stray duplicate).
            return []
        case .awaitingSecondTap:
            phase = .handsFree
            return [.handsFreeStart]
        case .handsFree:
            phase = .inactive
            return [.handsFreeStop]
        }
    }

    private mutating func handleRelease(at now: TimeInterval) -> [HotkeyGesture] {
        guard phase == .holding else { return [] }
        let duration = now - pressTime
        if duration >= tapMax {
            phase = .inactive
            return [.holdEnd]
        } else {
            phase = .awaitingSecondTap
            return [.holdDiscard]
        }
    }
}
