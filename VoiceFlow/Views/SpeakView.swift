import SwiftUI
import SwiftData

struct SpeakView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TTSRecord.timestamp, order: .reverse) private var history: [TTSRecord]
    @State private var inputText = ""
    @State private var selectedVoice = "alloy"
    @State private var isGenerating = false
    @State private var audioData: Data?
    @State private var errorMessage: String?
    @State private var showError = false
    @StateObject private var player = AudioPlayer()
    @State private var expandedRecordID: UUID?
    
    private let voices = ["alloy", "echo", "fable", "onyx", "nova", "shimmer"]
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Controls Section
                Section {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Text to speak")
                                .font(.headline)
                            
                            TextField("Enter text...", text: $inputText, axis: .vertical)
                                .lineLimit(3...6)
                                .padding(8)
                                .background(Color.darkSurfaceLight)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        Picker("Voice", selection: $selectedVoice) {
                            ForEach(voices, id: \.self) { voice in
                                Text(voice.capitalized).tag(voice)
                            }
                        }
                        .pickerStyle(.segmented)
                        
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
                        
                        if audioData != nil {
                            Button {
                                togglePlayback()
                            } label: {
                                Label(player.isPlaying ? "Stop" : "Play", systemImage: player.isPlaying ? "stop.fill" : "play.fill")
                                    .font(.title2)
                            }
                            .tint(.bitcoinOrange)
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
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "Unknown error")
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
        isGenerating = true
        Task {
            do {
                let data = try await OpenAIService.shared.synthesize(text: inputText, voice: selectedVoice)
                audioData = data
                let filename = "\(UUID().uuidString).mp3"
                let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fileURL = docsURL.appendingPathComponent(filename)
                try? data.write(to: fileURL)
                let record = TTSRecord(inputText: inputText, voiceUsed: selectedVoice, audioFilePath: filename)
                modelContext.insert(record)
                try? modelContext.save()
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
    SpeakView()
        .preferredColorScheme(.dark)
}
