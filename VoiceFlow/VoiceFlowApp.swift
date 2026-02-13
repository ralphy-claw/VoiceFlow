import SwiftUI
import SwiftData

@main
struct VoiceFlowApp: App {
    @State private var selectedTab = 0
    @State private var sharedTextData: SharedDataHandler.SharedTextData?
    @State private var sharedAudioData: SharedDataHandler.SharedAudioData?
    @State private var summarizePrefilledText = ""
    @State private var speakPrefilledText = ""
    
    var body: some Scene {
        WindowGroup {
            ContentView(
                selectedTab: $selectedTab,
                sharedTextData: $sharedTextData,
                sharedAudioData: $sharedAudioData,
                summarizePrefilledText: $summarizePrefilledText,
                speakPrefilledText: $speakPrefilledText
            )
            .preferredColorScheme(.dark)
            .onOpenURL { url in
                handleDeepLink(url)
            }
        }
        .modelContainer(for: [
            TranscriptionRecord.self,
            TTSRecord.self,
            SummaryRecord.self,
            PromptRecord.self
        ])
    }
    
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "voiceflow" else { return }
        
        switch url.host {
        case "share":
            if let data = SharedDataHandler.readSharedText() {
                sharedTextData = data
                switch data.action {
                case "tts":
                    selectedTab = 1
                case "summarize":
                    selectedTab = 2
                default:
                    break
                }
            }
            
        case "transcribe":
            if let data = SharedDataHandler.readSharedAudio() {
                sharedAudioData = data
                selectedTab = 0
            }
            
        default:
            break
        }
    }
}
