import Foundation

enum Config {
    // MARK: - Replace with your OpenAI API key
    static let openAIAPIKey = "sk-YOUR-API-KEY-HERE"
    
    // MARK: - API Endpoints
    static let whisperEndpoint = "https://api.openai.com/v1/audio/transcriptions"
    static let ttsEndpoint = "https://api.openai.com/v1/audio/speech"
    static let chatEndpoint = "https://api.openai.com/v1/chat/completions"
    
    // MARK: - Models
    static let whisperModel = "whisper-1"
    static let ttsModel = "tts-1"
    static let chatModel = "gpt-4o-mini"
}
