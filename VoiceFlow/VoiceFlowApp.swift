import SwiftUI
import SwiftData

@main
struct VoiceFlowApp: App {
    @State private var selectedTab = 0
    @State private var sharedTextData: SharedDataHandler.SharedTextData?
    @State private var sharedAudioData: SharedDataHandler.SharedAudioData?
    
    var body: some Scene {
        WindowGroup {
            ContentView(
                selectedTab: $selectedTab,
                sharedTextData: $sharedTextData,
                sharedAudioData: $sharedAudioData
            )
            .preferredColorScheme(.dark)
            .onOpenURL { url in
                handleDeepLink(url)
            }
        }
        .modelContainer(for: [
            TranscriptionRecord.self,
            TTSRecord.self,
            SummaryRecord.self
        ])
    }
    
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "voiceflow" else { return }
        
        switch url.host {
        case "share":
            // Handle share extension data
            if let data = SharedDataHandler.readSharedText() {
                sharedTextData = data
                
                // Navigate to appropriate tab
                switch data.action {
                case "tts":
                    selectedTab = 1 // Speak tab
                case "summarize":
                    selectedTab = 2 // Summarize tab
                default:
                    break
                }
            }
            
        case "transcribe":
            // Handle audio share
            if let data = SharedDataHandler.readSharedAudio() {
                sharedAudioData = data
                selectedTab = 0 // Transcribe tab
            }
            
        default:
            break
        }
    }
}
