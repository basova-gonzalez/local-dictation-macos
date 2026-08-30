import Foundation

// Keyboard modifier flags for a global hotkey. Stored independently of Carbon so
// the model stays testable and AppKit-free.
public struct HotkeyModifiers: OptionSet, Sendable, Equatable, Codable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    public static let command = HotkeyModifiers(rawValue: 1 << 0)
    public static let option  = HotkeyModifiers(rawValue: 1 << 1)
    public static let control = HotkeyModifiers(rawValue: 1 << 2)
    public static let shift   = HotkeyModifiers(rawValue: 1 << 3)

    public var symbolPrefix: String {
        var s = ""
        if contains(.control) { s += "⌃" }
        if contains(.option)  { s += "⌥" }
        if contains(.shift)   { s += "⇧" }
        if contains(.command) { s += "⌘" }
        return s
    }
}

// A configurable global hotkey. `virtualKey` is a Carbon virtual key value; it is
// deliberately not read from live keyboard events (see HotkeyCatalog), so the
// app needs no Input Monitoring permission and never inspects normal typing.
public struct HotkeyCombo: Sendable, Equatable, Codable {
    public let modifiers: HotkeyModifiers
    public let virtualKey: UInt32
    public let keyName: String

    public init(modifiers: HotkeyModifiers, virtualKey: UInt32, keyName: String) {
        self.modifiers = modifiers
        self.virtualKey = virtualKey
        self.keyName = keyName
    }

    public var displayName: String {
        let prefix = modifiers.symbolPrefix
        return prefix.isEmpty ? keyName : "\(prefix) \(keyName)"
    }
}

public enum HotkeyValidation: Sendable, Equatable {
    case ok
    // A plain letter/space key with no modifier would swallow ordinary typing.
    case needsModifier
}

extension HotkeyCombo {
    // Function keys are safe on their own; everything else needs a modifier so
    // the hotkey cannot capture ordinary input.
    public func validate() -> HotkeyValidation {
        if modifiers.isEmpty && !HotkeyCatalog.standaloneKeys.contains(virtualKey) {
            return .needsModifier
        }
        return .ok
    }

    public var isValid: Bool { validate() == .ok }
}

// A fixed catalog of offerable hotkeys. Choosing from a catalog (rather than
// capturing raw key events) is what lets settings verify a combo without Input
// Monitoring and without ever reading arbitrary keystrokes.
public enum HotkeyCatalog {
    // Carbon HIToolbox virtual key values.
    public static let vkSpace: UInt32 = 49
    public static let vkD: UInt32 = 2
    public static let vkR: UInt32 = 15
    public static let vkF13: UInt32 = 105

    // Keys allowed with no modifier.
    public static let standaloneKeys: Set<UInt32> = [vkF13]

    public static let optionSpace = HotkeyCombo(modifiers: [.option], virtualKey: vkSpace, keyName: "Space")
    public static let controlSpace = HotkeyCombo(modifiers: [.control], virtualKey: vkSpace, keyName: "Space")
    public static let optionCommandD = HotkeyCombo(modifiers: [.option, .command], virtualKey: vkD, keyName: "D")
    public static let optionCommandR = HotkeyCombo(modifiers: [.option, .command], virtualKey: vkR, keyName: "R")
    public static let f13 = HotkeyCombo(modifiers: [], virtualKey: vkF13, keyName: "F13")

    public static let all: [HotkeyCombo] = [optionSpace, controlSpace, optionCommandD, optionCommandR, f13]
    public static let defaultCombo = optionSpace

    // Resolves a stored combo back to a catalog entry, falling back to the
    // default if it is unknown or invalid.
    public static func resolve(_ combo: HotkeyCombo?) -> HotkeyCombo {
        guard let combo else { return defaultCombo }
        if let match = all.first(where: {
            $0.modifiers == combo.modifiers && $0.virtualKey == combo.virtualKey
        }) {
            return match
        }
        return combo.isValid ? combo : defaultCombo
    }
}
