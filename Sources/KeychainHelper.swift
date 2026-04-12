import Foundation
import Security

// MARK: - Keychain Helper
// チームデータ（チームコード含む）を UserDefaults より安全な Keychain に保存するためのヘルパー

enum KeychainHelper {

    private static let service = "com.somayamada.kehai"

    // MARK: - Save
    static func save(_ data: Data, key: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        // 既存エントリを削除してから新しく保存
        SecItemDelete(query as CFDictionary)

        let attributes: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecValueData:   data
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }

    // MARK: - Load
    static func load(key: String) -> Data? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      key,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    // MARK: - Delete
    static func delete(key: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Convenience: String
    static func saveString(_ value: String, key: String) {
        guard let data = value.data(using: .utf8) else { return }
        save(data, key: key)
    }

    static func loadString(key: String) -> String? {
        guard let data = load(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
