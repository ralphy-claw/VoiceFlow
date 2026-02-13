import SwiftUI

struct ContentView: View {
    @Binding var selectedTab: Int
    @Binding var sharedTextData: SharedDataHandler.SharedTextData?
    @Binding var sharedAudioData: SharedDataHandler.SharedAudioData?
    
    @State private var showOnboarding = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TranscribeView(sharedAudioData: $sharedAudioData)
                .tabItem {
                    Label("Transcribe", systemImage: "mic.fill")
                }
                .tag(0)
            
            SpeakView(sharedText: $sharedTextData)
                .tabItem {
                    Label("Speak", systemImage: "speaker.wave.2.fill")
                }
                .tag(1)
            
            SummarizeView(sharedText: $sharedTextData)
                .tabItem {
                    Label("Summarize", systemImage: "doc.text.fill")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
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
