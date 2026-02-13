import SwiftUI
import SwiftData

struct SummarizeView: View {
    @Binding var sharedText: SharedDataHandler.SharedTextData?
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SummaryRecord.timestamp, order: .reverse) private var history: [SummaryRecord]
    @State private var inputText = ""
    @State private var summary = ""
    @State private var isSummarizing = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var expandedRecordID: UUID?
    @State private var settings = SummarizeSettings()
    @State private var showCopyToast = false
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Controls Section
                Section {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Text to summarize")
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
                        
                        HStack {
                            Text("Length:")
                                .font(.subheadline)
                            Picker("Length", selection: $settings.length) {
                                ForEach(SummaryLength.allCases, id: \.self) { length in
                                    Text(length.rawValue).tag(length)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        HStack {
                            Text("Format:")
                                .font(.subheadline)
                            Picker("Format", selection: $settings.format) {
                                ForEach(SummaryFormat.allCases, id: \.self) { format in
                                    Text(format.rawValue).tag(format)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        PremiumButton(
                            title: "Summarize",
                            icon: "sparkles",
                            isLoading: isSummarizing,
                            isDisabled: inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ) {
                            summarize()
                        }
                        
                        if !summary.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Summary")
                                        .font(.headline)
                                    Spacer()
                                    Button {
                                        UIPasteboard.general.string = summary
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
                                        summary = ""
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
                                
                                Text(summary)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.darkSurfaceLight)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .textSelection(.enabled)
                                    .contextMenu {
                                        Button {
                                            UIPasteboard.general.string = summary
                                            HapticService.notification(.success)
                                            withAnimation {
                                                showCopyToast = true
                                            }
                                        } label: {
                                            Label("Copy", systemImage: "doc.on.doc")
                                        }
                                        
                                        Button {
                                            summary = ""
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
                } header: {
                    SectionHeader(icon: "sparkles", title: "Summarize")
                }
                
                // MARK: - History Section
                Section {
                    if history.isEmpty {
                        EmptyStateView(
                            icon: "doc.text.magnifyingglass",
                            title: "No Summaries Yet",
                            subtitle: "Your summaries will appear here"
                        )
                        .listRowBackground(Color.darkSurface)
                    } else {
                        ForEach(history) { record in
                            SummaryHistoryRow(record: record, isExpanded: expandedRecordID == record.id) {
                                UIPasteboard.general.string = record.summaryText
                                HapticService.notification(.success)
                                withAnimation { showCopyToast = true }
                            }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    expandedRecordID = expandedRecordID == record.id ? nil : record.id
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
            .scrollDismissesKeyboard(.interactively)
            .background(Color.darkBackground.ignoresSafeArea())
            .navigationTitle("Summarize")
            .toast(isShowing: $showCopyToast, message: "Copied to clipboard")
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
            .onChange(of: sharedText) { _, newData in
                if let data = newData, data.action == "summarize" {
                    inputText = data.text
                    SharedDataHandler.clearSharedText()
                    sharedText = nil
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
    
    private func summarize() {
        HapticService.impact(.medium)
        isSummarizing = true
        Task {
            do {
                let systemPrompt = settings.buildSystemPrompt()
                let result = try await OpenAIService.shared.summarize(text: inputText, systemPrompt: systemPrompt)
                summary = result
                HapticService.notification(.success)
                let record = SummaryRecord(inputText: inputText, summaryText: result)
                modelContext.insert(record)
                try? modelContext.save()
            } catch {
                HapticService.notification(.error)
                errorMessage = error.localizedDescription
                showError = true
            }
            isSummarizing = false
        }
    }
}

// MARK: - History Row

private struct SummaryHistoryRow: View {
    let record: SummaryRecord
    let isExpanded: Bool
    var onCopy: () -> Void = {}
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(record.inputText)
                    .lineLimit(isExpanded ? nil : 2)
                Spacer()
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
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Original")
                            .font(.caption.bold())
                            .foregroundStyle(Color.bitcoinOrange)
                        Spacer()
                        Button {
                            UIPasteboard.general.string = record.inputText
                            HapticService.notification(.success)
                        } label: {
                            Image(systemName: "doc.on.doc.fill")
                                .font(.caption)
                                .foregroundStyle(Color.bitcoinOrange)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    Text(record.inputText)
                        .font(.body)
                        .textSelection(.enabled)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Summary")
                            .font(.caption.bold())
                            .foregroundStyle(Color.bitcoinOrange)
                        Spacer()
                        Button {
                            onCopy()
                        } label: {
                            Image(systemName: "doc.on.doc.fill")
                                .font(.caption)
                                .foregroundStyle(Color.bitcoinOrange)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    Text(record.summaryText)
                        .font(.body)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button {
                UIPasteboard.general.string = record.inputText
                HapticService.notification(.success)
            } label: {
                Label("Copy Original", systemImage: "doc.on.doc")
            }
            Button { onCopy() } label: {
                Label("Copy Summary", systemImage: "doc.on.doc.fill")
            }
        }
    }
}

#Preview {
    SummarizeView(sharedText: .constant(nil))
        .preferredColorScheme(.dark)
}
