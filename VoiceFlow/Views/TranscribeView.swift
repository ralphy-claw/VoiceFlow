import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct TranscribeView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var recorder = AudioRecorder()
    @State private var transcription = ""
    @State private var isTranscribing = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showFilePicker = false
    @State private var lastSourceType = "recording"
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Recording controls
                HStack(spacing: 30) {
                    Button {
                        handleRecord()
                    } label: {
                        VStack {
                            Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(recorder.isRecording ? Color.red : Color.bitcoinOrange)
                            Text(recorder.isRecording ? "Stop" : "Record")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Button {
                        showFilePicker = true
                    } label: {
                        VStack {
                            Image(systemName: "doc.badge.plus")
                                .font(.system(size: 50))
                                .foregroundStyle(Color.bitcoinOrange)
                            Text("Import")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(isTranscribing)
                }
                .padding(.top)
                
                if recorder.isRecording {
                    Text(String(format: "%.1fs", recorder.recordingTime))
                        .font(.title2.monospacedDigit())
                        .foregroundStyle(Color.bitcoinOrange)
                }
                
                if isTranscribing {
                    ProgressView("Transcribing...")
                        .tint(.bitcoinOrange)
                }
                
                if !transcription.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Transcription")
                                .font(.headline)
                            Spacer()
                            Button {
                                UIPasteboard.general.string = transcription
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                                    .font(.caption)
                            }
                            .tint(.bitcoinOrange)
                        }
                        
                        TextEditor(text: $transcription)
                            .frame(minHeight: 150)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(Color.darkSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .background(Color.darkBackground.ignoresSafeArea())
            .navigationTitle("Transcribe")
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
            .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.audio, .mpeg4Audio, .mp3, .wav]) { result in
                handleFileImport(result)
            }
        }
    }
    
    private func handleRecord() {
        if recorder.isRecording {
            guard let url = recorder.stopRecording() else { return }
            lastSourceType = "recording"
            transcribeFile(at: url, sourceType: "recording", duration: recorder.recordingTime)
        } else {
            do {
                try recorder.startRecording()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func handleFileImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            
            if let data = try? Data(contentsOf: url) {
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                try? data.write(to: tempURL)
                transcribeFile(at: tempURL, sourceType: "import", duration: nil)
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func transcribeFile(at url: URL, sourceType: String, duration: Double?) {
        isTranscribing = true
        Task {
            do {
                let data = try Data(contentsOf: url)
                let text = try await OpenAIService.shared.transcribe(audioData: data, filename: url.lastPathComponent)
                transcription = text
                let record = TranscriptionRecord(sourceType: sourceType, transcribedText: text, duration: duration)
                modelContext.insert(record)
                try? modelContext.save()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isTranscribing = false
        }
    }
}

#Preview {
    TranscribeView()
        .preferredColorScheme(.dark)
}
