import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct TranscribeView: View {
    @Binding var sharedAudioData: SharedDataHandler.SharedAudioData?
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TranscriptionRecord.timestamp, order: .reverse) private var history: [TranscriptionRecord]
    @StateObject private var recorder = AudioRecorder()
    @State private var transcription = ""
    @State private var isTranscribing = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showFilePicker = false
    @State private var lastSourceType = "recording"
    @State private var expandedRecordID: UUID?
    @State private var showCopyToast = false
    @State private var sttSettings = STTSettings()
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Controls Section
                Section {
                    VStack(spacing: 16) {
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
                            .buttonStyle(.plain)
                            
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
                            .buttonStyle(.plain)
                            .disabled(isTranscribing)
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Provider toggle
                        Picker("Provider", selection: $sttSettings.provider) {
                            ForEach(STTProvider.allCases, id: \.self) { provider in
                                Text(provider.rawValue).tag(provider)
                            }
                        }
                        .pickerStyle(.segmented)
                        .disabled(isTranscribing || recorder.isRecording)
                        
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
                                        HapticService.notification(.success)
                                        withAnimation {
                                            showCopyToast = true
                                        }
                                    } label: {
                                        Label("Copy", systemImage: "doc.on.doc")
                                            .font(.caption)
                                    }
                                    .tint(.bitcoinOrange)
                                    
                                    Button {
                                        transcription = ""
                                        HapticService.impact(.light)
                                    } label: {
                                        Label("Clear", systemImage: "trash")
                                            .font(.caption)
                                    }
                                    .tint(.red)
                                }
                                
                                Text(transcription)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.darkSurfaceLight)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .textSelection(.enabled)
                                    .contextMenu {
                                        Button {
                                            UIPasteboard.general.string = transcription
                                            HapticService.notification(.success)
                                            withAnimation {
                                                showCopyToast = true
                                            }
                                        } label: {
                                            Label("Copy", systemImage: "doc.on.doc")
                                        }
                                        
                                        Button {
                                            transcription = ""
                                            HapticService.impact(.light)
                                        } label: {
                                            Label("Clear", systemImage: "trash")
                                        }
                                    }
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
                            TranscriptionHistoryRow(record: record, isExpanded: expandedRecordID == record.id)
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
            .navigationTitle("Transcribe")
            .toast(isShowing: $showCopyToast, message: "Copied to clipboard")
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
            .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.audio, .mpeg4Audio, .mp3, .wav]) { result in
                handleFileImport(result)
            }
            .onChange(of: sharedAudioData) { _, newData in
                if let data = newData {
                    handleSharedAudio(data)
                    sharedAudioData = nil
                }
            }
        }
    }
    
    private func deleteRecords(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(history[index])
        }
        try? modelContext.save()
    }
    
    private func handleRecord() {
        if recorder.isRecording {
            HapticService.impact(.medium)
            guard let url = recorder.stopRecording() else { return }
            lastSourceType = "recording"
            transcribeFile(at: url, sourceType: "recording", duration: recorder.recordingTime)
        } else {
            do {
                HapticService.impact(.heavy)
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
                let text: String
                
                switch sttSettings.provider {
                case .cloud:
                    let data = try Data(contentsOf: url)
                    text = try await OpenAIService.shared.transcribe(audioData: data, filename: url.lastPathComponent)
                    
                case .local:
                    text = try await WhisperKitService.shared.transcribe(audioURL: url)
                }
                
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
    
    private func handleSharedAudio(_ data: SharedDataHandler.SharedAudioData) {
        transcribeFile(at: data.fileURL, sourceType: "share", duration: nil)
        // Clean up shared data
        SharedDataHandler.clearSharedAudio()
    }
}

// MARK: - History Row

private struct TranscriptionHistoryRow: View {
    let record: TranscriptionRecord
    let isExpanded: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: record.sourceType == "recording" ? "mic.fill" : "doc.fill")
                    .foregroundStyle(Color.bitcoinOrange)
                    .font(.caption)
                Text(record.transcribedText)
                    .lineLimit(isExpanded ? nil : 2)
                Spacer()
            }
            
            Text(record.timestamp, style: .relative)
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            if isExpanded {
                Divider()
                Text(record.transcribedText)
                    .font(.body)
                    .textSelection(.enabled)
                
                Button {
                    UIPasteboard.general.string = record.transcribedText
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .tint(.bitcoinOrange)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TranscribeView()
        .preferredColorScheme(.dark)
}
