import Foundation
import UIKit

struct ImagenService: ImageGenerationService {
    var modelName: String { "Imagen 4" }
    var modelIcon: String { "photo.artframe" }
    var requiresAPIKey: Bool { true }
    var hasValidAPIKey: Bool {
        let key = KeychainService.read(key: "geminiAPIKey") ?? ""
        return !key.isEmpty
    }

    func generateImage(prompt: String) async throws -> Data {
        let apiKey = KeychainService.read(key: "geminiAPIKey") ?? ""
        guard !apiKey.isEmpty else {
            throw ImagenError.noAPIKey
        }

        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/imagen-4.0-generate-001:predict"
        guard let url = URL(string: urlString) else {
            throw ImagenError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let body: [String: Any] = [
            "instances": [
                ["prompt": prompt]
            ],
            "parameters": [
                "sampleCount": 1,
                "aspectRatio": "1:1"
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImagenError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ImagenError.apiError("Status \(httpResponse.statusCode): \(errorBody)")
        }

        // Imagen predict returns: { "predictions": [{ "bytesBase64Encoded": "...", "mimeType": "image/png" }] }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let predictions = json["predictions"] as? [[String: Any]],
              let first = predictions.first,
              let b64String = first["bytesBase64Encoded"] as? String,
              let imageData = Data(base64Encoded: b64String) else {
            throw ImagenError.parseError
        }

        return imageData
    }

    enum ImagenError: LocalizedError {
        case noAPIKey
        case invalidURL
        case invalidResponse
        case apiError(String)
        case parseError

        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "No Gemini API key. Add it in Settings."
            case .invalidURL: return "Invalid API URL."
            case .invalidResponse: return "Invalid server response."
            case .apiError(let msg): return msg
            case .parseError: return "Failed to parse Imagen API response."
            }
        }
    }
}
