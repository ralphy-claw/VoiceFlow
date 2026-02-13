import Foundation
import UIKit

// MARK: - Protocol

protocol ImageGenerationService {
    func generateImage(prompt: String) async throws -> Data
    var modelName: String { get }
    var modelIcon: String { get }
    var requiresAPIKey: Bool { get }
    var hasValidAPIKey: Bool { get }
}

// MARK: - Image Model Enum

enum ImageModel: String, CaseIterable, Identifiable {
    case gemini = "Gemini"
    case dalle3 = "DALL-E 3"
    case imagen4 = "Imagen 4"
    case flux = "Flux"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .gemini: return "sparkle"
        case .dalle3: return "brain.head.profile"
        case .imagen4: return "photo.artframe"
        case .flux: return "bolt.fill"
        }
    }
}

// MARK: - Image Model Manager

@Observable
final class ImageModelManager {
    static let shared = ImageModelManager()

    private let geminiService = GeminiImageAdapter()
    private let dalleService = DallEImageService()
    private let imagenService = ImagenService()
    private let fluxService = FluxImageService()

    func service(for model: ImageModel) -> any ImageGenerationService {
        switch model {
        case .gemini: return geminiService
        case .dalle3: return dalleService
        case .imagen4: return imagenService
        case .flux: return fluxService
        }
    }
}

// MARK: - Gemini Adapter (wraps existing GeminiImageService)

struct GeminiImageAdapter: ImageGenerationService {
    var modelName: String { "Gemini" }
    var modelIcon: String { "sparkle" }
    var requiresAPIKey: Bool { true }
    var hasValidAPIKey: Bool {
        let key = KeychainService.read(key: "geminiAPIKey") ?? ""
        return !key.isEmpty
    }

    func generateImage(prompt: String) async throws -> Data {
        let image = try await GeminiImageService.shared.generateImage(prompt: prompt)
        guard let data = image.pngData() else {
            throw NSError(domain: "ImageGen", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode image"])
        }
        return data
    }
}
