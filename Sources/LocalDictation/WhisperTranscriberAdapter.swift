import Foundation
import LocalDictationCore
import WhisperKit

// Shares one in-flight asynchronous load between prewarm and the first
// dictation. The task returns Void and stores WhisperKit behind the adapter's
// lock, so the non-Sendable model object never crosses a concurrency boundary.
actor WhisperLoadSingleFlight {
    private var inFlight: Task<Void, Error>?

    func run(_ operation: @escaping @Sendable () async throws -> Void) async throws {
        if let inFlight {
            try await inFlight.value
            return
        }

        let task = Task { try await operation() }
        inFlight = task
        do {
            try await task.value
            inFlight = nil
        } catch {
            inFlight = nil
            throw error
        }
    }
}

// Content-free diagnostic only. It intentionally cannot carry an Error,
// transcript, samples, model path, dictionary contents, or any target metadata.
enum TranscriptionFailureKind: String, Sendable, Equatable {
    case noAudioSamples
    case assetsMissing
    case emptyResult
    case runtimeFailure

    var russianDescription: String {
        switch self {
        case .noAudioSamples: return "нет аудиосэмплов"
        case .assetsMissing: return "локальная модель недоступна"
        case .emptyResult: return "Whisper вернул пустой результат"
        case .runtimeFailure: return "внутренняя ошибка Whisper"
        }
    }
}

// Real WhisperKit transcriber for the public product flow. Loads exactly one
// WhisperKit instance for the app lifetime (never per dictation), forces Russian,
// and uses only the locally provisioned model —
// it never triggers a network downloader. An empty/meaningless transcript is
// rejected so the flow ends in a bounded failure and nothing is inserted.
//
// Not an actor: WhisperKit is non-Sendable, so it is held in a nonisolated
// class guarded by a lock. The coordinator
// serializes dictations, so transcription calls do not overlap.
final class WhisperTranscriberAdapter: TranscriptionComponent, @unchecked Sendable {
    enum TranscriberError: Error, Equatable {
        case noAudioSamples
        case assetsMissing
        case emptyResult
    }

    private let lock = NSLock()
    private let loadSingleFlight = WhisperLoadSingleFlight()
    private nonisolated(unsafe) var whisperKit: WhisperKit?
    private var failureKind: TranscriptionFailureKind?

    init() {}

    private func cachedInstance() -> WhisperKit? {
        lock.lock(); defer { lock.unlock() }
        return whisperKit
    }

    private func storeInstance(_ instance: WhisperKit) {
        lock.lock(); whisperKit = instance; lock.unlock()
    }

    var lastFailureDescription: String? {
        lock.lock(); defer { lock.unlock() }
        return failureKind?.russianDescription
    }

    var lastFailureKind: TranscriptionFailureKind? {
        lock.lock(); defer { lock.unlock() }
        return failureKind
    }

    func resetFailure() {
        lock.lock()
        failureKind = nil
        lock.unlock()
    }

    private func recordFailure(_ kind: TranscriptionFailureKind) {
        lock.lock(); failureKind = kind; lock.unlock()
    }

    // Loads the single instance if needed. Fails closed if local assets are
    // absent; does not fall back to a network download.
    private func ensureLoaded() async throws -> WhisperKit {
        if let instance = cachedInstance() { return instance }
        guard WhisperModelConfig.makeConfig() != nil else {
            throw TranscriberError.assetsMissing
        }
        try await loadSingleFlight.run { [self] in
            guard cachedInstance() == nil else { return }
            guard let config = WhisperModelConfig.makeConfig() else {
                throw TranscriberError.assetsMissing
            }
            let instance = try await WhisperKit(config)
            storeInstance(instance)
        }
        guard let instance = cachedInstance() else {
            throw TranscriberError.assetsMissing
        }
        return instance
    }

    // Loads and warms up the model ahead of the first user dictation.
    func prewarm() async {
        guard let instance = try? await ensureLoaded() else { return }
        let silence = [Float](repeating: 0, count: 16_000)
        _ = try? await instance.transcribe(
            audioArray: silence,
            decodeOptions: WhisperModelConfig.decodingOptions()
        )
    }

    func transcribe(_ audio: RecordedAudio) async throws -> Transcript {
        resetFailure()
        guard !audio.samples.isEmpty else {
            recordFailure(.noAudioSamples)
            throw TranscriberError.noAudioSamples
        }

        let instance: WhisperKit
        do {
            instance = try await ensureLoaded()
        } catch TranscriberError.assetsMissing {
            recordFailure(.assetsMissing)
            throw TranscriberError.assetsMissing
        } catch {
            recordFailure(.runtimeFailure)
            throw error
        }

        do {
            if let transcript = try await transcribeInsertable(
                audio: audio,
                instance: instance,
                options: WhisperModelConfig.decodingOptions()
            ) {
                return transcript
            }
        } catch {
            if Task.isCancelled || error is CancellationError {
                throw error
            }
            recordFailure(.runtimeFailure)
            throw error
        }

        recordFailure(.emptyResult)
        throw TranscriberError.emptyResult
    }

    private func transcribeInsertable(
        audio: RecordedAudio,
        instance: WhisperKit,
        options: DecodingOptions
    ) async throws -> Transcript? {
        let results = try await instance.transcribe(
            audioArray: audio.samples,
            decodeOptions: options
        )
        let text = results.map(\.text).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard RawTranscriptPolicy.isInsertable(text) else {
            return nil
        }
        return Transcript(text: text)
    }
}
