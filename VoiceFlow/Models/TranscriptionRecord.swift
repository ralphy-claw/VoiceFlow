import Foundation
import SwiftData

@Model
final class TranscriptionRecord {
    var id: UUID
    var timestamp: Date
    var sourceType: String
    var transcribedText: String
    var duration: Double?

    init(sourceType: String, transcribedText: String, duration: Double? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.sourceType = sourceType
        self.transcribedText = transcribedText
        self.duration = duration
    }
}
