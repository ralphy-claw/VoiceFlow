import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TranscribeView()
                .tabItem {
                    Label("Transcribe", systemImage: "mic.fill")
                }
            
            SpeakView()
                .tabItem {
                    Label("Speak", systemImage: "speaker.wave.2.fill")
                }
            
            SummarizeView()
                .tabItem {
                    Label("Summarize", systemImage: "doc.text.fill")
                }
        }
        .tint(.bitcoinOrange)
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
