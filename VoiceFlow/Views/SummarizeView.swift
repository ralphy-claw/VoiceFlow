import SwiftUI
import SwiftData

struct SummarizeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SummaryRecord.timestamp, order: .reverse) private var history: [SummaryRecord]
    @State private var inputText = ""
    @State private var summary = ""
    @State private var isSummarizing = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var expandedRecordID: UUID?
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Controls Section
                Section {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Text to summarize")
                                .font(.headline)
                            
                            TextField("Enter text...", text: $inputText, axis: .vertical)
                                .lineLimit(3...6)
                                .padding(8)
                                .background(Color.darkSurfaceLight)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        Button {
                            summarize()
                        } label: {
                            if isSummarizing {
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Label("Summarize", systemImage: "sparkles")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.bitcoinOrange)
                        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSummarizing)
                        
                        if !summary.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Summary")
                                        .font(.headline)
                                    Spacer()
                                    Button {
                                        UIPasteboard.general.string = summary
                                    } label: {
                                        Label("Copy", systemImage: "doc.on.doc")
                                            .font(.caption)
                                    }
                                    .tint(.bitcoinOrange)
                                }
                                
                                Text(summary)
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
                            SummaryHistoryRow(record: record, isExpanded: expandedRecordID == record.id)
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
            .navigationTitle("Summarize")
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "Unknown error")
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
        isSummarizing = true
        Task {
            do {
                let result = try await OpenAIService.shared.summarize(text: inputText)
                summary = result
                let record = SummaryRecord(inputText: inputText, summaryText: result)
                modelContext.insert(record)
                try? modelContext.save()
            } catch {
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(record.inputText)
                .lineLimit(isExpanded ? nil : 2)
            
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
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(.caption2)
                        }
                        .tint(.bitcoinOrange)
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
                            UIPasteboard.general.string = record.summaryText
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(.caption2)
                        }
                        .tint(.bitcoinOrange)
                    }
                    Text(record.summaryText)
                        .font(.body)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SummarizeView()
        .preferredColorScheme(.dark)
}
