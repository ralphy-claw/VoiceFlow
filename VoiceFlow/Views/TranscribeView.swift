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
    
    // #25 — Continuous mode
    @State private var continuousMode = false
    @State private var continuousText = ""
    
    // #26 — Language
    @State private var showLanguagePicker = false
    
    // #27 — Editing
    @State private var isEditingTranscription = false
    @State private var editingRecordID: UUID?
    @State private var editText = ""
    @State private var currentTranscriptionRecord: TranscriptionRecord?
    @AppStorage("hasSeenEditHint") private var hasSeenEditHint = false
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Controls Section
                Section {
                    VStack(spacing: 16) {
                        // Mode toggle & language button
                        HStack {
                            // Continuous mode toggle (#25)
                            Toggle(isOn: $continuousMode) {
                                HStack(spacing: 4) {
                                    Image(systemName: continuousMode ? "waveform" : "mic.fill")
                                        .font(.caption)
                                    Text(continuousMode ? "Continuous" : "Single-shot")
                                        .font(.caption)
                                }
                            }
                            .toggleStyle(.button)
                            .tint(.bitcoinOrange)
                            .disabled(recorder.isRecording)
                            
                            Spacer()
                            
                            // Language quick toggle (#26)
                            Button {
                                showLanguagePicker = true
                            } label: {
                                Text(sttSettings.languageDisplayCode)
                                    .font(.caption.bold().monospaced())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.darkSurfaceLight)
                                    .clipShape(Capsule())
                                    .foregroundStyle(Color.bitcoinOrange)
                            }
                        }
                        
                        HStack(spacing: 30) {
                            Button {
                                handleRecord()
                            } label: {
                                VStack(spacing: 8) {
                                    ZStack {
                                        Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                            .font(.system(size: 60))
                                            .foregroundStyle(recorder.isRecording ? Color.red : Color.bitcoinOrange)
                                        
                                        if recorder.isRecording {
                                            RecordingIndicator(isRecording: true)
                                                .offset(x: 24, y: -24)
                                        }
                                    }
                                    Text(recorder.isRecording ? (continuousMode ? "Finish" : "Stop") : "Record")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(ScaleButtonStyle())
                            
                            Button {
                                showFilePicker = true
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: "doc.badge.plus")
                                        .font(.system(size: 50))
                                        .foregroundStyle(Color.bitcoinOrange)
                                    Text("Import")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(ScaleButtonStyle())
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
                        
                        // Audio level meter (#25)
                        if recorder.isRecording {
                            AudioLevelMeter(level: recorder.audioLevel)
                                .padding(.horizontal)
                            
                            Text(String(format: "%.1fs", recorder.recordingTime))
                                .font(.title2.monospacedDigit())
                                .foregroundStyle(Color.bitcoinOrange)
                            
                            if continuousMode {
                                Text("Recording continuously — tap Stop to finish")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if isTranscribing {
                            ProgressView("Transcribing...")
                                .tint(.bitcoinOrange)
                        }
                        
                        // Continuous mode accumulated text
                        if continuousMode && !continuousText.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Continuous Transcription")
                                        .font(.headline)
                                    Spacer()
                                    Button {
                                        UIPasteboard.general.string = continuousText
                                        HapticService.notification(.success)
                                        withAnimation { showCopyToast = true }
                                    } label: {
                                        Image(systemName: "doc.on.doc.fill")
                                            .font(.body)
                                            .foregroundStyle(Color.bitcoinOrange)
                                            .frame(width: 36, height: 36)
                                            .background(Color.darkSurfaceLight)
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                                Text(continuousText)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.darkSurfaceLight)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .textSelection(.enabled)
                            }
                        }
                        
                        // Single-shot transcription result (#27 — editable)
                        if !transcription.isEmpty && !continuousMode {
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
                                        Image(systemName: "doc.on.doc.fill")
                                            .font(.body)
                                            .foregroundStyle(Color.bitcoinOrange)
                                            .frame(width: 36, height: 36)
                                            .background(Color.darkSurfaceLight)
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    
                                    Button {
                                        transcription = ""
                                        isEditingTranscription = false
                                        HapticService.impact(.light)
                                    } label: {
                                        Image(systemName: "trash.fill")
                                            .font(.body)
                                            .foregroundStyle(.red)
                                            .frame(width: 36, height: 36)
                                            .background(Color.darkSurfaceLight)
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                                
                                if isEditingTranscription {
                                    TextEditor(text: $transcription)
                                        .scrollContentBackground(.hidden)
                                        .padding(8)
                                        .frame(minHeight: 100)
                                        .background(Color.darkSurfaceLight)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .onChange(of: transcription) { _, newValue in
                                            // Save edits back to the record
                                            if let record = currentTranscriptionRecord {
                                                record.editedText = newValue
                                                try? modelContext.save()
                                            }
                                        }
                                    
                                    Button("Done Editing") {
                                        isEditingTranscription = false
                                        HapticService.impact(.light)
                                    }
                                    .font(.caption)
                                    .foregroundStyle(Color.bitcoinOrange)
                                } else {
                                    Text(transcription)
                                        .padding(8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.darkSurfaceLight)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .textSelection(.enabled)
                                        .onTapGesture {
                                            isEditingTranscription = true
                                            if !hasSeenEditHint {
                                                hasSeenEditHint = true
                                            }
                                        }
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
                                                isEditingTranscription = true
                                            } label: {
                                                Label("Edit", systemImage: "pencil")
                                            }
                                            
                                            Button {
                                                transcription = ""
                                                HapticService.impact(.light)
                                            } label: {
                                                Label("Clear", systemImage: "trash")
                                            }
                                        }
                                    
                                    // "Tap to edit" hint (#27)
                                    if !hasSeenEditHint {
                                        Text("Tap to edit transcription")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .italic()
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.darkSurface)
                } header: {
                    SectionHeader(icon: "mic.fill", title: "Voice to Text")
                }
                
                // MARK: - History Section
                Section {
                    if history.isEmpty {
                        EmptyStateView(
                            icon: "clock.arrow.circlepath",
                            title: "No History Yet",
                            subtitle: "Your transcriptions will appear here",
                            ctaTitle: "Start Recording",
                            ctaIcon: "mic.fill",
                            ctaAction: { handleRecord() }
                        )
                        .listRowBackground(Color.darkSurface)
                    } else {
                        ForEach(history) { record in
                            TranscriptionHistoryRow(
                                record: record,
                                isExpanded: expandedRecordID == record.id,
                                isEditing: editingRecordID == record.id,
                                editText: editingRecordID == record.id ? $editText : .constant(""),
                                onCopy: {
                                    UIPasteboard.general.string = record.displayText
                                    HapticService.notification(.success)
                                    withAnimation { showCopyToast = true }
                                },
                                onEdit: {
                                    if editingRecordID == record.id {
                                        // Save and stop editing
                                        record.editedText = editText
                                        try? modelContext.save()
                                        editingRecordID = nil
                                    } else {
                                        editText = record.displayText
                                        editingRecordID = record.id
                                    }
                                }
                            )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if editingRecordID != record.id {
                                        expandedRecordID = expandedRecordID == record.id ? nil : record.id
                                    }
                                }
                                .listRowBackground(Color.darkSurface)
                        }
                        .onDelete(perform: deleteRecords)
                    }
                } header: {
                    SectionHeader(icon: "clock.arrow.circlepath", title: "History")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.darkBackground.ignoresSafeArea())
            .simultaneousGesture(TapGesture().onEnded {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            })
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
            .sheet(isPresented: $showLanguagePicker) {
                LanguagePickerView(selectedLanguage: $sttSettings.language)
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
            if continuousMode {
                let _ = recorder.stopContinuousRecording()
                // Don't transcribe the final segment separately — it would
                // duplicate the per-segment records already created via
                // transcribeSegment. Just keep the accumulated continuousText.
            } else {
                guard let url = recorder.stopRecording() else { return }
                lastSourceType = "recording"
                transcribeFile(at: url, sourceType: "recording", duration: recorder.recordingTime)
            }
        } else {
            do {
                HapticService.impact(.heavy)
                if continuousMode {
                    continuousText = ""
                    try recorder.startContinuousRecording { segmentURL in
                        transcribeSegment(at: segmentURL)
                    }
                } else {
                    try recorder.startRecording()
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func transcribeSegment(at url: URL) {
        Task {
            do {
                let data = try Data(contentsOf: url)
                let lang = sttSettings.language
                let text = try await OpenAIService.shared.transcribe(
                    audioData: data,
                    filename: url.lastPathComponent,
                    language: lang == "auto" ? nil : lang
                )
                if !text.isEmpty {
                    if continuousText.isEmpty {
                        continuousText = text
                    } else {
                        continuousText += "\n" + text
                    }
                }
            } catch {
                // Silently continue in continuous mode
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
                let lang = sttSettings.language
                
                switch sttSettings.provider {
                case .cloud:
                    let data = try Data(contentsOf: url)
                    text = try await OpenAIService.shared.transcribe(
                        audioData: data,
                        filename: url.lastPathComponent,
                        language: lang == "auto" ? nil : lang
                    )
                    
                case .local:
                    text = try await WhisperKitService.shared.transcribe(
                        audioURL: url,
                        language: lang == "auto" ? nil : lang
                    )
                }
                
                transcription = text
                isEditingTranscription = false
                let record = TranscriptionRecord(
                    sourceType: sourceType,
                    transcribedText: text,
                    duration: duration,
                    language: lang
                )
                modelContext.insert(record)
                try? modelContext.save()
                currentTranscriptionRecord = record
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isTranscribing = false
        }
    }
    
    private func handleSharedAudio(_ data: SharedDataHandler.SharedAudioData) {
        transcribeFile(at: data.fileURL, sourceType: "share", duration: nil)
        SharedDataHandler.clearSharedAudio()
    }
}

// MARK: - History Row

private struct TranscriptionHistoryRow: View {
    let record: TranscriptionRecord
    let isExpanded: Bool
    var isEditing: Bool = false
    @Binding var editText: String
    var onCopy: () -> Void = {}
    var onEdit: () -> Void = {}
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: iconName)
                    .foregroundStyle(Color.bitcoinOrange)
                    .font(.caption)
                Text(record.displayText)
                    .lineLimit(isExpanded ? nil : 2)
                Spacer()
                if let lang = record.language, lang != "auto" {
                    Text(lang.uppercased())
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            
            Text(record.timestamp, style: .relative)
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            if isExpanded {
                Divider()
                
                if isEditing {
                    TextEditor(text: $editText)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .frame(minHeight: 80)
                        .background(Color.darkSurfaceLight)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Text(record.displayText)
                        .font(.body)
                        .textSelection(.enabled)
                    
                    if record.editedText != nil {
                        Text("Edited")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                }
                
                HStack(spacing: 16) {
                    Button { onCopy() } label: {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.title3)
                            .foregroundStyle(Color.bitcoinOrange)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    
                    Button { onEdit() } label: {
                        Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle.fill")
                            .font(.title3)
                            .foregroundStyle(isEditing ? .green : Color.bitcoinOrange)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button { onCopy() } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            Button { onEdit() } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
    }
    
    private var iconName: String {
        switch record.sourceType {
        case "continuous": return "waveform"
        case "recording": return "mic.fill"
        default: return "doc.fill"
        }
    }
}

#Preview {
    TranscribeView(sharedAudioData: .constant(nil))
        .preferredColorScheme(.dark)
}
