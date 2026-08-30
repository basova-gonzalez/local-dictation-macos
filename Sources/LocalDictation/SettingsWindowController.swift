import AppKit
import LocalDictationCore

// Settings window: permission status/requests and hotkey selection with a
// verify-before-save step. It never resets TCC grants and only requests
// permissions on an explicit button press.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let store: SettingsStore
    private let permissions: SystemPermissionProvider
    private let hotkeyMonitor: CarbonHotkeyMonitor
    private let onHotkeyChanged: (Bool) -> Void

    private let popup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let verifyStatus = NSTextField(labelWithString: "Не проверено")
    private let saveButton = NSButton(title: "Сохранить", target: nil, action: nil)
    private let micStatus = NSTextField(labelWithString: "Микрофон: —")
    private let axStatus = NSTextField(labelWithString: "Универсальный доступ: —")

    private var candidateVerified = false

    init(
        store: SettingsStore,
        permissions: SystemPermissionProvider,
        hotkeyMonitor: CarbonHotkeyMonitor,
        onHotkeyChanged: @escaping (Bool) -> Void
    ) {
        self.store = store
        self.permissions = permissions
        self.hotkeyMonitor = hotkeyMonitor
        self.onHotkeyChanged = onHotkeyChanged
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 460),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        super.init()
        window.title = "Local Dictation — Настройки"
        window.isReleasedWhenClosed = false
        window.delegate = self
        buildUI()
    }

    func show() {
        refreshPermissions()
        selectCurrentCombo()
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

        root.addArrangedSubview(bold("Разрешения"))
        root.addArrangedSubview(NSTextField(wrappingLabelWithString:
            "Local Dictation работает только локально. Микрофон нужен во время записи; " +
            "Универсальный доступ — чтобы запоминать поле и вставлять текст без отправки."))
        root.addArrangedSubview(micStatus)
        let micButton = NSButton(title: "Запросить микрофон", target: self, action: #selector(requestMic))
        root.addArrangedSubview(micButton)
        root.addArrangedSubview(axStatus)
        let axButton = NSButton(title: "Запросить универсальный доступ", target: self, action: #selector(requestAX))
        root.addArrangedSubview(axButton)

        root.addArrangedSubview(separator())
        root.addArrangedSubview(bold("Горячая клавиша"))
        for combo in HotkeyCatalog.all {
            popup.addItem(withTitle: combo.displayName)
        }
        popup.target = self
        popup.action = #selector(comboChanged)
        root.addArrangedSubview(popup)
        let verifyButton = NSButton(title: "Проверить", target: self, action: #selector(verify))
        root.addArrangedSubview(verifyButton)
        verifyStatus.font = .systemFont(ofSize: 12)
        root.addArrangedSubview(verifyStatus)
        saveButton.target = self
        saveButton.action = #selector(saveHotkey)
        root.addArrangedSubview(saveButton)

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

    private func separator() -> NSBox {
        let b = NSBox()
        b.boxType = .separator
        b.translatesAutoresizingMaskIntoConstraints = false
        b.widthAnchor.constraint(equalToConstant: 480).isActive = true
        return b
    }

    private func selectCurrentCombo() {
        if let index = HotkeyCatalog.all.firstIndex(where: {
            $0.modifiers == hotkeyMonitor.combo.modifiers && $0.virtualKey == hotkeyMonitor.combo.virtualKey
        }) {
            popup.selectItem(at: index)
        }
        candidateVerified = false
        verifyStatus.stringValue = "Не проверено"
    }

    private var selectedCombo: HotkeyCombo {
        HotkeyCatalog.all[max(0, popup.indexOfSelectedItem)]
    }

    private func refreshPermissions() {
        let snapshot = permissions.snapshot()
        micStatus.stringValue = "Микрофон: \(snapshot.microphone.russianLabel)"
        axStatus.stringValue = "Универсальный доступ: \(snapshot.accessibility.russianLabel)"
    }

    // MARK: - Actions

    @objc private func requestMic() {
        permissions.requestMicrophone { [weak self] _ in self?.refreshPermissions() }
    }

    @objc private func requestAX() {
        permissions.requestAccessibilityPrompt()
        refreshPermissions()
    }

    @objc private func comboChanged() {
        candidateVerified = false
        verifyStatus.stringValue = "Не проверено"
        if hotkeyMonitor.isVerifying { hotkeyMonitor.cancelVerification() }
    }

    @objc private func verify() {
        let candidate = selectedCombo
        candidateVerified = false
        let started = hotkeyMonitor.beginVerification(of: candidate) { [weak self] in
            self?.candidateVerified = true
            self?.verifyStatus.stringValue = "✓ Сочетание \(candidate.displayName) сработало"
        }
        if started {
            verifyStatus.stringValue = "Нажмите \(candidate.displayName)…"
        } else {
            verifyStatus.stringValue = "⚠︎ \(candidate.displayName) недоступно (конфликт). Выберите другое."
        }
    }

    @objc private func saveHotkey() {
        let candidate = selectedCombo
        let registered = hotkeyMonitor.setCombo(candidate)
        if registered {
            store.save(AppSettings(hotkey: candidate))
            verifyStatus.stringValue = candidateVerified
                ? "Сохранено: \(candidate.displayName)"
                : "Сохранено (без проверки): \(candidate.displayName)"
        } else {
            verifyStatus.stringValue = "⚠︎ Не удалось зарегистрировать \(candidate.displayName) — конфликт."
        }
        onHotkeyChanged(registered)
    }

    func windowWillClose(_ notification: Notification) {
        if hotkeyMonitor.isVerifying {
            hotkeyMonitor.cancelVerification()
        }
    }
}
