import AppKit
import AVFoundation
import LocalDictationCore

// Product menu-bar app. The public alpha pipeline is AVAudioEngine → WhisperKit
// → raw pass-through → Accessibility insertion. It has no LLM, shared runtime,
// history, dictionary, telemetry, or cloud dependency.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    // Hands-free auto-stop for the MVP: accumulated audio is still transcribed.
    static let handsFreeMaxSeconds: TimeInterval = 600

    private let settingsStore = UserDefaultsSettingsStore()
    private let permissions = SystemPermissionProvider()
    private let overlay = AppKitOverlayController()

    private let recorder = AudioRecorderAdapter()
    private let inserter = AccessibilityInserter()
    private lazy var transcriber = WhisperTranscriberAdapter()

    private var productCoordinator: DictationCoordinator!
    private var hotkeyMonitor: CarbonHotkeyMonitor!
    private var hotkeyRegistered = true
    private var handsFreeTimer: Timer?

    private var statusItem: NSStatusItem?
    private let stateMenuItem = NSMenuItem(title: "Состояние: ожидание", action: nil, keyEquivalent: "")
    private let insertDiagMenuItem = NSMenuItem(title: "Вставка: —", action: nil, keyEquivalent: "")
    private let hotkeyMenuItem = NSMenuItem(title: "Горячая клавиша: —", action: nil, keyEquivalent: "")
    private let micMenuItem = NSMenuItem(title: "Микрофон: —", action: nil, keyEquivalent: "")
    private let axMenuItem = NSMenuItem(title: "Универсальный доступ: —", action: nil, keyEquivalent: "")

    private var settingsController: SettingsWindowController?
    private var onboardingController: OnboardingWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Remove only provably app-owned stale recordings from a prior crash.
        AudioRecorderAdapter.cleanupStaleAudio()

        buildCoordinators()
        buildHotkey()
        buildStatusItem()
        refreshDynamicItems()

        // Load and warm the single WhisperKit instance off the UI, ahead of the
        // first dictation. Never downloads: fails quietly if assets are missing
        // (surfaced as a bounded failure when the user actually dictates).
        let transcriber = self.transcriber
        Task.detached { await transcriber.prewarm() }
        if !settingsStore.didOnboard {
            DispatchQueue.main.async { self.showOnboarding() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Quitting while recording must not leave audio behind.
        productCoordinator?.cancel()
        cancelHandsFreeTimer()
        AudioRecorderAdapter.cleanupStaleAudio()
    }

    // MARK: - Wiring

    private func buildCoordinators() {
        // Product flow: real recorder/transcriber/inserter with no text
        // post-processing, prompt, personal dictionary, or history.
        let product = DictationCoordinator(
            recorder: recorder,
            transcriber: transcriber,
            cleanup: RawPassthroughCleanup(),
            inserter: inserter,
            overlay: overlay,
            showsCleaningOverlay: false
        )
        product.onStateChange = { [weak self] state in
            guard let self else { return }
            self.stateMenuItem.title = "Состояние: \(Self.russianState(state))"
            if state != .recording { self.cancelHandsFreeTimer() }
            // Persist a safe insertion diagnostic (content-free) so a target app
            // can be classified without transcript or field data.
            if state == .success || state == .failure {
                let desc: String
                if state == .failure, let stage = self.productCoordinator.lastFailureStage {
                    desc = Self.failureDescription(
                        stage: stage,
                        recordingDescription: self.recorder.lastFailureDescription,
                        transcriptionDescription: self.transcriber.lastFailureDescription,
                        insertionDescription: self.inserter.lastResultDescription
                    )
                } else {
                    desc = self.inserter.lastResultDescription ?? "успех"
                }
                self.insertDiagMenuItem.title = "Вставка: \(desc)"
            }
            // Drop the saved target once the flow settles, so no later insert can
            // reuse a stale snapshot.
            if state == .idle { self.inserter.discardFocus() }
        }
        self.productCoordinator = product

    }

    private func buildHotkey() {
        let combo = settingsStore.load().hotkey
        let monitor = CarbonHotkeyMonitor(combo: combo) { [weak self] gesture in
            self?.handle(gesture)
        }
        hotkeyRegistered = monitor.start()
        self.hotkeyMonitor = monitor
    }

    // Hotkey gestures drive the PRODUCT flow only.
    private func handle(_ gesture: HotkeyGesture) {
        switch gesture {
        case .holdStart: startProductFlow(handsFree: false)
        case .holdEnd: productCoordinator.stop()
        case .holdDiscard: productCoordinator.cancel()
        case .handsFreeStart: startProductFlow(handsFree: true)
        case .handsFreeStop: productCoordinator.stop()
        case .cancelled: productCoordinator.cancel()
        }
    }

    // Captures focus and starts recording only with a granted Microphone
    // permission. On first use it requests the permission and does not start
    // this time.
    private func startProductFlow(handsFree: Bool) {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        guard status == .authorized else {
            if status == .notDetermined {
                permissions.requestMicrophone { [weak self] _ in self?.refreshDynamicItems() }
            }
            return
        }
        // Snapshot the target BEFORE the overlay and recording start.
        recorder.resetFailure()
        transcriber.resetFailure()
        inserter.captureFocus()
        if handsFree {
            productCoordinator.startHandsFree()
            startHandsFreeTimer()
        } else {
            productCoordinator.startHold()
        }
    }

    private func startHandsFreeTimer() {
        cancelHandsFreeTimer()
        handsFreeTimer = Timer.scheduledTimer(
            withTimeInterval: Self.handsFreeMaxSeconds,
            repeats: false
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.productCoordinator.stop() }
        }
    }

    private func cancelHandsFreeTimer() {
        handsFreeTimer?.invalidate()
        handsFreeTimer = nil
    }

    // MARK: - Menu

    private func buildStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let icon = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Local Dictation")
        icon?.isTemplate = true
        item.button?.image = icon
        item.button?.toolTip = "Local Dictation"

        let menu = NSMenu()
        menu.delegate = self

        let header = NSMenuItem(title: "Local Dictation", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(stateMenuItem)
        menu.addItem(insertDiagMenuItem)
        menu.addItem(hotkeyMenuItem)
        menu.addItem(.separator())

        micMenuItem.action = #selector(requestMicrophone)
        micMenuItem.target = self
        menu.addItem(micMenuItem)
        axMenuItem.action = #selector(requestAccessibility)
        axMenuItem.target = self
        menu.addItem(axMenuItem)
        menu.addItem(.separator())

        let onboarding = NSMenuItem(title: "Онбординг…", action: #selector(showOnboarding), keyEquivalent: "")
        onboarding.target = self
        menu.addItem(onboarding)
        let settings = NSMenuItem(title: "Настройки…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())

        menu.addItem(withTitle: "Выйти", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        item.menu = menu
        statusItem = item
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshDynamicItems()
    }

    private func refreshDynamicItems() {
        stateMenuItem.title = "Состояние: \(Self.russianState(productCoordinator.state))"
        if hotkeyRegistered {
            hotkeyMenuItem.title = "Горячая клавиша: \(hotkeyMonitor.combo.displayName)"
        } else {
            hotkeyMenuItem.title = "Горячая клавиша: \(hotkeyMonitor.combo.displayName) — конфликт, выберите другую"
        }
        let snapshot = permissions.snapshot()
        micMenuItem.title = "Микрофон: \(snapshot.microphone.russianLabel)"
        axMenuItem.title = "Универсальный доступ: \(snapshot.accessibility.russianLabel)"
    }

    // MARK: - Permissions

    @objc private func requestMicrophone() {
        let snapshot = permissions.snapshot()
        guard snapshot.microphone != .granted else { return }
        explainThenRequest(
            title: "Доступ к микрофону",
            body: "Local Dictation использует микрофон только во время явной записи диктовки. Звук не покидает Mac.",
            grantTitle: "Запросить доступ"
        ) { [weak self] in
            self?.permissions.requestMicrophone { _ in self?.refreshDynamicItems() }
        }
    }

    @objc private func requestAccessibility() {
        let snapshot = permissions.snapshot()
        guard snapshot.accessibility != .granted else { return }
        explainThenRequest(
            title: "Универсальный доступ",
            body: "Local Dictation использует Универсальный доступ, чтобы запомнить активное поле и вставить в него распознанный текст без отправки. Enter не нажимается.",
            grantTitle: "Открыть системный запрос"
        ) { [weak self] in
            self?.permissions.requestAccessibilityPrompt()
        }
    }

    private func explainThenRequest(title: String, body: String, grantTitle: String, action: @escaping () -> Void) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = body
        alert.addButton(withTitle: grantTitle)
        alert.addButton(withTitle: "Позже")
        if alert.runModal() == .alertFirstButtonReturn {
            action()
        }
    }

    // MARK: - Windows

    @objc private func showSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController(
                store: settingsStore,
                permissions: permissions,
                hotkeyMonitor: hotkeyMonitor,
                onHotkeyChanged: { [weak self] registered in
                    self?.hotkeyRegistered = registered
                    self?.refreshDynamicItems()
                }
            )
        }
        settingsController?.show()
    }

    @objc private func showOnboarding() {
        if onboardingController == nil {
            onboardingController = OnboardingWindowController(
                permissions: permissions,
                hotkeyProvider: { [weak self] in self?.hotkeyMonitor.combo.displayName ?? "—" },
                onOpenSettings: { [weak self] in self?.showSettings() },
                onFinished: { [weak self] in self?.settingsStore.didOnboard = true }
            )
        }
        onboardingController?.show()
    }

    // MARK: - Helpers

    private static func russianState(_ state: DictationState) -> String {
        switch state {
        case .idle: return "ожидание"
        case .recording: return "запись"
        case .transcribing: return "распознавание"
        case .cleaning: return "очистка"
        case .inserting: return "вставка"
        case .success: return "готово"
        case .failure: return "ошибка"
        }
    }

    private static func failureDescription(
        stage: DictationFailureStage,
        recordingDescription: String?,
        transcriptionDescription: String?,
        insertionDescription: String?
    ) -> String {
        switch stage {
        case .recording:
            return "не выполнялась — \(recordingDescription ?? "ошибка записи")"
        case .transcription:
            return "не выполнялась — \(transcriptionDescription ?? "ошибка распознавания")"
        case .cleanup:
            return "не выполнялась — ошибка очистки"
        case .insertion:
            return insertionDescription ?? "ошибка системной вставки"
        }
    }
}
