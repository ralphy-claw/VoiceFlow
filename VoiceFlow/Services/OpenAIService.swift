import Foundation

enum OpenAIError: LocalizedError {
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

actor OpenAIService {
    static let shared = OpenAIService()
    
    private var apiKey: String { Config.openAIAPIKey }
    
    // MARK: - Whisper STT
    func transcribe(audioData: Data, filename: String = "audio.m4a", language: String? = nil) async throws -> String {
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: Config.whisperEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        // model field
        body.appendMultipart(boundary: boundary, name: "model", value: Config.whisperModel)
        // language field (if specified and not "auto")
        if let language = language, language != "auto", !language.isEmpty {
            body.appendMultipart(boundary: boundary, name: "language", value: language)
        }
        // file field
        let mimeType = filename.hasSuffix(".wav") ? "audio/wav" :
                        filename.hasSuffix(".mp3") ? "audio/mpeg" : "audio/m4a"
        body.appendMultipartFile(boundary: boundary, name: "file", filename: filename, mimeType: mimeType, data: audioData)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.resilientData(for: request, maxRetries: 3, timeoutInterval: 60)
        guard let http = response as? HTTPURLResponse else { throw OpenAIError.invalidResponse }
        
        if http.statusCode != 200 {
            let errBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OpenAIError.apiError("Whisper API error (\(http.statusCode)): \(errBody)")
        }
        
        let result = try JSONDecoder().decode(WhisperResponse.self, from: data)
        return result.text
    }
    
    // MARK: - TTS
    func synthesize(text: String, voice: String = "alloy") async throws -> Data {
        var request = URLRequest(url: URL(string: Config.ttsEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "model": Config.ttsModel,
            "input": text,
            "voice": voice,
            "response_format": "mp3"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.resilientData(for: request, maxRetries: 3, timeoutInterval: 30)
        guard let http = response as? HTTPURLResponse else { throw OpenAIError.invalidResponse }
        
        if http.statusCode != 200 {
            let errBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OpenAIError.apiError("TTS API error (\(http.statusCode)): \(errBody)")
        }
        
        return data
    }
    
    // MARK: - Summarize
    func summarize(text: String, systemPrompt: String? = nil) async throws -> String {
        var request = URLRequest(url: URL(string: Config.chatEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let defaultPrompt = "You are a helpful assistant. Summarize the following text concisely while keeping key points."
        
        let payload: [String: Any] = [
            "model": Config.chatModel,
            "messages": [
                ["role": "system", "content": systemPrompt ?? defaultPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.3
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.resilientData(for: request, maxRetries: 3, timeoutInterval: 30)
        guard let http = response as? HTTPURLResponse else { throw OpenAIError.invalidResponse }
        
        if http.statusCode != 200 {
            let errBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OpenAIError.apiError("Chat API error (\(http.statusCode)): \(errBody)")
        }
        
        let result = try JSONDecoder().decode(ChatResponse.self, from: data)
        return result.choices.first?.message.content ?? ""
    }
}

// MARK: - Response Models
struct WhisperResponse: Codable {
    let text: String
}

struct ChatResponse: Codable {
    let choices: [ChatChoice]
}

struct ChatChoice: Codable {
    let message: ChatMessage
}

struct ChatMessage: Codable {
    let content: String
}

// MARK: - Data Helpers
extension Data {
    mutating func appendMultipart(boundary: String, name: String, value: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }
    
    mutating func appendMultipartFile(boundary: String, name: String, filename: String, mimeType: String, data: Data) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        append(data)
        append("\r\n".data(using: .utf8)!)
    }
}
