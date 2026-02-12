import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct TranscribeView: View {
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
                                
                                Text(transcription)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.darkSurfaceLight)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
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
    
    private func deleteRecords(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(history[index])
        }
        try? modelContext.save()
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
