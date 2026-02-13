import Foundation
import SwiftData

@Model
final class PromptRecord {
    var id: UUID
    var originalText: String
    var enhancedText: String
    var preset: String?
    var timestamp: Date
    var isFavorite: Bool

    init(originalText: String, enhancedText: String, preset: String? = nil, isFavorite: Bool = false) {
        self.id = UUID()
        self.originalText = originalText
        self.enhancedText = enhancedText
        self.preset = preset
        self.timestamp = Date()
        self.isFavorite = isFavorite
    }
}
