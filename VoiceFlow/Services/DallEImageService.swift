import Foundation
import UIKit

struct DallEImageService: ImageGenerationService {
    var modelName: String { "DALL-E 3" }
    var modelIcon: String { "brain.head.profile" }
    var requiresAPIKey: Bool { true }
    var hasValidAPIKey: Bool { !Config.openAIAPIKey.isEmpty }

    func generateImage(prompt: String) async throws -> Data {
        let apiKey = Config.openAIAPIKey
        guard !apiKey.isEmpty else {
            throw DallEError.noAPIKey
        }

        guard let url = URL(string: "https://api.openai.com/v1/images/generations") else {
            throw DallEError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let body: [String: Any] = [
            "model": "dall-e-3",
            "prompt": prompt,
            "n": 1,
            "size": "1024x1024",
            "quality": "standard",
            "response_format": "b64_json"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DallEError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw DallEError.apiError("Status \(httpResponse.statusCode): \(errorBody)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]],
              let first = dataArray.first,
              let b64String = first["b64_json"] as? String,
              let imageData = Data(base64Encoded: b64String) else {
            throw DallEError.parseError
        }

        return imageData
    }

    enum DallEError: LocalizedError {
        case noAPIKey
        case invalidURL
        case invalidResponse
        case apiError(String)
        case parseError

        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "No OpenAI API key. Add it in Settings."
            case .invalidURL: return "Invalid API URL."
            case .invalidResponse: return "Invalid server response."
            case .apiError(let msg): return msg
            case .parseError: return "Failed to parse API response."
            }
        }
    }
}
