import SwiftUI

struct SummarizeView: View {
    @State private var inputText = ""
    @State private var summary = ""
    @State private var isSummarizing = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Text to summarize")
                        .font(.headline)
                    
                    TextEditor(text: $inputText)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal)
                
                // Summarize button
                Button {
                    summarize()
                } label: {
                    if isSummarizing {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Summarize", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSummarizing)
                .padding(.horizontal)
                
                // Summary result
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
                        }
                        
                        Text(summary)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding(.top)
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
}
