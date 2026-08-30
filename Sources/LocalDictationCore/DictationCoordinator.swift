import Foundation

public enum DictationTiming {
    // How long the success/failure overlay stays before returning to idle.
    public static let resultDisplaySeconds: TimeInterval = 1.2
}

// Drives the dictation flow through the pure state machine while delegating all
// real work to injected components. It owns no audio, model, HTTP, or
// Accessibility code. Re-entrant starts are ignored, cancellation returns to a
// consistent idle state, and any component error becomes a bounded failure that
// settles back to idle.
@MainActor
public final class DictationCoordinator {
    private var machine = DictationStateMachine()
    private var mode: DictationMode = .hold

    private let recorder: any RecordingComponent
    private let transcriber: any TranscriptionComponent
    private let cleanup: any CleanupComponent
    private let inserter: any InsertionComponent
    private weak var overlay: (any OverlayPresenting)?
    private let resultDisplaySeconds: TimeInterval
    private let showsCleaningOverlay: Bool

    private var pipelineTask: Task<Void, Never>?
    private var resetTask: Task<Void, Never>?
    private var recordingStartTask: Task<Void, Error>?
    private var stopRequested = false
    // Monotonic identity of the current flow. Bumped on every start and on
    // cancel so a late async completion from a superseded flow can never reach
    // insertion — this is deterministic and does not rely on overlay state.
    private var generation = 0

    // Fired on every state change so the menu bar can reflect the current stage.
    public var onStateChange: ((DictationState) -> Void)?

    public var state: DictationState { machine.state }
    public private(set) var lastFailureStage: DictationFailureStage?

    public init(
        recorder: any RecordingComponent,
        transcriber: any TranscriptionComponent,
        cleanup: any CleanupComponent,
        inserter: any InsertionComponent,
        overlay: (any OverlayPresenting)? = nil,
        resultDisplaySeconds: TimeInterval = DictationTiming.resultDisplaySeconds,
        showsCleaningOverlay: Bool = true
    ) {
        self.recorder = recorder
        self.transcriber = transcriber
        self.cleanup = cleanup
        self.inserter = inserter
        self.overlay = overlay
        self.resultDisplaySeconds = resultDisplaySeconds
        // Raw pass-through sets this false so no misleading "cleaning" status
        // is shown for an identity transformation.
        self.showsCleaningOverlay = showsCleaningOverlay
    }

    // MARK: - Public actions

    public func startHold() { begin(mode: .hold) }
    public func startHandsFree() { begin(mode: .handsFree) }

    // Ends a hold-to-talk press or stops a hands-free session. Both run the same
    // downstream pipeline.
    public func stop() {
        guard
            state == .recording,
            !stopRequested,
            let startTask = recordingStartTask
        else { return }
        stopRequested = true
        let gen = generation
        pipelineTask = Task {
            do {
                try await startTask.value
                guard gen == self.generation, !Task.isCancelled, self.state == .recording else { return }
                self.recordingStartTask = nil
                await self.runPipeline()
            } catch is CancellationError {
                // cancel() owns recorder settlement and the idle transition.
            } catch {
                guard gen == self.generation, !Task.isCancelled else { return }
                self.recordingStartTask = nil
                await self.fail(stage: .recording)
            }
        }
    }

    public func cancel() {
        guard state != .idle else { return }
        generation &+= 1
        let gen = generation
        let startTask = recordingStartTask
        recordingStartTask = nil
        stopRequested = false
        pipelineTask?.cancel()
        resetTask?.cancel()
        let recorder = self.recorder
        pipelineTask = Task {
            if let startTask {
                _ = try? await startTask.value
            }
            await recorder.cancelRecording()
            guard gen == self.generation else { return }
            _ = self.setState(.idle)
        }
    }

    // MARK: - Flow

    private func begin(mode: DictationMode) {
        // Re-entrancy guard: a start while a flow is active never spawns a
        // second pipeline.
        guard state == .idle else { return }
        self.mode = mode
        generation &+= 1
        lastFailureStage = nil
        stopRequested = false
        resetTask?.cancel()
        guard setState(.recording) else { return }
        let recorder = self.recorder
        let gen = generation
        let startTask = Task {
            try await recorder.beginRecording()
        }
        recordingStartTask = startTask
        pipelineTask = Task {
            do {
                try await startTask.value
            } catch {
                guard gen == self.generation else { return }
                self.recordingStartTask = nil
                await self.fail(stage: .recording)
            }
        }
    }

    private func runPipeline() async {
        let gen = generation
        do {
            let audio = try await perform(stage: .recording, generation: gen) {
                try await self.recorder.finishRecording()
            }
            guard gen == generation, !Task.isCancelled else { return }
            guard setState(.transcribing) else { return }

            let transcript = try await perform(stage: .transcription, generation: gen) {
                try await self.transcriber.transcribe(audio)
            }
            guard gen == generation, !Task.isCancelled else { return }
            guard setState(.cleaning) else { return }

            let cleaned = try await perform(stage: .cleanup, generation: gen) {
                try await self.cleanup.cleanup(transcript)
            }
            guard gen == generation, !Task.isCancelled else { return }
            guard setState(.inserting) else { return }

            try await perform(stage: .insertion, generation: gen) {
                try await self.inserter.insert(cleaned)
            }
            guard gen == generation, !Task.isCancelled else { return }
            guard setState(.success) else { return }
            scheduleReset()
        } catch is CancellationError {
            // cancel() already moved the machine to idle.
        } catch {
            // Do not surface a failure from a superseded/cancelled flow.
            guard gen == generation, !Task.isCancelled else { return }
            await fail()
        }
    }

    private func perform<T: Sendable>(
        stage: DictationFailureStage,
        generation expectedGeneration: Int,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        do {
            return try await operation()
        } catch {
            if
                !(error is CancellationError),
                expectedGeneration == generation,
                !Task.isCancelled
            {
                lastFailureStage = stage
            }
            throw error
        }
    }

    private func fail(stage: DictationFailureStage? = nil) async {
        if let stage { lastFailureStage = stage }
        guard setState(.failure) else { return }
        scheduleReset()
    }

    private func scheduleReset() {
        let seconds = resultDisplaySeconds
        resetTask = Task {
            if seconds > 0 {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            } else {
                await Task.yield()
            }
            guard !Task.isCancelled else { return }
            if self.state == .success || self.state == .failure {
                _ = self.setState(.idle)
            }
        }
    }

    @discardableResult
    private func setState(_ newState: DictationState) -> Bool {
        guard machine.transition(to: newState) else { return false }
        updateOverlay(for: newState)
        onStateChange?(newState)
        return true
    }

    private func updateOverlay(for state: DictationState) {
        switch state {
        case .idle: overlay?.hide()
        case .recording: overlay?.show(.recording(handsFree: mode == .handsFree))
        case .transcribing: overlay?.show(.transcribing)
        case .cleaning:
            // Raw pass-through shows no distinct "cleaning" status.
            if showsCleaningOverlay { overlay?.show(.cleaning) }
        case .inserting: overlay?.show(.inserting)
        case .success: overlay?.show(.success)
        case .failure: overlay?.show(.failure)
        }
    }

    // Test helper: await the current pipeline and any pending reset so callers
    // can assert the settled state deterministically (used with
    // resultDisplaySeconds == 0).
    public func awaitQuiescence() async {
        await pipelineTask?.value
        await resetTask?.value
    }
}
