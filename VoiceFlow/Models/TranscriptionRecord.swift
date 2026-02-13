import Foundation
import SwiftData

@Model
final class TranscriptionRecord {
    var id: UUID
    var timestamp: Date
    var sourceType: String
    var transcribedText: String
    var duration: Double?
    var editedText: String?
    var language: String?

    /// Returns edited text if available, otherwise the original transcription
    var displayText: String {
        editedText ?? transcribedText
    }

    init(sourceType: String, transcribedText: String, duration: Double? = nil, language: String? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.sourceType = sourceType
        self.transcribedText = transcribedText
        self.duration = duration
        self.language = language
    }
}
