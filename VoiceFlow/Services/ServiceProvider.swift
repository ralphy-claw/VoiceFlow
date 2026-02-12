import Foundation

enum APIKeyStatus: String {
    case untested = "Untested"
    case valid = "Valid"
    case invalid = "Invalid"
    case testing = "Testing..."
}

protocol ServiceProvider: Identifiable {
    var id: String { get }
    var name: String { get }
    var iconName: String { get }
    var keychainKey: String { get }
    
    var apiKey: String? { get set }
    func validate(apiKey: String) async -> Bool
}

extension ServiceProvider {
    var apiKey: String? {
        get { KeychainService.read(key: keychainKey) }
    }
    
    var hasKey: Bool { apiKey != nil && !(apiKey?.isEmpty ?? true) }
}

class OpenAIProvider: ServiceProvider, ObservableObject {
    let id = "openai"
    let name = "OpenAI"
    let iconName = "brain.head.profile"
    let keychainKey = "openai-api-key"
    
    var apiKey: String? {
        get { KeychainService.read(key: keychainKey) }
        set {
            if let value = newValue, !value.isEmpty {
                try? KeychainService.save(key: keychainKey, value: value)
            } else {
                try? KeychainService.delete(key: keychainKey)
            }
        }
    }
    
    func validate(apiKey: String) async -> Bool {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return http.statusCode == 200
        } catch {
            return false
        }
    }
}
