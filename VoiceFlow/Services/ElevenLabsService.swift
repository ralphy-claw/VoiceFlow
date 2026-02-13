import Foundation

enum ElevenLabsError: LocalizedError {
    case invalidResponse
    case apiError(String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from server"
        case .apiError(let msg): return msg
        case .networkError(let err): return err.localizedDescription
        }
    }
}

struct ElevenLabsVoice: Codable, Identifiable {
    let voice_id: String
    let name: String
    let preview_url: String?
    let category: String?
    
    var id: String { voice_id }
}

struct VoicesResponse: Codable {
    let voices: [ElevenLabsVoice]
}

actor ElevenLabsService {
    static let shared = ElevenLabsService()
    
    private var apiKey: String {
        KeychainService.read(key: "elevenlabs-api-key") ?? ""
    }
    
    private let baseURL = "https://api.elevenlabs.io/v1"
    
    // MARK: - TTS
    func synthesize(text: String, voiceId: String = "21m00Tcm4TlvDq8ikWAM") async throws -> Data {
        let endpoint = "\(baseURL)/text-to-speech/\(voiceId)"
        guard let url = URL(string: endpoint) else {
            throw ElevenLabsError.apiError("Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "text": text,
            "model_id": "eleven_monolingual_v1",
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ElevenLabsError.invalidResponse
        }
        
        if http.statusCode != 200 {
            let errBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ElevenLabsError.apiError("ElevenLabs API error (\(http.statusCode)): \(errBody)")
        }
        
        return data
    }
    
    // MARK: - Get Voices
    func getVoices() async throws -> [ElevenLabsVoice] {
        let endpoint = "\(baseURL)/voices"
        guard let url = URL(string: endpoint) else {
            throw ElevenLabsError.apiError("Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ElevenLabsError.invalidResponse
        }
        
        if http.statusCode != 200 {
            let errBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ElevenLabsError.apiError("ElevenLabs API error (\(http.statusCode)): \(errBody)")
        }
        
        let result = try JSONDecoder().decode(VoicesResponse.self, from: data)
        return result.voices
    }
}

// MARK: - Provider Implementation

class ElevenLabsProvider: ServiceProvider, ObservableObject {
    let id = "elevenlabs"
    let name = "ElevenLabs"
    let iconName = "waveform.badge.mic"
    let keychainKey = "elevenlabs-api-key"
    
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
        // Store temporarily to test
        let oldKey = self.apiKey
        self.apiKey = apiKey
        
        do {
            _ = try await ElevenLabsService.shared.getVoices()
            return true
        } catch {
            // Restore old key if validation failed
            self.apiKey = oldKey
            return false
        }
    }
}
