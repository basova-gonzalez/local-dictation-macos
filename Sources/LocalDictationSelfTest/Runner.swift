import Foundation
import LocalDictationCore

@main
struct SelfTestRunner {
    static func main() async {
        let harness = Harness()
        checkStateMachine(harness)
        checkHotkey(harness)
        checkSettings(harness)
        checkRawTranscript(harness)
        checkPasteboardGuard(harness)
        await checkPipeline(harness)
        await checkCancellationFence(harness)
        harness.report()
    }
}

private func checkStateMachine(_ h: Harness) {
    let allowed: [[DictationState]] = [
        [.idle, .recording], [.recording, .transcribing],
        [.transcribing, .cleaning], [.cleaning, .inserting],
        [.inserting, .success], [.recording, .failure],
        [.transcribing, .failure], [.cleaning, .failure],
        [.inserting, .failure], [.recording, .idle],
        [.transcribing, .idle], [.cleaning, .idle],
        [.inserting, .idle], [.success, .idle], [.failure, .idle]
    ]
    for from in DictationState.allCases {
        for to in DictationState.allCases {
            h.check(
                "transition \(from.rawValue)->\(to.rawValue)",
                DictationStateMachine.isAllowed(from: from, to: to)
                    == allowed.contains([from, to])
            )
        }
    }
}

private func checkHotkey(_ h: Harness) {
    var classifier = HotkeyClassifier()
    h.check(
        "hold starts",
        classifier.handle(.pressed(isRepeat: false), at: 0) == [.holdStart]
    )
    h.check("hold ends", classifier.handle(.released, at: 0.5) == [.holdEnd])
    h.check("option-space valid", HotkeyCatalog.optionSpace.isValid)
    h.check("default display", HotkeyCatalog.optionSpace.displayName == "⌥ Space")
}

private func checkSettings(_ h: Harness) {
    let store = InMemorySettingsStore()
    h.check("default hotkey", store.load().hotkey == HotkeyCatalog.defaultCombo)
    store.save(AppSettings(hotkey: HotkeyCatalog.controlSpace))
    h.check("saved hotkey", store.load().hotkey == HotkeyCatalog.controlSpace)
}

private func checkRawTranscript(_ h: Harness) {
    let samples = ["привет", "новый абзац", "abc\nстрока", ""]
    for sample in samples {
        h.check(
            "byte-identical raw pass-through \(sample.count)",
            RawTranscriptPolicy.passThrough(sample) == sample
        )
    }
    h.check("empty rejected", !RawTranscriptPolicy.isInsertable(""))
    h.check("punctuation rejected", !RawTranscriptPolicy.isInsertable("… ."))
    h.check("Russian accepted", RawTranscriptPolicy.isInsertable("проверка"))
}

private func checkPasteboardGuard(_ h: Harness) {
    h.check(
        "paste allowed only for same active app and active flow",
        PasteGuard.shouldPaste(sameActiveApp: true, flowActive: true)
    )
    h.check(
        "paste blocked after app switch",
        !PasteGuard.shouldPaste(sameActiveApp: false, flowActive: true)
    )
    h.check(
        "paste blocked after flow end",
        !PasteGuard.shouldPaste(sameActiveApp: true, flowActive: false)
    )
}

@MainActor
private func checkPipeline(_ h: Harness) async {
    let recorder = SpyRecorder()
    let inserter = SpyInserter()
    let overlay = SpyOverlay()
    let coordinator = DictationCoordinator(
        recorder: recorder,
        transcriber: FixedTranscriber(text: "нейтральная проверка"),
        cleanup: PassthroughCleanup(),
        inserter: inserter,
        overlay: overlay,
        resultDisplaySeconds: 0,
        showsCleaningOverlay: false
    )
    coordinator.startHold()
    coordinator.stop()
    await coordinator.awaitQuiescence()
    h.check("pipeline settles idle", coordinator.state == .idle)
    h.check("single insertion", await inserter.insertedTexts == ["нейтральная проверка"])
    h.check("cleaning overlay hidden", !overlay.statuses.contains(.cleaning))
}

@MainActor
private func checkCancellationFence(_ h: Harness) async {
    let recorder = SpyRecorder()
    let inserter = SpyInserter()
    let coordinator = DictationCoordinator(
        recorder: recorder,
        transcriber: SlowTranscriber(delaySeconds: 0.05),
        cleanup: PassthroughCleanup(),
        inserter: inserter,
        resultDisplaySeconds: 0,
        showsCleaningOverlay: false
    )
    coordinator.startHold()
    coordinator.stop()
    try? await Task.sleep(nanoseconds: 5_000_000)
    coordinator.cancel()
    try? await Task.sleep(nanoseconds: 100_000_000)
    h.check("late transcription not inserted", await inserter.insertedTexts.isEmpty)
    h.check("cancel settles idle", coordinator.state == .idle)
}
