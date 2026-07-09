import Foundation
import Security

enum KeychainError: LocalizedError {
    case unhandledStatus(OSStatus)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .unhandledStatus(let status):
            "Keychain operation failed with status \(status)."
        case .invalidData:
            "Stored Keychain data was invalid."
        }
    }
}

struct KeychainStore: Sendable {
    private let service: String

    init(service: String = Bundle.main.bundleIdentifier ?? "space.lifeplayer.rewritr") {
        self.service = service
    }

    func read(account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainError.unhandledStatus(status)
        }

        guard let data = item as? Data, let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return value
    }

    func save(_ value: String, account: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let update: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        guard updateStatus == errSecItemNotFound else {
            throw KeychainError.unhandledStatus(updateStatus)
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError.unhandledStatus(addStatus)
        }
    }
}
