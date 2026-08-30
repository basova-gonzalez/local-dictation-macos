import AppKit

// A floating status panel that must never become the key or main window and
// never activates the app or steals input focus. Used by the 2B spike (and
// later by the real recording overlay).
final class NonActivatingOverlayPanel: NSPanel {
    private let label = NSTextField(labelWithString: "")

    // Updates the status text of an already-visible panel without re-creating it.
    func update(text: String) {
        label.stringValue = text
    }

    init(text: String) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 64),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        // Show above all Spaces without pulling focus.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        ignoresMouseEvents = true

        label.stringValue = text
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        let container = NSVisualEffectView()
        container.material = .hudWindow
        container.state = .active
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        contentView = container
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
    }

    // The whole point of the spike: this panel can never become key or main.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func present() {
        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            setFrameOrigin(NSPoint(x: f.midX - frame.width / 2, y: f.maxY - 120))
        }
        // orderFrontRegardless shows without activating the app.
        orderFrontRegardless()
    }
}
