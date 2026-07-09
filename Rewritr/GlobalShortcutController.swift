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
    static let defaultShortcutLabel = "Control+Option+R"

    private let keyCode: UInt32
    private let modifiers: UInt32
    private let onTrigger: @MainActor () -> Void
    nonisolated(unsafe) private var eventHandlerRef: EventHandlerRef?
    nonisolated(unsafe) private var hotKeyRef: EventHotKeyRef?

    init(
        keyCode: UInt32 = UInt32(kVK_ANSI_R),
        modifiers: UInt32 = UInt32(controlKey | optionKey),
        onTrigger: @escaping @MainActor () -> Void
    ) {
        self.keyCode = keyCode
        self.modifiers = modifiers
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
        if hotKeyRef != nil {
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

        let hotKeyID = EventHotKeyID(signature: 0x72777472, id: 1)
        let hotKeyStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard hotKeyStatus == noErr else {
            throw GlobalShortcutError.registerHotKeyFailed(hotKeyStatus)
        }
    }

    private func handleTrigger() {
        onTrigger()
    }
}
