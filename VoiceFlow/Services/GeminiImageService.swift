import SwiftUI
import UIKit
import Foundation

@Observable
final class GeminiImageService {
    static let shared = GeminiImageService()
    
    var isGenerating = false
    var generatedImage: UIImage?
    var errorMessage: String?
    
    func generateImage(prompt: String) async throws -> UIImage {
        let apiKey = KeychainService.read(key: "geminiAPIKey") ?? ""
        guard !apiKey.isEmpty else {
            throw GeminiError.noAPIKey
        }
        
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw GeminiError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ],
            "generationConfig": [
                "responseModalities": ["TEXT", "IMAGE"]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GeminiError.apiError("Status \(httpResponse.statusCode): \(errorBody)")
        }
        
        // Parse response for inline image data
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw GeminiError.parseError
        }
        
        // Find the part with inlineData
        for part in parts {
            if let inlineData = part["inlineData"] as? [String: Any],
               let base64String = inlineData["data"] as? String,
               let imageData = Data(base64Encoded: base64String),
               let image = UIImage(data: imageData) {
                return image
            }
        }
        
        throw GeminiError.noImageInResponse
    }
    
    enum GeminiError: LocalizedError {
        case noAPIKey
        case invalidURL
        case invalidResponse
        case apiError(String)
        case parseError
        case noImageInResponse
        
        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "No Gemini API key. Add it in Settings."
            case .invalidURL: return "Invalid API URL."
            case .invalidResponse: return "Invalid server response."
            case .apiError(let msg): return msg
            case .parseError: return "Failed to parse API response."
            case .noImageInResponse: return "No image was returned by the API."
            }
        }
    }
}
