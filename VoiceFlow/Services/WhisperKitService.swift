import Foundation
// import WhisperKit  // TODO: Add WhisperKit package dependency via Xcode

enum WhisperKitError: LocalizedError {
    case notAvailable
    case transcriptionFailed(String)
    case modelNotDownloaded
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "WhisperKit is not available on this device"
        case .transcriptionFailed(let msg):
            return "Transcription failed: \(msg)"
        case .modelNotDownloaded:
            return "Whisper model not downloaded. Please download it first."
        }
    }
}

@MainActor
class WhisperKitService: ObservableObject {
    static let shared = WhisperKitService()
    
    @Published var isModelDownloaded = false
    @Published var downloadProgress: Double = 0
    @Published var isDownloading = false
    
    // Uncomment when WhisperKit is added:
    // private var whisperKit: WhisperKit?
    
    private let modelName = "openai/whisper-base"
    
    func initialize() async {
        // TODO: Uncomment when WhisperKit package is added
        /*
        do {
            whisperKit = try await WhisperKit(model: modelName)
            isModelDownloaded = true
        } catch {
            print("WhisperKit initialization failed: \(error)")
            isModelDownloaded = false
        }
        */
        
        // For now, just mark as not available
        isModelDownloaded = false
    }
    
    func downloadModel() async throws {
        isDownloading = true
        defer { isDownloading = false }
        
        // TODO: Implement model download when WhisperKit is added
        /*
        do {
            whisperKit = try await WhisperKit(model: modelName, downloadProgress: { progress in
                Task { @MainActor in
                    self.downloadProgress = progress.fractionCompleted
                }
            })
            isModelDownloaded = true
        } catch {
            throw WhisperKitError.transcriptionFailed(error.localizedDescription)
        }
        */
        
        throw WhisperKitError.notAvailable
    }
    
    func transcribe(audioURL: URL, language: String? = nil) async throws -> String {
        guard isModelDownloaded else {
            throw WhisperKitError.modelNotDownloaded
        }
        
        // TODO: Implement transcription when WhisperKit is added
        /*
        guard let whisperKit = whisperKit else {
            throw WhisperKitError.notAvailable
        }
        
        do {
            var options = DecodingOptions()
            if let language = language {
                options.language = language
            }
            let result = try await whisperKit.transcribe(audioPath: audioURL.path, decodeOptions: options)
            return result.text
        } catch {
            throw WhisperKitError.transcriptionFailed(error.localizedDescription)
        }
        */
        
        throw WhisperKitError.notAvailable
    }
}

// MARK: - Settings

enum STTProvider: String, CaseIterable, Codable {
    case cloud = "Cloud (OpenAI Whisper)"
    case local = "On-Device (WhisperKit)"
}

@Observable
class STTSettings {
    var provider: STTProvider {
        didSet { save() }
    }
    
    var language: String {
        didSet { saveLanguage() }
    }
    
    private let providerKey = "stt_provider"
    private let languageKey = "stt_language"
    
    init() {
        if let providerRaw = UserDefaults.standard.string(forKey: providerKey),
           let savedProvider = STTProvider(rawValue: providerRaw) {
            self.provider = savedProvider
        } else {
            self.provider = .cloud
        }
        self.language = UserDefaults.standard.string(forKey: languageKey) ?? "auto"
    }
    
    private func save() {
        UserDefaults.standard.set(provider.rawValue, forKey: providerKey)
    }
    
    private func saveLanguage() {
        UserDefaults.standard.set(language, forKey: languageKey)
    }
    
    /// Display code for the current language (e.g. "EN", "BG", "AUTO")
    var languageDisplayCode: String {
        if language == "auto" { return "AUTO" }
        return language.uppercased()
    }
}

// MARK: - Supported Languages

struct WhisperLanguage: Identifiable, Hashable {
    let id: String // ISO code
    let name: String
    
    var displayCode: String { id.uppercased() }
}

enum WhisperLanguages {
    static let common: [WhisperLanguage] = [
        WhisperLanguage(id: "en", name: "English"),
        WhisperLanguage(id: "bg", name: "Bulgarian"),
        WhisperLanguage(id: "es", name: "Spanish"),
        WhisperLanguage(id: "fr", name: "French"),
        WhisperLanguage(id: "de", name: "German"),
        WhisperLanguage(id: "ja", name: "Japanese"),
        WhisperLanguage(id: "zh", name: "Chinese"),
    ]
    
    static let all: [WhisperLanguage] = [
        WhisperLanguage(id: "en", name: "English"),
        WhisperLanguage(id: "bg", name: "Bulgarian"),
        WhisperLanguage(id: "es", name: "Spanish"),
        WhisperLanguage(id: "fr", name: "French"),
        WhisperLanguage(id: "de", name: "German"),
        WhisperLanguage(id: "ja", name: "Japanese"),
        WhisperLanguage(id: "zh", name: "Chinese"),
        WhisperLanguage(id: "ar", name: "Arabic"),
        WhisperLanguage(id: "cs", name: "Czech"),
        WhisperLanguage(id: "da", name: "Danish"),
        WhisperLanguage(id: "nl", name: "Dutch"),
        WhisperLanguage(id: "fi", name: "Finnish"),
        WhisperLanguage(id: "el", name: "Greek"),
        WhisperLanguage(id: "he", name: "Hebrew"),
        WhisperLanguage(id: "hi", name: "Hindi"),
        WhisperLanguage(id: "hu", name: "Hungarian"),
        WhisperLanguage(id: "id", name: "Indonesian"),
        WhisperLanguage(id: "it", name: "Italian"),
        WhisperLanguage(id: "ko", name: "Korean"),
        WhisperLanguage(id: "ms", name: "Malay"),
        WhisperLanguage(id: "no", name: "Norwegian"),
        WhisperLanguage(id: "pl", name: "Polish"),
        WhisperLanguage(id: "pt", name: "Portuguese"),
        WhisperLanguage(id: "ro", name: "Romanian"),
        WhisperLanguage(id: "ru", name: "Russian"),
        WhisperLanguage(id: "sk", name: "Slovak"),
        WhisperLanguage(id: "sv", name: "Swedish"),
        WhisperLanguage(id: "th", name: "Thai"),
        WhisperLanguage(id: "tr", name: "Turkish"),
        WhisperLanguage(id: "uk", name: "Ukrainian"),
        WhisperLanguage(id: "vi", name: "Vietnamese"),
    ]
}
