import Foundation

enum ProductCopy {
    static let positioning = "Rewritr helps non-native English speakers rewrite selected English text into smoother, more natural, native-like English while preserving the original meaning."

    static let compatibilitySummary = "Rewritr works in most macOS apps and browser text fields that support normal copy and paste. Select text, trigger rewrite, and Rewritr uses macOS clipboard automation to capture and replace it. Some secure fields, terminal sessions, remote desktops, and custom editors may not support reliable replacement."

    static let compatibilityRestrictions = [
        "You must explicitly select text before triggering rewrite.",
        "The target app must support normal Command-C and Command-V behavior for selected text.",
        "Secure fields such as password inputs should not be rewritten.",
        "Terminal support is limited because selected terminal text often refers to output/history rather than editable input.",
        "Remote desktops, virtual machines, browser-based IDEs, and apps with unusual focus handling may behave inconsistently.",
        "Clipboard managers may observe temporary clipboard changes even when Rewritr restores the clipboard afterward."
    ]
}
