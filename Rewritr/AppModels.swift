import Foundation
import Carbon.HIToolbox
import AppKit

extension Notification.Name {
    static let rewritrShortcutDidChange = Notification.Name("RewritrShortcutDidChange")
    static let rewritrShortcutRegistrationFailed = Notification.Name("RewritrShortcutRegistrationFailed")
}

enum RewriteBehavior: String, CaseIterable, Identifiable, Sendable {
    case previewBeforeReplacing
    case replaceInstantly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .previewBeforeReplacing:
            "Preview before replacing"
        case .replaceInstantly:
            "Replace instantly"
        }
    }
}

struct ShortcutConfiguration: Equatable, Sendable {
    static let defaultShortcut = ShortcutConfiguration(
        keyCode: UInt32(kVK_ANSI_R),
        modifiers: UInt32(controlKey | optionKey)
    )

    let keyCode: UInt32
    let modifiers: UInt32

    var displayName: String {
        let modifierNames: [(UInt32, String)] = [
            (UInt32(controlKey), "Control"),
            (UInt32(optionKey), "Option"),
            (UInt32(shiftKey), "Shift"),
            (UInt32(cmdKey), "Command")
        ]
        let parts = modifierNames.compactMap { flag, name in
            modifiers & flag != 0 ? name : nil
        }
        return (parts + [Self.keyName(for: keyCode)]).joined(separator: "+")
    }

    var isValid: Bool {
        keyCode > 0 && modifiersContainRequiredModifier
    }

    private var modifiersContainRequiredModifier: Bool {
        modifiers & UInt32(controlKey | optionKey | shiftKey | cmdKey) != 0
    }

    static func load(from defaults: UserDefaults = .standard) -> ShortcutConfiguration {
        guard
            defaults.object(forKey: SettingsKey.shortcutKeyCode) != nil,
            defaults.object(forKey: SettingsKey.shortcutModifiers) != nil
        else {
            return .defaultShortcut
        }

        let shortcut = ShortcutConfiguration(
            keyCode: UInt32(defaults.integer(forKey: SettingsKey.shortcutKeyCode)),
            modifiers: UInt32(defaults.integer(forKey: SettingsKey.shortcutModifiers))
        )
        return shortcut.isValid ? shortcut : .defaultShortcut
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(Int(keyCode), forKey: SettingsKey.shortcutKeyCode)
        defaults.set(Int(modifiers), forKey: SettingsKey.shortcutModifiers)
        defaults.set(displayName, forKey: SettingsKey.globalShortcutLabel)
    }

    static func fromEvent(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) -> ShortcutConfiguration? {
        var modifiers: UInt32 = 0
        if modifierFlags.contains(.control) {
            modifiers |= UInt32(controlKey)
        }
        if modifierFlags.contains(.option) {
            modifiers |= UInt32(optionKey)
        }
        if modifierFlags.contains(.shift) {
            modifiers |= UInt32(shiftKey)
        }
        if modifierFlags.contains(.command) {
            modifiers |= UInt32(cmdKey)
        }

        let shortcut = ShortcutConfiguration(keyCode: UInt32(keyCode), modifiers: modifiers)
        return shortcut.isValid ? shortcut : nil
    }

    private static func keyName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: "A"
        case kVK_ANSI_B: "B"
        case kVK_ANSI_C: "C"
        case kVK_ANSI_D: "D"
        case kVK_ANSI_E: "E"
        case kVK_ANSI_F: "F"
        case kVK_ANSI_G: "G"
        case kVK_ANSI_H: "H"
        case kVK_ANSI_I: "I"
        case kVK_ANSI_J: "J"
        case kVK_ANSI_K: "K"
        case kVK_ANSI_L: "L"
        case kVK_ANSI_M: "M"
        case kVK_ANSI_N: "N"
        case kVK_ANSI_O: "O"
        case kVK_ANSI_P: "P"
        case kVK_ANSI_Q: "Q"
        case kVK_ANSI_R: "R"
        case kVK_ANSI_S: "S"
        case kVK_ANSI_T: "T"
        case kVK_ANSI_U: "U"
        case kVK_ANSI_V: "V"
        case kVK_ANSI_W: "W"
        case kVK_ANSI_X: "X"
        case kVK_ANSI_Y: "Y"
        case kVK_ANSI_Z: "Z"
        case kVK_ANSI_0: "0"
        case kVK_ANSI_1: "1"
        case kVK_ANSI_2: "2"
        case kVK_ANSI_3: "3"
        case kVK_ANSI_4: "4"
        case kVK_ANSI_5: "5"
        case kVK_ANSI_6: "6"
        case kVK_ANSI_7: "7"
        case kVK_ANSI_8: "8"
        case kVK_ANSI_9: "9"
        case kVK_Space: "Space"
        case kVK_Escape: "Esc"
        case kVK_Return: "Return"
        case kVK_Tab: "Tab"
        case kVK_Delete: "Delete"
        case kVK_ForwardDelete: "Forward Delete"
        case kVK_LeftArrow: "Left Arrow"
        case kVK_RightArrow: "Right Arrow"
        case kVK_UpArrow: "Up Arrow"
        case kVK_DownArrow: "Down Arrow"
        default: "Key \(keyCode)"
        }
    }
}

struct ProviderConfig: Equatable, Sendable {
    static let apiKeyKeychainID = "default-api-key"

    let baseURL: String
    let model: String
    let apiKeyKeychainID: String
    let timeoutSeconds: Int

    var chatCompletionsURL: URL? {
        Self.chatCompletionsURL(from: baseURL)
    }

    var validationErrors: [String] {
        var errors: [String] = []

        if baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Provider URL is required.")
        } else if chatCompletionsURL == nil {
            errors.append("Provider URL must be a valid URL.")
        }

        if model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Model is required.")
        }

        if apiKeyKeychainID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("API key reference is required.")
        }

        if timeoutSeconds < 5 || timeoutSeconds > 60 {
            errors.append("Timeout must be between 5 and 60 seconds.")
        }

        return errors
    }

    static func chatCompletionsURL(from baseURL: String) -> URL? {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let components = URLComponents(string: trimmed) else {
            return nil
        }

        guard components.scheme != nil, components.host != nil else {
            return nil
        }

        return components.url
    }
}

enum RewriteMode: String, Sendable {
    case refine
}

struct RewriteRequest: Equatable, Sendable {
    let inputText: String
    let mode: RewriteMode
    let behavior: RewriteBehavior
    let allowsLongRewrite: Bool

    init(
        inputText: String,
        mode: RewriteMode = .refine,
        behavior: RewriteBehavior,
        allowsLongRewrite: Bool = false
    ) {
        self.inputText = inputText
        self.mode = mode
        self.behavior = behavior
        self.allowsLongRewrite = allowsLongRewrite
    }
}

struct RewriteResult: Equatable, Sendable {
    let refinedText: String
}

enum RewriteLengthPolicy {
    static let previewWarningWordCount = 4_000
    static let instantWarningWordCount = 2_000

    static func wordCount(in text: String) -> Int {
        text
            .split { $0.isWhitespace || $0.isNewline }
            .count
    }

    static func warningThreshold(for behavior: RewriteBehavior) -> Int {
        switch behavior {
        case .previewBeforeReplacing:
            previewWarningWordCount
        case .replaceInstantly:
            instantWarningWordCount
        }
    }

    static func requiresWarning(wordCount: Int, behavior: RewriteBehavior) -> Bool {
        wordCount >= warningThreshold(for: behavior)
    }
}
