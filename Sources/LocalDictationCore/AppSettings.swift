import Foundation

// User-configurable settings. Persisted outside the repository (UserDefaults in
// the app target); never committed.
public struct AppSettings: Sendable, Equatable, Codable {
    public var hotkey: HotkeyCombo

    public init(hotkey: HotkeyCombo = HotkeyCatalog.defaultCombo) {
        self.hotkey = hotkey
    }
}

public protocol SettingsStore: AnyObject, Sendable {
    func load() -> AppSettings
    func save(_ settings: AppSettings)
}

// In-memory store for tests.
public final class InMemorySettingsStore: SettingsStore, @unchecked Sendable {
    private var settings: AppSettings
    private let lock = NSLock()

    public init(_ settings: AppSettings = AppSettings()) {
        self.settings = settings
    }

    public func load() -> AppSettings {
        lock.lock(); defer { lock.unlock() }
        return settings
    }

    public func save(_ settings: AppSettings) {
        lock.lock(); defer { lock.unlock() }
        self.settings = settings
    }
}
