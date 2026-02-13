import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct TranscribeView: View {
    @Binding var sharedAudioData: SharedDataHandler.SharedAudioData?
    @Binding var selectedTab: Int
    @Binding var summarizePrefilledText: String
    @Binding var speakPrefilledText: String
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TranscriptionRecord.timestamp, order: .reverse) private var history: [TranscriptionRecord]
    @StateObject private var recorder = AudioRecorder()
    @State private var networkMonitor = NetworkMonitor.shared
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
    
    // #42 — Search & bulk actions
    @State private var searchText = ""
    @State private var isMultiSelectMode = false
    @State private var selectedRecordIDs: Set<UUID> = []
    @State private var showExportSheet = false
    @State private var exportURL: URL?
    
    private var filteredHistory: [TranscriptionRecord] {
        if searchText.isEmpty { return history }
        return history.filter { $0.displayText.localizedCaseInsensitiveContains(searchText) }
    }
    
    private static let dateSectionFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()
    
    // #42 — Date-grouped history
    private var groupedHistory: [(String, [TranscriptionRecord])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredHistory) { record -> String in
            if calendar.isDateInToday(record.timestamp) { return "Today" }
            if calendar.isDateInYesterday(record.timestamp) { return "Yesterday" }
            return Self.dateSectionFormatter.string(from: record.timestamp)
        }
        // Sort groups by newest first
        return grouped.sorted { lhs, rhs in
            (lhs.value.first?.timestamp ?? .distantPast) > (rhs.value.first?.timestamp ?? .distantPast)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Network warning (#40)
                if !networkMonitor.isConnected && sttSettings.provider == .cloud {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "wifi.slash")
                                .foregroundStyle(.red)
                            Text("No internet connection. Cloud transcription unavailable.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .listRowBackground(Color.darkSurface)
                    }
                }
                
                // MARK: - Controls Section
                Section {
                    VStack(spacing: 16) {
                        HStack {
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
                            .accessibilityLabel(continuousMode ? "Continuous mode enabled" : "Single-shot mode")
                            .accessibilityHint("Double-tap to toggle between continuous and single-shot recording")
                            
                            Spacer()
                            
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
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Transcription language: \(sttSettings.languageDisplayCode)")
                            .accessibilityHint("Double-tap to change language")
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
                            .accessibilityLabel(recorder.isRecording ? "Stop recording" : "Start recording")
                            .accessibilityHint(recorder.isRecording ? "Double-tap to stop" : "Double-tap to start voice recording")
                            
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
                            .accessibilityLabel("Import audio file")
                            .accessibilityHint("Double-tap to select an audio file for transcription")
                        }
                        .frame(maxWidth: .infinity)
                        
                        Picker("Provider", selection: $sttSettings.provider) {
                            ForEach(STTProvider.allCases, id: \.self) { provider in
                                Text(provider.rawValue).tag(provider)
                            }
                        }
                        .pickerStyle(.segmented)
                        .disabled(isTranscribing || recorder.isRecording)
                        .accessibilityLabel("Transcription provider")
                        
                        if recorder.isRecording {
                            AudioLevelMeter(level: recorder.audioLevel)
                                .padding(.horizontal)
                                .accessibilityLabel("Audio level: \(Int(recorder.audioLevel * 100)) percent")
                            
                            Text(String(format: "%.1fs", recorder.recordingTime))
                                .font(.title2.monospacedDigit())
                                .foregroundStyle(Color.bitcoinOrange)
                                .accessibilityLabel("Recording time: \(String(format: "%.0f", recorder.recordingTime)) seconds")
                            
                            if continuousMode {
                                Text("Recording continuously — tap Stop to finish")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if isTranscribing {
                            ProgressView("Transcribing...")
                                .tint(.bitcoinOrange)
                                .accessibilityLabel("Transcribing audio, please wait")
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
                                    .accessibilityLabel("Copy transcription")
                                }
                                Text(continuousText)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.darkSurfaceLight)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .textSelection(.enabled)
                            }
                        }
                        
                        // Single-shot transcription result
                        if !transcription.isEmpty && !continuousMode {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Transcription")
                                        .font(.headline)
                                    Spacer()
                                    Button {
                                        UIPasteboard.general.string = transcription
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
                                    .accessibilityLabel("Copy transcription")
                                    
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
                                    .accessibilityLabel("Clear transcription")
                                }
                                
                                if isEditingTranscription {
                                    TextEditor(text: $transcription)
                                        .scrollContentBackground(.hidden)
                                        .padding(8)
                                        .frame(minHeight: 100)
                                        .background(Color.darkSurfaceLight)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .onChange(of: transcription) { _, newValue in
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
                                        .contentShape(Rectangle())
                                        .textSelection(.enabled)
                                        .onTapGesture {
                                            isEditingTranscription = true
                                            if !hasSeenEditHint { hasSeenEditHint = true }
                                        }
                                        .contextMenu {
                                            Button { UIPasteboard.general.string = transcription; HapticService.notification(.success); withAnimation { showCopyToast = true } } label: { Label("Copy", systemImage: "doc.on.doc") }
                                            Button { isEditingTranscription = true } label: { Label("Edit", systemImage: "pencil") }
                                            Button { transcription = ""; HapticService.impact(.light) } label: { Label("Clear", systemImage: "trash") }
                                        }
                                    
                                    if !hasSeenEditHint {
                                        Text("Tap to edit transcription")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .italic()
                                    }
                                }
                                
                                // #43 — Action buttons on transcription result
                                HStack(spacing: 12) {
                                    Button {
                                        summarizePrefilledText = transcription
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            selectedTab = 2
                                        }
                                    } label: {
                                        Label("Summarize This", systemImage: "sparkles")
                                            .font(.caption.weight(.medium))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(Color.darkSurfaceLight)
                                            .foregroundStyle(Color.bitcoinOrange)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel("Summarize this transcription")
                                    .accessibilityHint("Switches to Summarize tab with this text")
                                    
                                    Button {
                                        speakPrefilledText = transcription
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            selectedTab = 1
                                        }
                                    } label: {
                                        Label("Speak This", systemImage: "speaker.wave.2.fill")
                                            .font(.caption.weight(.medium))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(Color.darkSurfaceLight)
                                            .foregroundStyle(Color.bitcoinOrange)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel("Speak this transcription")
                                    .accessibilityHint("Switches to Speak tab")
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.darkSurface)
                } header: {
                    SectionHeader(icon: "mic.fill", title: "Voice to Text")
                }
                
                // MARK: - History Section (#42)
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
                        // Multi-select toolbar (#42)
                        if isMultiSelectMode {
                            HStack {
                                Button("Select All") {
                                    selectedRecordIDs = Set(filteredHistory.map(\.id))
                                }
                                .font(.caption)
                                .foregroundStyle(Color.bitcoinOrange)
                                .buttonStyle(.borderless)
                                
                                Spacer()
                                
                                Text("\(selectedRecordIDs.count) selected")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Spacer()
                                
                                Button("Delete") {
                                    deleteSelectedRecords()
                                }
                                .font(.caption.bold())
                                .foregroundStyle(.red)
                                .disabled(selectedRecordIDs.isEmpty)
                                .buttonStyle(.borderless)
                                
                                Button("Export") {
                                    exportSelectedRecords()
                                }
                                .font(.caption.bold())
                                .foregroundStyle(Color.bitcoinOrange)
                                .disabled(selectedRecordIDs.isEmpty)
                                .buttonStyle(.borderless)
                            }
                            .padding(.vertical, 4)
                            .listRowBackground(Color.darkSurface)
                        }
                        
                        ForEach(groupedHistory, id: \.0) { dateLabel, records in
                            Section {
                                ForEach(records) { record in
                                    HStack(spacing: 8) {
                                        if isMultiSelectMode {
                                            Image(systemName: selectedRecordIDs.contains(record.id) ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(selectedRecordIDs.contains(record.id) ? Color.bitcoinOrange : .secondary)
                                                .onTapGesture {
                                                    if selectedRecordIDs.contains(record.id) {
                                                        selectedRecordIDs.remove(record.id)
                                                    } else {
                                                        selectedRecordIDs.insert(record.id)
                                                    }
                                                }
                                                .accessibilityLabel(selectedRecordIDs.contains(record.id) ? "Selected" : "Not selected")
                                        }
                                        
                                        TranscriptionHistoryRow(
                                            record: record,
                                            isExpanded: expandedRecordID == record.id,
                                            isEditing: editingRecordID == record.id,
                                            editText: editingRecordID == record.id ? $editText : .constant(""),
                                            onToggle: {
                                                if isMultiSelectMode {
                                                    if selectedRecordIDs.contains(record.id) {
                                                        selectedRecordIDs.remove(record.id)
                                                    } else {
                                                        selectedRecordIDs.insert(record.id)
                                                    }
                                                } else if editingRecordID != record.id {
                                                    expandedRecordID = expandedRecordID == record.id ? nil : record.id
                                                }
                                            },
                                            onCopy: {
                                                UIPasteboard.general.string = record.displayText
                                                HapticService.notification(.success)
                                                withAnimation { showCopyToast = true }
                                            },
                                            onEdit: {
                                                if editingRecordID == record.id {
                                                    record.editedText = editText
                                                    try? modelContext.save()
                                                    editingRecordID = nil
                                                } else {
                                                    editText = record.displayText
                                                    editingRecordID = record.id
                                                }
                                            },
                                            // #43 — Actions
                                            onSummarize: {
                                                summarizePrefilledText = record.displayText
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                    selectedTab = 2
                                                }
                                            },
                                            onSpeak: {
                                                speakPrefilledText = record.displayText
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                    selectedTab = 1
                                                }
                                            }
                                        )
                                    }
                                    .listRowBackground(Color.darkSurface)
                                }
                                .onDelete(perform: { offsets in
                                    deleteRecords(from: records, at: offsets)
                                })
                            } header: {
                                Text(dateLabel)
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    SectionHeader(
                        icon: "clock.arrow.circlepath",
                        title: "History",
                        trailingAction: {
                            withAnimation { isMultiSelectMode.toggle() }
                            if !isMultiSelectMode { selectedRecordIDs.removeAll() }
                        },
                        trailingIcon: isMultiSelectMode ? "xmark.circle" : "checklist",
                        trailingLabel: isMultiSelectMode ? "Done" : "Select"
                    )
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.darkBackground.ignoresSafeArea())
            .searchable(text: $searchText, prompt: "Search transcriptions")
            .scrollDismissesKeyboard(.interactively)
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
            .sheet(isPresented: $showExportSheet) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .onChange(of: sharedAudioData) { _, newData in
                if let data = newData {
                    handleSharedAudio(data)
                    sharedAudioData = nil
                }
            }
        }
    }
    
    // MARK: - Delete
    
    private func deleteRecords(from records: [TranscriptionRecord], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(records[index])
        }
        try? modelContext.save()
    }
    
    // #42 — Bulk delete
    private func deleteSelectedRecords() {
        for record in history where selectedRecordIDs.contains(record.id) {
            modelContext.delete(record)
        }
        try? modelContext.save()
        selectedRecordIDs.removeAll()
        isMultiSelectMode = false
        HapticService.notification(.success)
    }
    
    // #42 — Export
    private func exportSelectedRecords() {
        let selected = history.filter { selectedRecordIDs.contains($0.id) }
        guard !selected.isEmpty else { return }
        
        let exportData = selected.map { record -> [String: Any] in
            [
                "id": record.id.uuidString,
                "text": record.displayText,
                "source": record.sourceType,
                "language": record.language ?? "auto",
                "timestamp": ISO8601DateFormatter().string(from: record.timestamp),
                "duration": record.duration ?? 0
            ]
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("voiceflow_transcriptions.json")
            try jsonData.write(to: tempURL)
            exportURL = tempURL
            showExportSheet = true
        } catch {
            errorMessage = "Export failed: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func handleRecord() {
        // #40 — Network check
        if !recorder.isRecording && sttSettings.provider == .cloud && !networkMonitor.isConnected {
            errorMessage = "No internet connection. Switch to On-Device mode or connect to the network."
            showError = true
            return
        }
        
        if recorder.isRecording {
            HapticService.impact(.medium)
            if continuousMode {
                let _ = recorder.stopContinuousRecording()
                UIAccessibility.post(notification: .announcement, argument: "Recording stopped")
            } else {
                guard let url = recorder.stopRecording() else { return }
                lastSourceType = "recording"
                transcribeFile(at: url, sourceType: "recording", duration: recorder.recordingTime)
                UIAccessibility.post(notification: .announcement, argument: "Recording stopped, transcribing")
            }
        } else {
            Task {
                do {
                    try await recorder.ensureMicrophonePermission()
                    HapticService.impact(.heavy)
                    UIAccessibility.post(notification: .announcement, argument: "Recording started")
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
                // #40 — Show error in continuous mode instead of silent failure
                await MainActor.run {
                    errorMessage = "Segment transcription failed: \(error.localizedDescription)"
                    showError = true
                }
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
                UIAccessibility.post(notification: .announcement, argument: "Transcription complete")
            } catch {
                // #40 — User-friendly error messages
                let userMessage: String
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .notConnectedToInternet:
                        userMessage = "No internet connection. Please check your network."
                    case .timedOut:
                        userMessage = "Request timed out. Please try again."
                    default:
                        userMessage = "Network error: \(urlError.localizedDescription)"
                    }
                } else {
                    userMessage = error.localizedDescription
                }
                errorMessage = userMessage
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
    var onToggle: () -> Void = {}
    var onCopy: () -> Void = {}
    var onEdit: () -> Void = {}
    var onSummarize: () -> Void = {} // #43
    var onSpeak: () -> Void = {} // #43
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header area — tappable for expand/collapse
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
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
            }
            .contentShape(Rectangle())
            .onTapGesture { onToggle() }
            
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
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Copy text")
                    
                    Button { onEdit() } label: {
                        Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle.fill")
                            .font(.title3)
                            .foregroundStyle(isEditing ? .green : Color.bitcoinOrange)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(isEditing ? "Save edit" : "Edit text")
                    
                    // #43 — Action buttons
                    Button { onSummarize() } label: {
                        Image(systemName: "sparkles")
                            .font(.title3)
                            .foregroundStyle(Color.bitcoinOrange)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Summarize this text")
                    
                    Button { onSpeak() } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.title3)
                            .foregroundStyle(Color.bitcoinOrange)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Speak this text")
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .contextMenu {
            Button { onCopy() } label: { Label("Copy", systemImage: "doc.on.doc") }
            Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
            Divider()
            Button { onSummarize() } label: { Label("Summarize This", systemImage: "sparkles") }
            Button { onSpeak() } label: { Label("Speak This", systemImage: "speaker.wave.2.fill") }
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
    TranscribeView(sharedAudioData: .constant(nil), selectedTab: .constant(0), summarizePrefilledText: .constant(""), speakPrefilledText: .constant(""))
        .preferredColorScheme(.dark)
}
