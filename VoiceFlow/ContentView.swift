import SwiftUI

struct ContentView: View {
    @State private var showOnboarding = false
    
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
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(.bitcoinOrange)
        .onAppear {
            let provider = OpenAIProvider()
            if !provider.hasKey {
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding) {
            APIKeyOnboardingView(isPresented: $showOnboarding)
        }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
