import Foundation

enum Config {
    // MARK: - API Key (reads from Keychain)
    static var openAIAPIKey: String {
        KeychainService.read(key: "openai-api-key") ?? ""
    }
    
    // MARK: - API Endpoints
    static let whisperEndpoint = "https://api.openai.com/v1/audio/transcriptions"
    static let ttsEndpoint = "https://api.openai.com/v1/audio/speech"
    static let chatEndpoint = "https://api.openai.com/v1/chat/completions"
    
    // MARK: - Models
    static let whisperModel = "whisper-1"
    static let ttsModel = "tts-1"
    static let chatModel = "gpt-4o-mini"
}
