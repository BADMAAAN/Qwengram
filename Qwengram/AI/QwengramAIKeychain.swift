import Foundation
import Security

public enum QwengramAIKeychainError: Error, Equatable {
    case invalidKey
    case operationFailed(OSStatus)
}

public enum QwengramAIKeychain {
    private static let service = "com.qwengram.ai"
    private static let qwenAPIKeyAccount = "qwen.api-key"

    public static func saveQwenAPIKey(_ key: String) throws {
        guard !key.isEmpty else {
            throw QwengramAIKeychainError.invalidKey
        }
        let query = baseQuery()
        let attributes: [String: Any] = [
            kSecValueData as String: Data(key.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            attributes.forEach { addQuery[$0.key] = $0.value }
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw QwengramAIKeychainError.operationFailed(addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw QwengramAIKeychainError.operationFailed(updateStatus)
        }
    }

    public static func loadQwenAPIKey() throws -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = result as? Data, let key = String(data: data, encoding: .utf8) else {
            throw QwengramAIKeychainError.operationFailed(status)
        }
        return key
    }

    public static func deleteQwenAPIKey() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw QwengramAIKeychainError.operationFailed(status)
        }
    }

    private static func baseQuery() -> [String: Any] {
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: qwenAPIKeyAccount,
        ]
    }
}
