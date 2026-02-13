import Foundation

enum APIKeyHelper {
    private static let appGroupID = "group.com.lubodev.voiceflow"
    
    private static var appGroupDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }
    
    /// Read API key: tries Keychain first, falls back to App Group UserDefaults
    static func readAPIKey(for keychainKey: String) -> String? {
        if let keychainValue = KeychainService.read(key: keychainKey), !keychainValue.isEmpty {
            return keychainValue
        }
        return appGroupDefaults?.string(forKey: keychainKey)
    }
    
    /// Save API key to both Keychain and App Group UserDefaults
    static func saveAPIKey(_ value: String?, for keychainKey: String) {
        if let value = value, !value.isEmpty {
            try? KeychainService.save(key: keychainKey, value: value)
            appGroupDefaults?.set(value, forKey: keychainKey)
        } else {
            try? KeychainService.delete(key: keychainKey)
            appGroupDefaults?.removeObject(forKey: keychainKey)
        }
    }
}
