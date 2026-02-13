import SwiftUI
import SwiftData

struct PromptsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PromptRecord.timestamp, order: .reverse) private var history: [PromptRecord]
    @StateObject private var recorder = AudioRecorder()

    // MARK: - State
    @State private var isRecording = false
    @State private var isTranscribing = false
    @State private var isEnhancing = false
    @State private var rawTranscription = ""
    @State private var enhancedPrompt = ""
    @State private var selectedPreset: PromptPreset = .none
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showCopyToast = false

    // Image generation
    @State private var isGeneratingImage = false
    @State private var generatedImage: UIImage?

    // Creation flow
    @State private var showCreator = false

    // Detail/edit
    @State private var editingRecord: PromptRecord?

    // History filters
    @State private var searchText = ""
    @State private var filterFavorites = false

    private var filteredHistory: [PromptRecord] {
        var items = history
        if filterFavorites { items = items.filter { $0.isFavorite } }
        if !searchText.isEmpty {
            items = items.filter {
                $0.originalText.localizedCaseInsensitiveContains(searchText) ||
                $0.enhancedText.localizedCaseInsensitiveContains(searchText)
            }
        }
        return items
    }

    private static let dateSectionFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    private var groupedHistory: [(String, [PromptRecord])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredHistory) { record -> String in
            if calendar.isDateInToday(record.timestamp) { return "Today" }
            if calendar.isDateInYesterday(record.timestamp) { return "Yesterday" }
            return Self.dateSectionFormatter.string(from: record.timestamp)
        }
        return grouped.sorted { lhs, rhs in
            (lhs.value.first?.timestamp ?? .distantPast) > (rhs.value.first?.timestamp ?? .distantPast)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Creator Section
                if showCreator {
                    creatorSection
                }

                // MARK: - Filter bar
                if !history.isEmpty {
                    Section {
                        HStack(spacing: 12) {
                            Button {
                                HapticService.impact(.light)
                                filterFavorites = false
                            } label: {
                                Text("All")
                                    .font(.subheadline.weight(filterFavorites ? .regular : .semibold))
                                    .foregroundStyle(filterFavorites ? .secondary : Color.bitcoinOrange)
                            }
                            .buttonStyle(.borderless)

                            Button {
                                HapticService.impact(.light)
                                filterFavorites = true
                            } label: {
                                Label("Favorites", systemImage: "star.fill")
                                    .font(.subheadline.weight(filterFavorites ? .semibold : .regular))
                                    .foregroundStyle(filterFavorites ? Color.bitcoinOrange : .secondary)
                            }
                            .buttonStyle(.borderless)

                            Spacer()
                        }
                    }
                    .listRowBackground(Color.darkSurface)
                }

                // MARK: - History
                if filteredHistory.isEmpty && !showCreator {
                    Section {
                        EmptyStateView(
                            icon: "sparkles.rectangle.stack",
                            title: "No Prompts Yet",
                            subtitle: "Speak your idea and AI will craft the perfect image generation prompt",
                            ctaTitle: "Create Prompt",
                            ctaIcon: "plus",
                            ctaAction: { showCreator = true }
                        )
                    }
                    .listRowBackground(Color.darkSurface)
                } else {
                    ForEach(groupedHistory, id: \.0) { section, records in
                        Section {
                            ForEach(records) { record in
                                promptRow(record)
                            }
                            .onDelete { offsets in
                                deleteRecords(offsets: offsets, from: records)
                            }
                        } header: {
                            Text(section)
                                .foregroundStyle(.secondary)
                        }
                        .listRowBackground(Color.darkSurface)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.darkBackground)
            .searchable(text: $searchText, prompt: "Search prompts")
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Prompts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticService.impact(.light)
                        resetCreator()
                        showCreator = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
            .overlay {
                if showCopyToast {
                    VStack {
                        Spacer()
                        Text("Copied!")
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(.bottom, 32)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .allowsHitTesting(false)
                }
            }
            .sheet(item: $editingRecord) { record in
                PromptDetailView(record: record)
            }
        }
    }

    // MARK: - Creator Section
    private var creatorSection: some View {
        Section {
            VStack(spacing: 16) {
                // Preset picker
                presetPicker

                // Record / type area
                inputArea

                // Enhanced result
                if !enhancedPrompt.isEmpty {
                    enhancedArea
                }
            }
            .padding(.vertical, 8)
        } header: {
            HStack {
                Text("New Prompt")
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showCreator = false
                    resetCreator()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .listRowBackground(Color.darkSurface)
    }

    // MARK: - Preset Picker
    private var presetPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PromptPreset.allCases) { preset in
                    Button {
                        HapticService.impact(.light)
                        selectedPreset = preset
                    } label: {
                        Label(preset.rawValue, systemImage: preset.icon)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                selectedPreset == preset
                                    ? Color.bitcoinOrange.opacity(0.2)
                                    : Color.darkSurfaceLight
                            )
                            .foregroundStyle(selectedPreset == preset ? Color.bitcoinOrange : .secondary)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(selectedPreset == preset ? Color.bitcoinOrange : .clear, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    // MARK: - Input Area (Recording + Text)
    private var inputArea: some View {
        VStack(spacing: 12) {
            Button {
                HapticService.impact(.medium)
                if recorder.isRecording {
                    stopAndTranscribe()
                } else {
                    startRecording()
                }
            } label: {
                HStack(spacing: 8) {
                    if isTranscribing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                    }
                    Text(isTranscribing ? "Transcribing..." : recorder.isRecording ? "Stop" : "Record your idea")
                        .font(.subheadline.weight(.medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(recorder.isRecording ? Color.red : Color.bitcoinOrange)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.borderless)
            .disabled(isTranscribing)

            Text("Or type your idea below")
                .font(.caption)
                .foregroundStyle(.tertiary)

            HStack(spacing: 8) {
                TextField("Describe your image idea...", text: $rawTranscription, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .lineLimit(3...6)

                if !rawTranscription.isEmpty {
                    Button {
                        HapticService.impact(.light)
                        enhancePrompt()
                    } label: {
                        Image(systemName: "sparkles")
                            .font(.title3)
                            .foregroundStyle(Color.bitcoinOrange)
                    }
                    .buttonStyle(.borderless)
                    .disabled(isEnhancing)
                }
            }

            if !rawTranscription.isEmpty {
                HStack(spacing: 12) {
                    Button {
                        HapticService.impact(.light)
                        enhancePrompt()
                    } label: {
                        HStack(spacing: 4) {
                            if isEnhancing {
                                ProgressView()
                                    .tint(Color.bitcoinOrange)
                                    .scaleEffect(0.8)
                            }
                            Text(isEnhancing ? "Enhancing..." : enhancedPrompt.isEmpty ? "Enhance" : "Re-enhance")
                                .font(.subheadline.weight(.medium))
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.bitcoinOrange)
                    .disabled(isEnhancing)

                    Button {
                        rawTranscription = ""
                        enhancedPrompt = ""
                    } label: {
                        Text("Clear")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                }
            }
        }
    }

    // MARK: - Enhanced Area
    private var enhancedArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Enhanced Prompt")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                if selectedPreset.modifier != nil {
                    Text(selectedPreset.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.bitcoinOrange.opacity(0.2))
                        .foregroundStyle(Color.bitcoinOrange)
                        .clipShape(Capsule())
                }
            }

            Text(enhancedPrompt)
                .font(.subheadline)
                .textSelection(.enabled)

            HStack(spacing: 12) {
                Button {
                    HapticService.impact(.light)
                    UIPasteboard.general.string = enhancedPrompt
                    withAnimation { showCopyToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { showCopyToast = false }
                    }
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.bordered)
                .tint(.bitcoinOrange)

                Button {
                    HapticService.impact(.light)
                    savePrompt()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.bordered)
                .tint(.bitcoinOrange)

                ShareLink(item: enhancedPrompt) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            }
            
            // Generate Image button
            Button {
                HapticService.impact(.medium)
                generateImage(from: enhancedPrompt)
            } label: {
                HStack(spacing: 6) {
                    if isGeneratingImage {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "photo.badge.plus")
                    }
                    Text(isGeneratingImage ? "Generating..." : "Generate Image")
                        .font(.subheadline.weight(.medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.bitcoinOrange)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.borderless)
            .disabled(isGeneratingImage)
            
            if let image = generatedImage {
                VStack(spacing: 8) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Button {
                        HapticService.impact(.light)
                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                        withAnimation { showCopyToast = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { showCopyToast = false }
                        }
                    } label: {
                        Label("Save to Photos", systemImage: "square.and.arrow.down")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.bitcoinOrange)
                }
            }
        }
    }

    // MARK: - Prompt Row
    private func promptRow(_ record: PromptRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(record.enhancedText)
                    .font(.subheadline)
                    .lineLimit(3)
                Spacer(minLength: 8)
                Button {
                    HapticService.impact(.light)
                    record.isFavorite.toggle()
                } label: {
                    Image(systemName: record.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(record.isFavorite ? Color.bitcoinOrange : .secondary)
                        .font(.body)
                }
                .buttonStyle(.borderless)
            }

            HStack {
                if let preset = record.preset {
                    Text(preset)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.bitcoinOrange.opacity(0.15))
                        .foregroundStyle(Color.bitcoinOrange)
                        .clipShape(Capsule())
                }
                Spacer()
                Text(record.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 12) {
                Button {
                    HapticService.impact(.light)
                    UIPasteboard.general.string = record.enhancedText
                    withAnimation { showCopyToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { showCopyToast = false }
                    }
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Color.bitcoinOrange)

                ShareLink(item: record.enhancedText) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)

                Button {
                    HapticService.impact(.light)
                    editingRecord = record
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    // MARK: - Actions
    private func startRecording() {
        try? recorder.startRecording()
    }

    private func stopAndTranscribe() {
        guard let url = recorder.stopRecording() else { return }
        isTranscribing = true
        Task {
            do {
                let data = try Data(contentsOf: url)
                let text = try await OpenAIService.shared.transcribe(audioData: data, filename: "prompt.m4a")
                await MainActor.run {
                    rawTranscription = text
                    isTranscribing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isTranscribing = false
                }
            }
        }
    }

    private func enhancePrompt() {
        isEnhancing = true
        let systemPrompt = "You are a prompt engineer. Transform the user's rough idea into a detailed, effective image generation prompt. Be specific about style, lighting, composition, camera angle. Keep it under 200 words."
        var userText = rawTranscription
        if let modifier = selectedPreset.modifier {
            userText += "\n\nApply this style: \(modifier)"
        }
        Task {
            do {
                let result = try await OpenAIService.shared.summarize(text: userText, systemPrompt: systemPrompt)
                await MainActor.run {
                    enhancedPrompt = result
                    isEnhancing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isEnhancing = false
                }
            }
        }
    }

    private func savePrompt() {
        let record = PromptRecord(
            originalText: rawTranscription,
            enhancedText: enhancedPrompt,
            preset: selectedPreset == .none ? nil : selectedPreset.rawValue
        )
        modelContext.insert(record)
        HapticService.notification(.success)
        resetCreator()
        showCreator = false
    }

    private func generateImage(from prompt: String) {
        isGeneratingImage = true
        generatedImage = nil
        Task {
            do {
                let image = try await GeminiImageService.shared.generateImage(prompt: prompt)
                await MainActor.run {
                    generatedImage = image
                    isGeneratingImage = false
                    HapticService.notification(.success)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isGeneratingImage = false
                    HapticService.notification(.error)
                }
            }
        }
    }

    private func resetCreator() {
        rawTranscription = ""
        enhancedPrompt = ""
        selectedPreset = .none
        generatedImage = nil
        isGeneratingImage = false
    }

    private func deleteRecords(offsets: IndexSet, from records: [PromptRecord]) {
        for offset in offsets {
            modelContext.delete(records[offset])
        }
    }
}

// MARK: - Detail/Edit View
struct PromptDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let record: PromptRecord

    @State private var editedText: String = ""
    @State private var isEnhancing = false
    @State private var showCopyToast = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            List {
                Section("Original") {
                    Text(record.originalText)
                        .font(.subheadline)
                        .textSelection(.enabled)

                    Button {
                        HapticService.impact(.light)
                        UIPasteboard.general.string = record.originalText
                        withAnimation { showCopyToast = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { showCopyToast = false }
                        }
                    } label: {
                        Label("Copy Original", systemImage: "doc.on.doc")
                            .font(.subheadline)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.bitcoinOrange)
                }
                .listRowBackground(Color.darkSurface)

                Section("Enhanced Prompt") {
                    TextEditor(text: $editedText)
                        .font(.subheadline)
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)

                    HStack(spacing: 12) {
                        Button {
                            HapticService.impact(.light)
                            reEnhance()
                        } label: {
                            HStack(spacing: 4) {
                                if isEnhancing {
                                    ProgressView().tint(Color.bitcoinOrange).scaleEffect(0.8)
                                }
                                Text(isEnhancing ? "Enhancing..." : "Re-enhance")
                                    .font(.subheadline.weight(.medium))
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(.bitcoinOrange)
                        .disabled(isEnhancing)

                        Button {
                            HapticService.impact(.light)
                            enhanceMore()
                        } label: {
                            Text("Enhance more")
                                .font(.subheadline.weight(.medium))
                        }
                        .buttonStyle(.bordered)
                        .tint(.bitcoinOrange)
                        .disabled(isEnhancing)
                    }

                    Button {
                        HapticService.impact(.light)
                        UIPasteboard.general.string = editedText
                        withAnimation { showCopyToast = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { showCopyToast = false }
                        }
                    } label: {
                        Label("Copy Enhanced", systemImage: "doc.on.doc")
                            .font(.subheadline)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.bitcoinOrange)

                    ShareLink(item: editedText) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.subheadline)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.darkSurface)

                if let preset = record.preset {
                    Section("Preset") {
                        Text(preset)
                            .font(.subheadline)
                            .foregroundStyle(Color.bitcoinOrange)
                    }
                    .listRowBackground(Color.darkSurface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.darkBackground)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Edit Prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.borderless)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        record.enhancedText = editedText
                        dismiss()
                    }
                    .buttonStyle(.borderless)
                    .fontWeight(.semibold)
                }
            }
            .onAppear { editedText = record.enhancedText }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
            .overlay {
                if showCopyToast {
                    VStack {
                        Spacer()
                        Text("Copied!")
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(.bottom, 32)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .allowsHitTesting(false)
                }
            }
        }
    }

    private func reEnhance() {
        isEnhancing = true
        let systemPrompt = "You are a prompt engineer. Transform the user's rough idea into a detailed, effective image generation prompt. Be specific about style, lighting, composition, camera angle. Keep it under 200 words."
        Task {
            do {
                let result = try await OpenAIService.shared.summarize(text: record.originalText, systemPrompt: systemPrompt)
                await MainActor.run {
                    editedText = result
                    isEnhancing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isEnhancing = false
                }
            }
        }
    }

    private func enhanceMore() {
        isEnhancing = true
        let systemPrompt = "You are a prompt engineer. Take this existing image generation prompt and make it even more detailed and effective. Add more specificity about lighting, textures, mood, and technical details. Keep it under 250 words."
        Task {
            do {
                let result = try await OpenAIService.shared.summarize(text: editedText, systemPrompt: systemPrompt)
                await MainActor.run {
                    editedText = result
                    isEnhancing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isEnhancing = false
                }
            }
        }
    }
}

#Preview {
    PromptsView()
        .preferredColorScheme(.dark)
}
