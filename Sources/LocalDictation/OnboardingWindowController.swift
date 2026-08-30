import AppKit
import LocalDictationCore

// First-run onboarding. Explains the purpose of each permission before any
// system prompt, shows current status, and points to Settings for the hotkey.
// It never opens System Settings on its own and never resets grants.
@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let permissions: SystemPermissionProvider
    private let hotkeyProvider: () -> String
    private let onOpenSettings: () -> Void
    private let onFinished: () -> Void

    private let micStatus = NSTextField(labelWithString: "Микрофон: —")
    private let axStatus = NSTextField(labelWithString: "Универсальный доступ: —")
    private let hotkeyLine = NSTextField(labelWithString: "Горячая клавиша: —")

    init(
        permissions: SystemPermissionProvider,
        hotkeyProvider: @escaping () -> String,
        onOpenSettings: @escaping () -> Void,
        onFinished: @escaping () -> Void
    ) {
        self.permissions = permissions
        self.hotkeyProvider = hotkeyProvider
        self.onOpenSettings = onOpenSettings
        self.onFinished = onFinished
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 460),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        super.init()
        window.title = "Local Dictation — Первый запуск"
        window.isReleasedWhenClosed = false
        window.delegate = self
        buildUI()
    }

    func show() {
        refresh()
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildUI() {
        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 10
        root.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        root.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "Добро пожаловать в Local Dictation")
        title.font = .boldSystemFont(ofSize: 16)
        root.addArrangedSubview(title)
        root.addArrangedSubview(NSTextField(wrappingLabelWithString:
            "Это локальная диктовка: речь и текст не покидают Mac. Сейчас идёт Этап 3 — интерфейс работает на mock-компонентах, реальная запись и вставка ещё не подключены."))

        root.addArrangedSubview(bold("Что понадобится"))
        root.addArrangedSubview(NSTextField(wrappingLabelWithString:
            "• Микрофон — только во время явной записи диктовки.\n" +
            "• Универсальный доступ — чтобы запомнить активное поле и вставить текст без отправки (на следующих этапах).\n" +
            "Оба разрешения запрашиваются только по вашему действию, никакие настройки не сбрасываются."))
        root.addArrangedSubview(micStatus)
        let micButton = NSButton(title: "Запросить микрофон", target: self, action: #selector(requestMic))
        root.addArrangedSubview(micButton)
        root.addArrangedSubview(axStatus)
        let axButton = NSButton(title: "Запросить универсальный доступ", target: self, action: #selector(requestAX))
        root.addArrangedSubview(axButton)

        root.addArrangedSubview(bold("Горячая клавиша"))
        root.addArrangedSubview(hotkeyLine)
        root.addArrangedSubview(NSTextField(wrappingLabelWithString:
            "Удержание — короткая диктовка. Двойное нажатие — hands-free, повторное нажатие завершает. Сочетание можно изменить и проверить в настройках."))
        let settingsButton = NSButton(title: "Открыть настройки…", target: self, action: #selector(openSettings))
        root.addArrangedSubview(settingsButton)

        let done = NSButton(title: "Готово", target: self, action: #selector(finish))
        done.keyEquivalent = "\r"
        root.addArrangedSubview(done)

        let container = NSView()
        container.addSubview(root)
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: container.topAnchor),
            root.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            root.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])
        window.contentView = container
    }

    private func bold(_ s: String) -> NSTextField {
        let t = NSTextField(labelWithString: s)
        t.font = .boldSystemFont(ofSize: 13)
        return t
    }

    private func refresh() {
        let snapshot = permissions.snapshot()
        micStatus.stringValue = "Микрофон: \(snapshot.microphone.russianLabel)"
        axStatus.stringValue = "Универсальный доступ: \(snapshot.accessibility.russianLabel)"
        hotkeyLine.stringValue = "Горячая клавиша: \(hotkeyProvider())"
    }

    @objc private func requestMic() {
        permissions.requestMicrophone { [weak self] _ in self?.refresh() }
    }

    @objc private func requestAX() {
        permissions.requestAccessibilityPrompt()
        refresh()
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func finish() {
        onFinished()
        window.close()
    }

    func windowWillClose(_ notification: Notification) {
        onFinished()
    }
}
