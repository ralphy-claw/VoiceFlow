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
    
    func transcribe(audioURL: URL) async throws -> String {
        guard isModelDownloaded else {
            throw WhisperKitError.modelNotDownloaded
        }
        
        // TODO: Implement transcription when WhisperKit is added
        /*
        guard let whisperKit = whisperKit else {
            throw WhisperKitError.notAvailable
        }
        
        do {
            let result = try await whisperKit.transcribe(audioPath: audioURL.path)
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
    
    private let providerKey = "stt_provider"
    
    init() {
        if let providerRaw = UserDefaults.standard.string(forKey: providerKey),
           let savedProvider = STTProvider(rawValue: providerRaw) {
            self.provider = savedProvider
        } else {
            self.provider = .cloud
        }
    }
    
    private func save() {
        UserDefaults.standard.set(provider.rawValue, forKey: providerKey)
    }
}
