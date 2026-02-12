import SwiftUI
import SwiftData

struct SummarizeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var inputText = ""
    @State private var summary = ""
    @State private var isSummarizing = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Text to summarize")
                        .font(.headline)
                    
                    TextEditor(text: $inputText)
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color.darkSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal)
                
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
                .padding(.horizontal)
                
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
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.darkSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding(.top)
            .background(Color.darkBackground.ignoresSafeArea())
            .navigationTitle("Summarize")
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
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

#Preview {
    SummarizeView()
        .preferredColorScheme(.dark)
}
