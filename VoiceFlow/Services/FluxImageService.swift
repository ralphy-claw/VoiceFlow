import Foundation
import UIKit

struct FluxImageService: ImageGenerationService {
    var modelName: String { "Flux" }
    var modelIcon: String { "bolt.fill" }
    var requiresAPIKey: Bool { true }
    var hasValidAPIKey: Bool {
        let key = KeychainService.read(key: "falAPIKey") ?? ""
        return !key.isEmpty
    }

    func generateImage(prompt: String) async throws -> Data {
        let apiKey = KeychainService.read(key: "falAPIKey") ?? ""
        guard !apiKey.isEmpty else {
            throw FluxError.noAPIKey
        }

        guard let url = URL(string: "https://fal.run/fal-ai/flux/dev") else {
            throw FluxError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let body: [String: Any] = [
            "prompt": prompt,
            "image_size": "square_hd",
            "num_images": 1
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FluxError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw FluxError.apiError("Status \(httpResponse.statusCode): \(errorBody)")
        }

        // fal.ai returns: { "images": [{ "url": "...", "width": ..., "height": ..., "content_type": "..." }] }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let images = json["images"] as? [[String: Any]],
              let first = images.first,
              let imageURLString = first["url"] as? String,
              let imageURL = URL(string: imageURLString) else {
            throw FluxError.parseError
        }

        // Download the image
        let (imageData, imageResponse) = try await URLSession.shared.data(from: imageURL)

        guard let imageHttp = imageResponse as? HTTPURLResponse, imageHttp.statusCode == 200 else {
            throw FluxError.downloadFailed
        }

        return imageData
    }

    enum FluxError: LocalizedError {
        case noAPIKey
        case invalidURL
        case invalidResponse
        case apiError(String)
        case parseError
        case downloadFailed

        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "No fal.ai API key. Add it in Settings."
            case .invalidURL: return "Invalid API URL."
            case .invalidResponse: return "Invalid server response."
            case .apiError(let msg): return msg
            case .parseError: return "Failed to parse fal.ai API response."
            case .downloadFailed: return "Failed to download generated image."
            }
        }
    }
}
