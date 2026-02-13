import SwiftUI

struct ContentView: View {
    @Binding var selectedTab: Int
    @Binding var sharedTextData: SharedDataHandler.SharedTextData?
    @Binding var sharedAudioData: SharedDataHandler.SharedAudioData?
    @Binding var summarizePrefilledText: String
    @Binding var speakPrefilledText: String
    
    @State private var showOnboarding = false
    @State private var showKeyboardOnboarding = false
    @State private var showKeyboardSetup = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TranscribeView(
                sharedAudioData: $sharedAudioData,
                selectedTab: $selectedTab,
                summarizePrefilledText: $summarizePrefilledText,
                speakPrefilledText: $speakPrefilledText
            )
                .tabItem {
                    Label("Transcribe", systemImage: "mic.fill")
                }
                .tag(0)
            
            SpeakView(sharedText: $sharedTextData, prefilledText: $speakPrefilledText)
                .tabItem {
                    Label("Speak", systemImage: "speaker.wave.2.fill")
                }
                .tag(1)
            
            SummarizeView(sharedText: $sharedTextData, prefilledText: $summarizePrefilledText)
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
            
            // Show keyboard onboarding on first launch
            if !UserDefaults.standard.bool(forKey: "hasCompletedKeyboardOnboarding") {
                showKeyboardOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding) {
            APIKeyOnboardingView(isPresented: $showOnboarding)
        }
        .fullScreenCover(isPresented: $showKeyboardOnboarding) {
            KeyboardOnboardingView(isPresented: $showKeyboardOnboarding)
        }
        .sheet(isPresented: $showKeyboardSetup) {
            KeyboardSetupGuideView()
        }
    }
}

#Preview {
    ContentView(
        selectedTab: .constant(0),
        sharedTextData: .constant(nil),
        sharedAudioData: .constant(nil),
        summarizePrefilledText: .constant(""),
        speakPrefilledText: .constant("")
    )
    .preferredColorScheme(.dark)
}
