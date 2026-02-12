import SwiftUI

struct SpeakView: View {
    @State private var inputText = ""
    @State private var selectedVoice = "alloy"
    @State private var isGenerating = false
    @State private var audioData: Data?
    @State private var errorMessage: String?
    @State private var showError = false
    @StateObject private var player = AudioPlayer()
    
    private let voices = ["alloy", "echo", "fable", "onyx", "nova", "shimmer"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Text to speak")
                        .font(.headline)
                    
                    TextEditor(text: $inputText)
                        .frame(minHeight: 150)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color.darkSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal)
                
                Picker("Voice", selection: $selectedVoice) {
                    ForEach(voices, id: \.self) { voice in
                        Text(voice.capitalized).tag(voice)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                Button {
                    generateSpeech()
                } label: {
                    if isGenerating {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Generate Speech", systemImage: "waveform")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.bitcoinOrange)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
                .padding(.horizontal)
                
                if audioData != nil {
                    Button {
                        togglePlayback()
                    } label: {
                        Label(player.isPlaying ? "Stop" : "Play", systemImage: player.isPlaying ? "stop.fill" : "play.fill")
                            .font(.title2)
                    }
                    .tint(.bitcoinOrange)
                }
                
                Spacer()
            }
            .padding(.top)
            .background(Color.darkBackground.ignoresSafeArea())
            .navigationTitle("Speak")
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }
    
    private func generateSpeech() {
        isGenerating = true
        Task {
            do {
                let data = try await OpenAIService.shared.synthesize(text: inputText, voice: selectedVoice)
                audioData = data
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isGenerating = false
        }
    }
    
    private func togglePlayback() {
        guard let data = audioData else { return }
        do {
            try player.toggle(data: data)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    SpeakView()
        .preferredColorScheme(.dark)
}
