import SwiftUI

struct LanguagePickerView: View {
    @Binding var selectedLanguage: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    private var filteredLanguages: [WhisperLanguage] {
        if searchText.isEmpty {
            return WhisperLanguages.all
        }
        return WhisperLanguages.all.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.id.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Auto-detect option
                Section {
                    Button {
                        selectedLanguage = "auto"
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "wand.and.stars")
                                .foregroundStyle(Color.bitcoinOrange)
                            Text("Auto-detect")
                            Spacer()
                            if selectedLanguage == "auto" {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.bitcoinOrange)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.darkSurface)
                }
                
                // Common languages
                if searchText.isEmpty {
                    Section {
                        ForEach(WhisperLanguages.common) { lang in
                            languageRow(lang)
                        }
                    } header: {
                        Text("Common")
                    }
                }
                
                // All / filtered languages
                Section {
                    ForEach(filteredLanguages) { lang in
                        // Skip common ones if showing them above
                        if searchText.isEmpty && WhisperLanguages.common.contains(where: { $0.id == lang.id }) {
                            EmptyView()
                        } else {
                            languageRow(lang)
                        }
                    }
                } header: {
                    if searchText.isEmpty {
                        Text("All Languages")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.darkBackground.ignoresSafeArea())
            .navigationTitle("Language")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search languages")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.bitcoinOrange)
                }
            }
        }
    }
    
    @ViewBuilder
    private func languageRow(_ lang: WhisperLanguage) -> some View {
        Button {
            selectedLanguage = lang.id
            dismiss()
        } label: {
            HStack {
                Text(lang.name)
                Spacer()
                Text(lang.displayCode)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                if selectedLanguage == lang.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.bitcoinOrange)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.darkSurface)
    }
}

#Preview {
    LanguagePickerView(selectedLanguage: .constant("auto"))
        .preferredColorScheme(.dark)
}
