import Foundation

// Handle for a finished recording. It carries decoded mono samples (a neutral
// value type — no AVFoundation or file path leaks into Core) so the real
// transcriber can consume them. The mock framework leaves `samples` empty.
public struct RecordedAudio: Sendable, Equatable {
    public let id: UUID
    public let samples: [Float]
    public let sampleRate: Double
    public init(id: UUID = UUID(), samples: [Float] = [], sampleRate: Double = 16_000) {
        self.id = id
        self.samples = samples
        self.sampleRate = sampleRate
    }
}

public struct Transcript: Sendable, Equatable {
    public let text: String
    public init(text: String) { self.text = text }
}

public struct CleanedText: Sendable, Equatable {
    public let text: String
    public init(text: String) { self.text = text }
}

// Error raised by mock components to exercise the failure paths.
public struct ComponentFailure: Error, Sendable, Equatable {
    public let component: String
    public init(_ component: String) { self.component = component }
}

// Content-free failure classification for UI diagnostics. It identifies only
// the pipeline boundary that failed; it never carries audio, transcript, model
// output, clipboard, target, PID, or a user path.
public enum DictationFailureStage: String, Sendable, Equatable {
    case recording
    case transcription
    case cleanup
    case insertion
}

// The coordinator depends only on these roles, never on model, network,
// AVFoundation, or Accessibility APIs. Real implementations live in the app
// target.

public protocol RecordingComponent: Sendable {
    func beginRecording() async throws
    func finishRecording() async throws -> RecordedAudio
    func cancelRecording() async
}

public protocol TranscriptionComponent: Sendable {
    func transcribe(_ audio: RecordedAudio) async throws -> Transcript
}

public protocol CleanupComponent: Sendable {
    func cleanup(_ transcript: Transcript) async throws -> CleanedText
}

public protocol InsertionComponent: Sendable {
    func insert(_ text: CleanedText) async throws
}

public enum PermissionState: String, Sendable, Equatable {
    case granted
    case denied
    case notDetermined
}

public struct PermissionsSnapshot: Sendable, Equatable {
    public let microphone: PermissionState
    public let accessibility: PermissionState
    public init(microphone: PermissionState, accessibility: PermissionState) {
        self.microphone = microphone
        self.accessibility = accessibility
    }
}

public protocol PermissionStatusProviding: Sendable {
    func snapshot() -> PermissionsSnapshot
}

// Overlay status shown to the user. It intentionally carries no transcript text.
public enum OverlayStatus: Sendable, Equatable {
    case recording(handsFree: Bool)
    case transcribing
    case cleaning
    case inserting
    case success
    case failure

    public var label: String {
        switch self {
        case .recording(let handsFree):
            return handsFree ? "Запись (hands-free)…" : "Запись…"
        case .transcribing: return "Распознавание…"
        case .cleaning: return "Очистка…"
        case .inserting: return "Вставка…"
        case .success: return "Готово"
        case .failure: return "Ошибка"
        }
    }
}

@MainActor
public protocol OverlayPresenting: AnyObject {
    func show(_ status: OverlayStatus)
    func hide()
}
