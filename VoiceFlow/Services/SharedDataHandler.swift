import Foundation

/// Handles reading shared data from App Group container
enum SharedDataHandler {
    private static let appGroupID = "group.com.lubodev.voiceflow"
    
    // MARK: - Shared Text
    
    struct SharedTextData: Equatable {
        let action: String
        let text: String
        let timestamp: TimeInterval
    }
    
    static func readSharedText() -> SharedTextData? {
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return nil
        }
        
        let sharedDataURL = groupURL.appendingPathComponent("shared_text.json")
        
        guard FileManager.default.fileExists(atPath: sharedDataURL.path),
              let data = try? Data(contentsOf: sharedDataURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let action = json["action"] as? String,
              let text = json["text"] as? String,
              let timestamp = json["timestamp"] as? TimeInterval else {
            return nil
        }
        
        return SharedTextData(action: action, text: text, timestamp: timestamp)
    }
    
    static func clearSharedText() {
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return
        }
        
        let sharedDataURL = groupURL.appendingPathComponent("shared_text.json")
        try? FileManager.default.removeItem(at: sharedDataURL)
    }
    
    // MARK: - Shared Audio
    
    struct SharedAudioData: Equatable {
        let fileURL: URL
        let timestamp: TimeInterval
    }
    
    static func readSharedAudio() -> SharedAudioData? {
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return nil
        }
        
        let metadataURL = groupURL.appendingPathComponent("shared_audio.json")
        
        guard FileManager.default.fileExists(atPath: metadataURL.path),
              let data = try? Data(contentsOf: metadataURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let filename = json["filename"] as? String,
              let timestamp = json["timestamp"] as? TimeInterval else {
            return nil
        }
        
        let fileURL = groupURL.appendingPathComponent(filename)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        return SharedAudioData(fileURL: fileURL, timestamp: timestamp)
    }
    
    static func clearSharedAudio() {
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return
        }
        
        let metadataURL = groupURL.appendingPathComponent("shared_audio.json")
        
        // Read filename to delete audio file too
        if let data = try? Data(contentsOf: metadataURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let filename = json["filename"] as? String {
            let fileURL = groupURL.appendingPathComponent(filename)
            try? FileManager.default.removeItem(at: fileURL)
        }
        
        try? FileManager.default.removeItem(at: metadataURL)
    }
}
