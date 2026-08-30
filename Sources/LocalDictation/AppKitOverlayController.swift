import AppKit
import LocalDictationCore

// Adapts the non-activating overlay panel to the Core OverlayPresenting role.
// Reuses a single panel and only updates its text between statuses, so it never
// re-activates the app or steals focus.
@MainActor
final class AppKitOverlayController: OverlayPresenting {
    private var panel: NonActivatingOverlayPanel?

    func show(_ status: OverlayStatus) {
        let text = "Local Dictation • " + status.label
        if let panel {
            panel.update(text: text)
        } else {
            let panel = NonActivatingOverlayPanel(text: text)
            self.panel = panel
            panel.present()
        }
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }
}
