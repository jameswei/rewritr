import Carbon.HIToolbox
import Foundation

enum GlobalShortcutError: LocalizedError, Sendable {
    case installHandlerFailed(OSStatus)
    case registerHotKeyFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .installHandlerFailed(let status):
            "Could not install the global shortcut handler. OSStatus: \(status)."
        case .registerHotKeyFailed(let status):
            "Could not register the global shortcut. OSStatus: \(status)."
        }
    }
}

@MainActor
final class GlobalShortcutController {
    static let defaultShortcutLabel = ShortcutConfiguration.defaultShortcut.displayName

    private var shortcut: ShortcutConfiguration
    private let onTrigger: @MainActor () -> Void
    nonisolated(unsafe) private var eventHandlerRef: EventHandlerRef?
    nonisolated(unsafe) private var hotKeyRef: EventHotKeyRef?

    var currentShortcut: ShortcutConfiguration {
        shortcut
    }

    init(
        shortcut: ShortcutConfiguration = ShortcutConfiguration.load(),
        onTrigger: @escaping @MainActor () -> Void
    ) {
        self.shortcut = shortcut
        self.onTrigger = onTrigger
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    func start() throws {
        try installHandlerIfNeeded()
        try register(shortcut)
    }

    func update(to newShortcut: ShortcutConfiguration) throws {
        guard newShortcut != shortcut else {
            return
        }
        try installHandlerIfNeeded()
        let previousHotKeyRef = hotKeyRef
        let previousShortcut = shortcut

        hotKeyRef = nil
        do {
            try register(newShortcut)
            if let previousHotKeyRef {
                UnregisterEventHotKey(previousHotKeyRef)
            }
        } catch {
            hotKeyRef = previousHotKeyRef
            shortcut = previousShortcut
            throw error
        }
    }

    private func register(_ shortcut: ShortcutConfiguration) throws {
        guard hotKeyRef == nil else {
            return
        }

        let hotKeyID = EventHotKeyID(signature: 0x72777472, id: 1)
        let hotKeyStatus = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard hotKeyStatus == noErr else {
            throw GlobalShortcutError.registerHotKeyFailed(hotKeyStatus)
        }
        self.shortcut = shortcut
    }

    private func installHandlerIfNeeded() throws {
        if eventHandlerRef != nil {
            return
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else {
                    return noErr
                }

                let controller = Unmanaged<GlobalShortcutController>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in
                    controller.handleTrigger()
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
        guard handlerStatus == noErr else {
            throw GlobalShortcutError.installHandlerFailed(handlerStatus)
        }
    }

    private func handleTrigger() {
        onTrigger()
    }
}
