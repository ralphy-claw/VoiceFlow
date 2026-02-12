import SwiftUI
import SwiftData

@main
struct VoiceFlowApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [
            TranscriptionRecord.self,
            TTSRecord.self,
            SummaryRecord.self
        ])
    }
}
