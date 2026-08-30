import Foundation
import LocalDictationCore

// Test doubles that count interactions. Recording/transcription/cleanup/insertion
// are actors so they stay Sendable while the coordinator awaits them off the main
// actor. The overlay spy is MainActor-isolated to match the protocol.

actor SpyRecorder: RecordingComponent {
    private(set) var beginCount = 0
    private(set) var finishCount = 0
    private(set) var cancelCount = 0
    let failOnBegin: Bool
    let failOnFinish: Bool

    init(failOnBegin: Bool = false, failOnFinish: Bool = false) {
        self.failOnBegin = failOnBegin
        self.failOnFinish = failOnFinish
    }

    func beginRecording() async throws {
        beginCount += 1
        if failOnBegin { throw ComponentFailure("recorder") }
    }
    func finishRecording() async throws -> RecordedAudio {
        finishCount += 1
        if failOnFinish { throw ComponentFailure("recorder") }
        return RecordedAudio()
    }
    func cancelRecording() async { cancelCount += 1 }
}

actor SlowStartRecorder: RecordingComponent {
    private(set) var beginCount = 0
    private(set) var finishCount = 0
    private(set) var cancelCount = 0
    private(set) var finishBeforeStart = false
    private(set) var cancelBeforeStart = false
    private var started = false
    let delayNanoseconds: UInt64

    init(delayNanoseconds: UInt64 = 100_000_000) {
        self.delayNanoseconds = delayNanoseconds
    }

    func beginRecording() async throws {
        beginCount += 1
        try await Task.sleep(nanoseconds: delayNanoseconds)
        started = true
    }

    func finishRecording() async throws -> RecordedAudio {
        finishCount += 1
        if !started { finishBeforeStart = true }
        started = false
        return RecordedAudio()
    }

    func cancelRecording() async {
        cancelCount += 1
        if !started { cancelBeforeStart = true }
        started = false
    }
}

actor SpyInserter: InsertionComponent {
    private(set) var insertedTexts: [String] = []
    let shouldFail: Bool

    init(shouldFail: Bool = false) { self.shouldFail = shouldFail }

    func insert(_ text: CleanedText) async throws {
        if shouldFail { throw ComponentFailure("inserter") }
        insertedTexts.append(text.text)
    }
}

@MainActor
final class SpyOverlay: OverlayPresenting {
    private(set) var statuses: [OverlayStatus] = []
    private(set) var hideCount = 0

    func show(_ status: OverlayStatus) { statuses.append(status) }
    func hide() { hideCount += 1 }
}

// Returns a fixed transcript; used to check raw pass-through end to end.
struct FixedTranscriber: TranscriptionComponent {
    let text: String
    func transcribe(_ audio: RecordedAudio) async throws -> Transcript {
        Transcript(text: text)
    }
}

// Delays before returning, without checking cancellation — simulates a late
// transcription completion that arrives after the flow was cancelled.
actor SlowTranscriber: TranscriptionComponent {
    let delaySeconds: Double
    let text: String
    private(set) var callCount = 0

    init(delaySeconds: Double, text: String = "поздний результат") {
        self.delaySeconds = delaySeconds
        self.text = text
    }

    func transcribe(_ audio: RecordedAudio) async throws -> Transcript {
        callCount += 1
        try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
        return Transcript(text: text)
    }
}

// Mirrors the app-layer RawPassthroughCleanup using the shared Core policy.
struct PassthroughCleanup: CleanupComponent {
    func cleanup(_ transcript: Transcript) async throws -> CleanedText {
        CleanedText(text: RawTranscriptPolicy.passThrough(transcript.text))
    }
}
