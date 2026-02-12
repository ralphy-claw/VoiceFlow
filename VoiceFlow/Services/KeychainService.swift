import Foundation
import Security

enum KeychainService {
    
    enum KeychainError: LocalizedError {
        case saveFailed(OSStatus)
        case readFailed(OSStatus)
        case deleteFailed(OSStatus)
        case unexpectedData
        
        var errorDescription: String? {
            switch self {
            case .saveFailed(let s): return "Keychain save failed: \(s)"
            case .readFailed(let s): return "Keychain read failed: \(s)"
            case .deleteFailed(let s): return "Keychain delete failed: \(s)"
            case .unexpectedData: return "Unexpected keychain data"
            }
        }
    }
    
    private static let serviceName = "com.voiceflow.apikeys"
    private static let accessGroup = "79NK8S894T.com.lubodev.voiceflow.shared"
    
    static func save(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else { return }
        
        // Delete existing first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecAttrAccessGroup as String: accessGroup
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessGroup as String: accessGroup,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.saveFailed(status) }
    }
    
    static func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecAttrAccessGroup as String: accessGroup,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }
    
    static func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecAttrAccessGroup as String: accessGroup
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}
