import Foundation
import SwiftData

@Model
final class SummaryRecord {
    var id: UUID
    var timestamp: Date
    var inputText: String
    var summaryText: String

    init(inputText: String, summaryText: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.inputText = inputText
        self.summaryText = summaryText
    }
}
