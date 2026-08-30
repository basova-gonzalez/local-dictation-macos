@preconcurrency import AVFoundation
import Foundation
import LocalDictationCore

// Real microphone recorder for the public product flow. Records the input node
// to an app-owned temp WAV, then on finish decodes it to 16 kHz mono samples
// (WhisperKit's expected input) and deletes the file immediately, so no audio
// lingers on disk during transcription. Cancel and failure also delete the temp
// file. It is not @MainActor: the tap callback runs on a realtime audio thread
// and must capture the file locally (Swift 6 isolation), so state is guarded by
// a lock instead.
final class AudioRecorderAdapter: RecordingComponent, @unchecked Sendable {
    static let tempPrefix = "ld-rec-"

    private let lock = NSLock()
    private var currentEngine: AVAudioEngine?
    private var tapInstalled = false
    private var currentURL: URL?
    private nonisolated(unsafe) var file: AVAudioFile?
    private var cancelled = false
    private var failureDescription: String?

    static var tempDirectory: URL { FileManager.default.temporaryDirectory }

    var lastFailureDescription: String? {
        lock.lock(); defer { lock.unlock() }
        return failureDescription
    }

    func resetFailure() {
        lock.lock()
        failureDescription = nil
        lock.unlock()
    }

    func beginRecording() async throws {
        setCancelled(false)
        setFailureDescription(nil)
        let url = Self.tempDirectory.appendingPathComponent("\(Self.tempPrefix)\(UUID().uuidString).wav")
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forWriting: url, settings: format.settings)
        } catch {
            setFailureDescription("ошибка подготовки аудио")
            try? FileManager.default.removeItem(at: url)
            throw error
        }
        // Capture the file locally; never touch self on the audio thread.
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            try? audioFile.write(from: buffer)
        }
        store(url: url, file: audioFile, engine: engine)
        do {
            engine.prepare()
            try engine.start()
        } catch {
            setFailureDescription("ошибка запуска аудиодвижка")
            stopEngine()
            let (failedURL, _, failedFile) = takeCurrent()
            var fileToClose = failedFile
            Self.finalizeFileForDecoding(&fileToClose)
            if let failedURL { try? FileManager.default.removeItem(at: failedURL) }
            throw error
        }
    }

    func finishRecording() async throws -> RecordedAudio {
        stopEngine()
        let (url, wasCancelled, audioFile) = takeCurrent()
        // AVAudioFile.close() explicitly updates the header of a file opened for
        // writing. The decoder opens the same WAV immediately, so deallocation
        // at an unspecified later point is not a sufficient finalization gate.
        var fileToClose = audioFile
        Self.finalizeFileForDecoding(&fileToClose)

        guard let url, !wasCancelled else {
            if let url { try? FileManager.default.removeItem(at: url) }
            setFailureDescription("нет активной записи")
            throw ComponentFailure("recorder")
        }
        // Delete the temp audio right after decoding — no file persists into the
        // transcription/insertion stages, success or failure.
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            let samples = try AudioDecoder.decodeToFloatArray(url: url)
            return RecordedAudio(samples: samples, sampleRate: 16_000)
        } catch {
            setFailureDescription("ошибка декодирования аудио")
            throw error
        }
    }

    func cancelRecording() async {
        stopEngine()
        let (url, audioFile) = markCancelledAndTake()
        var fileToClose = audioFile
        Self.finalizeFileForDecoding(&fileToClose)
        if let url { try? FileManager.default.removeItem(at: url) }
    }

    // Synchronous lock helpers — NSLock.lock()/unlock() are unavailable directly
    // from async contexts under Swift 6.
    private func setCancelled(_ value: Bool) {
        lock.lock(); cancelled = value; lock.unlock()
    }

    private func setFailureDescription(_ value: String?) {
        lock.lock()
        failureDescription = value
        lock.unlock()
    }

    private func store(url: URL, file: AVAudioFile, engine: AVAudioEngine) {
        lock.lock()
        currentURL = url
        self.file = file
        currentEngine = engine
        tapInstalled = true
        lock.unlock()
    }

    private func takeCurrent() -> (URL?, Bool, AVAudioFile?) {
        lock.lock(); defer { lock.unlock() }
        let url = currentURL
        let wasCancelled = cancelled
        let audioFile = file
        currentURL = nil
        file = nil
        return (url, wasCancelled, audioFile)
    }

    private func markCancelledAndTake() -> (URL?, AVAudioFile?) {
        lock.lock(); defer { lock.unlock() }
        cancelled = true
        let url = currentURL
        let audioFile = file
        currentURL = nil
        file = nil
        return (url, audioFile)
    }

    private func stopEngine() {
        let (engine, hadTap): (AVAudioEngine?, Bool) = {
            lock.lock(); defer { lock.unlock() }
            let engine = currentEngine
            let hadTap = tapInstalled
            currentEngine = nil
            tapInstalled = false
            return (engine, hadTap)
        }()
        guard let engine else { return }
        // Stop the render thread before destroying its tap. Once stop returns,
        // no new buffer write should race with explicit file finalization.
        if engine.isRunning {
            engine.stop()
        }
        if hadTap {
            engine.inputNode.removeTap(onBus: 0)
        }
        engine.reset()
    }

    // Internal so the fixed app self-test exercises the exact finalization gate.
    // macOS 15 introduced explicit close for deterministic header updates.
    static func finalizeFileForDecoding(_ file: inout AVAudioFile?) {
        if #available(macOS 15.0, *) {
            file?.close()
        }
        file = nil
    }

    // Startup cleanup of provably app-owned stale recordings only (our prefix in
    // the app temp directory). Never a broad recursive sweep.
    static func cleanupStaleAudio() {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: tempDirectory,
            includingPropertiesForKeys: nil
        ) else { return }
        for url in items where url.lastPathComponent.hasPrefix(tempPrefix) && url.pathExtension == "wav" {
            try? fm.removeItem(at: url)
        }
    }
}
