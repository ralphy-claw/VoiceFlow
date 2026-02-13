import SwiftUI
import SwiftData

struct SpeakView: View {
    @Binding var sharedText: SharedDataHandler.SharedTextData?
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TTSRecord.timestamp, order: .reverse) private var history: [TTSRecord]
    @State private var inputText = ""
    @State private var selectedProvider: TTSProvider = .openai
    @State private var selectedVoice = "alloy"
    @State private var selectedElevenLabsVoice = "21m00Tcm4TlvDq8ikWAM" // Rachel (default)
    @State private var elevenLabsVoices: [ElevenLabsVoice] = []
    @State private var playbackSpeed: Float = 1.0
    @State private var isGenerating = false
    @State private var audioData: Data?
    @State private var errorMessage: String?
    @State private var showError = false
    @StateObject private var player = AudioPlayer()
    @State private var expandedRecordID: UUID?
    @State private var showShareSheet = false
    @State private var shareURL: URL?
    @State private var showCopyToast = false
    
    private let voices = ["alloy", "echo", "fable", "onyx", "nova", "shimmer"]
    private let speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    
    enum TTSProvider: String, CaseIterable {
        case openai = "OpenAI"
        case elevenlabs = "ElevenLabs"
    }
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Controls Section
                Section {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Text to speak")
                                    .font(.headline)
                                Spacer()
                                if !inputText.isEmpty {
                                    Button {
                                        inputText = ""
                                        HapticService.impact(.light)
                                    } label: {
                                        Label("Clear", systemImage: "xmark.circle.fill")
                                            .labelStyle(.iconOnly)
                                            .font(.caption)
                                    }
                                    .tint(.secondary)
                                }
                            }
                            
                            TextField("Enter text...", text: $inputText, axis: .vertical)
                                .lineLimit(3...6)
                                .padding(8)
                                .background(Color.darkSurfaceLight)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .contextMenu {
                                    if !inputText.isEmpty {
                                        Button {
                                            UIPasteboard.general.string = inputText
                                            HapticService.notification(.success)
                                            withAnimation {
                                                showCopyToast = true
                                            }
                                        } label: {
                                            Label("Copy", systemImage: "doc.on.doc")
                                        }
                                    }
                                    
                                    Button {
                                        if let pasteText = UIPasteboard.general.string {
                                            inputText = pasteText
                                            HapticService.impact(.light)
                                        }
                                    } label: {
                                        Label("Paste", systemImage: "doc.on.clipboard")
                                    }
                                }
                        }
                        
                        Picker("Provider", selection: $selectedProvider) {
                            ForEach(TTSProvider.allCases, id: \.self) { provider in
                                Text(provider.rawValue).tag(provider)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        if selectedProvider == .openai {
                            Picker("Voice", selection: $selectedVoice) {
                                ForEach(voices, id: \.self) { voice in
                                    Text(voice.capitalized).tag(voice)
                                }
                            }
                            .pickerStyle(.menu)
                        } else {
                            if elevenLabsVoices.isEmpty {
                                Button {
                                    loadElevenLabsVoices()
                                } label: {
                                    Label("Load Voices", systemImage: "arrow.down.circle")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .tint(.bitcoinOrange)
                            } else {
                                Picker("Voice", selection: $selectedElevenLabsVoice) {
                                    ForEach(elevenLabsVoices) { voice in
                                        Text(voice.name).tag(voice.voice_id)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Speed:")
                                .font(.subheadline)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                                ForEach(speeds, id: \.self) { speed in
                                    Button {
                                        playbackSpeed = speed
                                        HapticService.impact(.light)
                                    } label: {
                                        Text("\(String(format: "%.2g", speed))x")
                                            .font(.subheadline.weight(playbackSpeed == speed ? .bold : .regular))
                                            .frame(maxWidth: .infinity, minHeight: 44)
                                            .background(playbackSpeed == speed ? Color.bitcoinOrange : Color.darkSurfaceLight)
                                            .foregroundStyle(playbackSpeed == speed ? .white : .primary)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
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
                        .frame(minHeight: 56)
                        .tint(.bitcoinOrange)
                        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
                        
                        if audioData != nil {
                            HStack(spacing: 16) {
                                Button {
                                    togglePlayback()
                                } label: {
                                    Label(player.isPlaying ? "Stop" : "Play", systemImage: player.isPlaying ? "stop.fill" : "play.fill")
                                        .font(.title3)
                                }
                                .buttonStyle(.bordered)
                                .tint(.bitcoinOrange)
                                
                                Button {
                                    shareAudio()
                                } label: {
                                    Label("Export", systemImage: "square.and.arrow.up")
                                        .font(.title3)
                                }
                                .buttonStyle(.bordered)
                                .tint(.bitcoinOrange)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.darkSurface)
                }
                
                // MARK: - History Section
                Section {
                    if history.isEmpty {
                        Text("No history yet")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.darkSurface)
                    } else {
                        ForEach(history) { record in
                            TTSHistoryRow(record: record, isExpanded: expandedRecordID == record.id)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation {
                                        expandedRecordID = expandedRecordID == record.id ? nil : record.id
                                    }
                                }
                                .listRowBackground(Color.darkSurface)
                        }
                        .onDelete(perform: deleteRecords)
                    }
                } header: {
                    Text("History")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.darkBackground.ignoresSafeArea())
            .navigationTitle("Speak")
            .toast(isShowing: $showCopyToast, message: "Copied to clipboard")
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
            .onChange(of: sharedText) { _, newData in
                if let data = newData, data.action == "tts" {
                    inputText = data.text
                    SharedDataHandler.clearSharedText()
                    sharedText = nil
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = shareURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }
    
    private func deleteRecords(at offsets: IndexSet) {
        for index in offsets {
            let record = history[index]
            // Remove stored audio file
            if let filename = record.audioFilePath {
                let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fileURL = docsURL.appendingPathComponent(filename)
                try? FileManager.default.removeItem(at: fileURL)
            }
            modelContext.delete(record)
        }
        try? modelContext.save()
    }
    
    private func generateSpeech() {
        HapticService.impact(.medium)
        isGenerating = true
        Task {
            do {
                let data: Data
                let voiceUsed: String
                
                switch selectedProvider {
                case .openai:
                    data = try await OpenAIService.shared.synthesize(text: inputText, voice: selectedVoice)
                    voiceUsed = "OpenAI: \(selectedVoice)"
                    
                case .elevenlabs:
                    data = try await ElevenLabsService.shared.synthesize(text: inputText, voiceId: selectedElevenLabsVoice)
                    let voiceName = elevenLabsVoices.first(where: { $0.voice_id == selectedElevenLabsVoice })?.name ?? selectedElevenLabsVoice
                    voiceUsed = "ElevenLabs: \(voiceName)"
                }
                
                audioData = data
                HapticService.notification(.success)
                let filename = "\(UUID().uuidString).mp3"
                let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fileURL = docsURL.appendingPathComponent(filename)
                try? data.write(to: fileURL)
                let record = TTSRecord(inputText: inputText, voiceUsed: voiceUsed, audioFilePath: filename)
                modelContext.insert(record)
                try? modelContext.save()
            } catch {
                HapticService.notification(.error)
                errorMessage = error.localizedDescription
                showError = true
            }
            isGenerating = false
        }
    }
    
    private func loadElevenLabsVoices() {
        Task {
            do {
                let voices = try await ElevenLabsService.shared.getVoices()
                elevenLabsVoices = voices
                if let firstVoice = voices.first {
                    selectedElevenLabsVoice = firstVoice.voice_id
                }
            } catch {
                errorMessage = "Failed to load ElevenLabs voices: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    private func togglePlayback() {
        guard let data = audioData else { return }
        HapticService.impact(.light)
        do {
            try player.toggle(data: data, rate: playbackSpeed)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func shareAudio() {
        guard let data = audioData else { return }
        
        // Create temporary file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("voiceflow_tts.mp3")
        do {
            try data.write(to: tempURL)
            shareURL = tempURL
            showShareSheet = true
        } catch {
            errorMessage = "Failed to prepare audio for export"
            showError = true
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - History Row

private struct TTSHistoryRow: View {
    let record: TTSRecord
    let isExpanded: Bool
    @StateObject private var player = AudioPlayer()
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(record.inputText)
                    .lineLimit(isExpanded ? nil : 2)
                Spacer()
                Text(record.voiceUsed.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.bitcoinOrange.opacity(0.2))
                    .foregroundStyle(Color.bitcoinOrange)
                    .clipShape(Capsule())
            }
            
            Text(record.timestamp, style: .relative)
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            if isExpanded {
                Divider()
                Text(record.inputText)
                    .font(.body)
                    .textSelection(.enabled)
                
                HStack(spacing: 16) {
                    Button {
                        replayAudio()
                    } label: {
                        Label(player.isPlaying ? "Stop" : "Replay", systemImage: player.isPlaying ? "stop.fill" : "play.fill")
                            .font(.caption)
                    }
                    .tint(.bitcoinOrange)
                    
                    Button {
                        UIPasteboard.general.string = record.inputText
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.caption)
                    }
                    .tint(.bitcoinOrange)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func replayAudio() {
        if player.isPlaying {
            player.stop()
            return
        }
        guard let filename = record.audioFilePath else { return }
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = docsURL.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            try player.play(data: data)
        } catch {
            // silently fail
        }
    }
}

#Preview {
    SpeakView(sharedText: .constant(nil))
        .preferredColorScheme(.dark)
}
