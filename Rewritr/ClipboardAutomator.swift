import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Foundation

enum ClipboardAutomationError: LocalizedError, Sendable {
    case accessibilityPermissionMissing
    case copyTimedOut
    case pasteTimedOut
    case emptySelection
    case unableToCreateKeyboardEvent

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionMissing:
            "Accessibility permission is required to copy and paste selected text."
        case .copyTimedOut:
            "Rewritr could not copy the selected text from the active app."
        case .pasteTimedOut:
            "Rewritr could not paste text back into the active app."
        case .emptySelection:
            "Select text before triggering rewrite."
        case .unableToCreateKeyboardEvent:
            "Rewritr could not create a keyboard automation event."
        }
    }
}

struct SelectedTextCapture: Equatable, Sendable {
    let text: String
    let sourceBundleIdentifier: String?
    let sourceProcessIdentifier: pid_t?
}

struct PasteboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    init(pasteboard: NSPasteboard = .general) {
        items = pasteboard.pasteboardItems?.map { item in
            item.types.reduce(into: [NSPasteboard.PasteboardType: Data]()) { result, type in
                result[type] = item.data(forType: type)
            }
        } ?? []
    }

    func restore(to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        guard !items.isEmpty else {
            return
        }

        let restoredItems = items.map { itemData in
            let item = NSPasteboardItem()
            itemData.forEach { type, data in
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(restoredItems)
    }
}

@MainActor
final class ClipboardAutomator {
    private let pasteboard: NSPasteboard
    private let eventPoster: KeyboardEventPosting
    private let copyTimeout: TimeInterval
    private let pasteRestoreDelayNanoseconds: UInt64

    init(
        pasteboard: NSPasteboard = .general,
        eventPoster: KeyboardEventPosting = CGKeyboardEventPoster(),
        copyTimeout: TimeInterval = 0.8,
        pasteRestoreDelayNanoseconds: UInt64 = 150_000_000
    ) {
        self.pasteboard = pasteboard
        self.eventPoster = eventPoster
        self.copyTimeout = copyTimeout
        self.pasteRestoreDelayNanoseconds = pasteRestoreDelayNanoseconds
    }

    func captureSelectedText() async throws -> SelectedTextCapture {
        guard AXIsProcessTrusted() else {
            throw ClipboardAutomationError.accessibilityPermissionMissing
        }

        let sourceApp = NSWorkspace.shared.frontmostApplication
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)
        defer {
            snapshot.restore(to: pasteboard)
        }

        pasteboard.clearContents()
        let clearedChangeCount = pasteboard.changeCount
        try eventPoster.postCommandKey(virtualKey: CGKeyCode(kVK_ANSI_C))
        let copied = try await waitForPasteboardChange(after: clearedChangeCount, timeout: copyTimeout)
        guard copied else {
            throw ClipboardAutomationError.copyTimedOut
        }

        guard let text = pasteboard.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ClipboardAutomationError.emptySelection
        }

        return SelectedTextCapture(
            text: text,
            sourceBundleIdentifier: sourceApp?.bundleIdentifier,
            sourceProcessIdentifier: sourceApp?.processIdentifier
        )
    }

    func pasteText(_ text: String) async throws {
        guard AXIsProcessTrusted() else {
            throw ClipboardAutomationError.accessibilityPermissionMissing
        }

        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        do {
            try eventPoster.postCommandKey(virtualKey: CGKeyCode(kVK_ANSI_V))
            try await Task.sleep(nanoseconds: pasteRestoreDelayNanoseconds)
            snapshot.restore(to: pasteboard)
        } catch {
            snapshot.restore(to: pasteboard)
            throw error
        }
    }

    private func waitForPasteboardChange(after changeCount: Int, timeout: TimeInterval) async throws -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            try Task.checkCancellation()
            if pasteboard.changeCount != changeCount {
                return true
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        return false
    }
}

protocol KeyboardEventPosting {
    func postCommandKey(virtualKey: CGKeyCode) throws
}

struct CGKeyboardEventPoster: KeyboardEventPosting {
    func postCommandKey(virtualKey: CGKeyCode) throws {
        let source = CGEventSource(stateID: .combinedSessionState)
        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false)
        else {
            throw ClipboardAutomationError.unableToCreateKeyboardEvent
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
