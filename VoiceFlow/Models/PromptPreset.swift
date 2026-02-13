import Foundation

enum PromptPreset: String, CaseIterable, Identifiable {
    case none = "None"
    case phoneSelfie = "Phone Selfie"
    case professionalPhoto = "Professional Photo"
    case cinematic = "Cinematic"
    case animeStyle = "Anime Style"
    case oilPainting = "Oil Painting"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .none: return "circle.dashed"
        case .phoneSelfie: return "iphone"
        case .professionalPhoto: return "camera.fill"
        case .cinematic: return "film"
        case .animeStyle: return "sparkles"
        case .oilPainting: return "paintbrush.fill"
        }
    }

    var modifier: String? {
        switch self {
        case .none:
            return nil
        case .phoneSelfie:
            return "taken with smartphone camera, front-facing selfie angle, natural lighting, slight wide-angle distortion, casual composition, realistic phone photo aesthetic, not professional photography"
        case .professionalPhoto:
            return "professional studio photography, perfect lighting, high-end DSLR, sharp focus, clean background, commercial quality"
        case .cinematic:
            return "cinematic composition, dramatic lighting, anamorphic lens flare, shallow depth of field, movie still aesthetic, 35mm film grain"
        case .animeStyle:
            return "anime art style, vibrant colors, cel-shading, detailed linework, Studio Ghibli inspired, Japanese animation aesthetic"
        case .oilPainting:
            return "classical oil painting style, visible brushstrokes, rich colors, museum-quality fine art, Renaissance lighting, canvas texture"
        }
    }
}
