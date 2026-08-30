import Foundation
import LocalDictationCore

// Persists settings in UserDefaults under the app's suite. This lives outside
// the repository and is never committed. Unknown or invalid stored hotkeys fall
// back to the catalog default.
final class UserDefaultsSettingsStore: SettingsStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let hotkeyKey = "settings.hotkey"
    private let onboardedKey = "settings.didOnboard"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AppSettings {
        let combo: HotkeyCombo?
        if
            let data = defaults.data(forKey: hotkeyKey),
            let decoded = try? JSONDecoder().decode(HotkeyCombo.self, from: data)
        {
            combo = decoded
        } else {
            combo = nil
        }
        return AppSettings(hotkey: HotkeyCatalog.resolve(combo))
    }

    func save(_ settings: AppSettings) {
        if let data = try? JSONEncoder().encode(settings.hotkey) {
            defaults.set(data, forKey: hotkeyKey)
        }
    }

    var didOnboard: Bool {
        get { defaults.bool(forKey: onboardedKey) }
        set { defaults.set(newValue, forKey: onboardedKey) }
    }
}
