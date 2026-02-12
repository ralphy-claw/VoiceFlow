import Foundation
import SwiftData

@Model
final class TTSRecord {
    var id: UUID
    var timestamp: Date
    var inputText: String
    var voiceUsed: String
    var audioFilePath: String?

    init(inputText: String, voiceUsed: String, audioFilePath: String? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.inputText = inputText
        self.voiceUsed = voiceUsed
        self.audioFilePath = audioFilePath
    }
}
