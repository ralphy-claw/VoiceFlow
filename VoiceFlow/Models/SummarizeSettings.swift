import Foundation

enum SummaryLength: String, CaseIterable, Codable {
    case brief = "Brief"
    case standard = "Standard"
    case detailed = "Detailed"
    
    var systemPrompt: String {
        switch self {
        case .brief:
            return "Provide a very brief summary in 1-2 sentences."
        case .standard:
            return "Provide a concise summary in a paragraph."
        case .detailed:
            return "Provide a comprehensive summary covering all key points."
        }
    }
}

enum SummaryFormat: String, CaseIterable, Codable {
    case prose = "Prose"
    case bullets = "Bullets"
    case keyTakeaways = "Key Takeaways"
    
    var systemPrompt: String {
        switch self {
        case .prose:
            return "Format as flowing prose paragraphs."
        case .bullets:
            return "Format as bullet points."
        case .keyTakeaways:
            return "Format as numbered key takeaways."
        }
    }
}

@Observable
class SummarizeSettings {
    var length: SummaryLength {
        didSet { save() }
    }
    
    var format: SummaryFormat {
        didSet { save() }
    }
    
    private let lengthKey = "summarize_length"
    private let formatKey = "summarize_format"
    
    init() {
        // Load from UserDefaults
        if let lengthRaw = UserDefaults.standard.string(forKey: lengthKey),
           let savedLength = SummaryLength(rawValue: lengthRaw) {
            self.length = savedLength
        } else {
            self.length = .standard
        }
        
        if let formatRaw = UserDefaults.standard.string(forKey: formatKey),
           let savedFormat = SummaryFormat(rawValue: formatRaw) {
            self.format = savedFormat
        } else {
            self.format = .prose
        }
    }
    
    private func save() {
        UserDefaults.standard.set(length.rawValue, forKey: lengthKey)
        UserDefaults.standard.set(format.rawValue, forKey: formatKey)
    }
    
    func buildSystemPrompt() -> String {
        """
        You are a helpful assistant. Summarize the following text.
        \(length.systemPrompt)
        \(format.systemPrompt)
        Keep key information and main points.
        """
    }
}
