import SwiftUI
import UniformTypeIdentifiers

struct TranscribeView: View {
    @StateObject private var recorder = AudioRecorder()
    @State private var transcription = ""
    @State private var isTranscribing = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showFilePicker = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Recording controls
                HStack(spacing: 30) {
                    // Record button
                    Button {
                        handleRecord()
                    } label: {
                        VStack {
                            Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(recorder.isRecording ? .red : .blue)
                            Text(recorder.isRecording ? "Stop" : "Record")
                                .font(.caption)
                        }
                    }
                    
                    // Import button
                    Button {
                        showFilePicker = true
                    } label: {
                        VStack {
                            Image(systemName: "doc.badge.plus")
                                .font(.system(size: 50))
                                .foregroundStyle(.blue)
                            Text("Import")
                                .font(.caption)
                        }
                    }
                    .disabled(isTranscribing)
                }
                .padding(.top)
                
                if recorder.isRecording {
                    Text(String(format: "%.1fs", recorder.recordingTime))
                        .font(.title2.monospacedDigit())
                        .foregroundStyle(.red)
                }
                
                if isTranscribing {
                    ProgressView("Transcribing...")
                }
                
                // Transcription result
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
                        }
                        
                        TextEditor(text: $transcription)
                            .frame(minHeight: 150)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
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
            transcribeFile(at: url)
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
                transcribeFile(at: tempURL)
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func transcribeFile(at url: URL) {
        isTranscribing = true
        Task {
            do {
                let data = try Data(contentsOf: url)
                let text = try await OpenAIService.shared.transcribe(audioData: data, filename: url.lastPathComponent)
                transcription = text
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
}
