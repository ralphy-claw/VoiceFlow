import SwiftUI

struct SettingsView: View {
    @StateObject private var openAIViewModel = ProviderViewModel(provider: OpenAIProvider())
    @StateObject private var elevenLabsViewModel = ProviderViewModel(provider: ElevenLabsProvider())
    @StateObject private var whisperKitService = WhisperKitService.shared
    @State private var sttSettings = STTSettings()
    @State private var summarizeSettings = SummarizeSettings()
    @State private var showKeyboardSetup = false
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Keyboard Setup
                Section {
                    Button {
                        showKeyboardSetup = true
                    } label: {
                        HStack {
                            Image(systemName: "keyboard")
                                .foregroundStyle(Color.bitcoinOrange)
                            Text("Set Up VoiceFlow Keyboard")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.darkSurface)
                } header: {
                    Label("Keyboard Extension", systemImage: "keyboard")
                        .foregroundColor(.bitcoinOrange)
                } footer: {
                    Text("Follow the setup guide to enable the VoiceFlow keyboard for voice typing in any app.")
                        .foregroundColor(.gray)
                }
                
                // MARK: - Provider Preferences
                Section {
                    Picker("Speech-to-Text", selection: $sttSettings.provider) {
                        ForEach(STTProvider.allCases, id: \.self) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    
                    if sttSettings.provider == .local {
                        HStack {
                            if whisperKitService.isModelDownloaded {
                                Label("Model Ready", systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Button {
                                    Task {
                                        do {
                                            try await whisperKitService.downloadModel()
                                        } catch {
                                            // errorMessage is already set on the service
                                        }
                                    }
                                } label: {
                                    if whisperKitService.isDownloading {
                                        HStack {
                                            ProgressView()
                                                .tint(.bitcoinOrange)
                                            Text("\(Int(whisperKitService.downloadProgress * 100))%")
                                        }
                                    } else {
                                        Label("Download Model", systemImage: "arrow.down.circle")
                                    }
                                }
                                .disabled(whisperKitService.isDownloading)
                            }
                        }
                        
                        if let error = whisperKitService.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    
                    // Language picker (#26)
                    NavigationLink {
                        LanguagePickerView(selectedLanguage: $sttSettings.language)
                    } label: {
                        HStack {
                            Text("Transcription Language")
                            Spacer()
                            Text(sttSettings.languageDisplayCode)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Picker("Summarization Length", selection: $summarizeSettings.length) {
                        ForEach(SummaryLength.allCases, id: \.self) { length in
                            Text(length.rawValue).tag(length)
                        }
                    }
                    
                    Picker("Summary Format", selection: $summarizeSettings.format) {
                        ForEach(SummaryFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                } header: {
                    Label("Provider Preferences", systemImage: "slider.horizontal.3")
                        .foregroundColor(.bitcoinOrange)
                } footer: {
                    Text("Choose default providers for each operation. You can override these in each tab.")
                        .foregroundColor(.gray)
                }
                
                // MARK: - API Keys
                Section {
                    apiKeyRow(viewModel: openAIViewModel)
                    testButton(viewModel: openAIViewModel)
                } header: {
                    Label("OpenAI", systemImage: "brain.head.profile")
                        .foregroundColor(.bitcoinOrange)
                } footer: {
                    Text("Used for Whisper STT, ChatGPT Summarization, and OpenAI TTS.")
                        .foregroundColor(.gray)
                }
                
                Section {
                    apiKeyRow(viewModel: elevenLabsViewModel)
                    testButton(viewModel: elevenLabsViewModel)
                } header: {
                    Label("ElevenLabs", systemImage: "waveform.badge.mic")
                        .foregroundColor(.bitcoinOrange)
                } footer: {
                    Text("Optional: Use ElevenLabs for higher quality text-to-speech. Your API key is stored securely in the iOS Keychain.")
                        .foregroundColor(.gray)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.darkBackground)
            .contentMargins(.bottom, 32, for: .scrollContent)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showKeyboardSetup) {
                KeyboardSetupGuideView()
            }
        }
    }
    
    // MARK: - API Key Row
    @ViewBuilder
    private func apiKeyRow(viewModel: ProviderViewModel) -> some View {
        HStack {
            if viewModel.isRevealed {
                TextField("Enter API Key", text: Binding(get: { viewModel.apiKeyInput }, set: { viewModel.apiKeyInput = $0 }))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
            } else {
                SecureField("Enter API Key", text: Binding(get: { viewModel.apiKeyInput }, set: { viewModel.apiKeyInput = $0 }))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            
            Button {
                viewModel.isRevealed.toggle()
            } label: {
                Image(systemName: viewModel.isRevealed ? "eye.slash" : "eye")
                    .foregroundColor(.bitcoinOrange)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .listRowBackground(Color.darkSurface)
        .onChange(of: viewModel.apiKeyInput) {
            viewModel.saveKey()
        }
    }
    
    // MARK: - Test Button
    @ViewBuilder
    private func testButton(viewModel: ProviderViewModel) -> some View {
        HStack {
            Button {
                Task { await viewModel.testKey() }
            } label: {
                HStack {
                    Image(systemName: "checkmark.shield")
                    Text("Test Connection")
                }
                .foregroundColor(.bitcoinOrange)
            }
            .disabled(viewModel.apiKeyInput.isEmpty || viewModel.status == .testing)
            .buttonStyle(.plain)
            
            Spacer()
            
            statusBadge(for: viewModel)
        }
        .listRowBackground(Color.darkSurface)
    }
    
    // MARK: - Status Badge
    @ViewBuilder
    private func statusBadge(for viewModel: ProviderViewModel) -> some View {
        switch viewModel.status {
        case .untested:
            Label("Untested", systemImage: "questionmark.circle")
                .font(.caption)
                .foregroundColor(.gray)
        case .testing:
            ProgressView()
                .tint(.bitcoinOrange)
        case .valid:
            Label("Valid", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.green)
        case .invalid:
            Label("Invalid", systemImage: "xmark.circle.fill")
                .font(.caption)
                .foregroundColor(.red)
        }
    }
}

// MARK: - ViewModel
@MainActor
class ProviderViewModel: ObservableObject {
    @Published var apiKeyInput: String = ""
    @Published var isRevealed = false
    @Published var status: APIKeyStatus = .untested
    
    private let provider: any ServiceProvider
    
    init(provider: any ServiceProvider) {
        self.provider = provider
        apiKeyInput = provider.apiKey ?? ""
        if !apiKeyInput.isEmpty {
            // Key exists but untested this session
            status = .untested
        }
    }
    
    func saveKey() {
        var mutableProvider = provider
        mutableProvider.apiKey = apiKeyInput.isEmpty ? nil : apiKeyInput
        status = .untested
    }
    
    func testKey() async {
        guard !apiKeyInput.isEmpty else { return }
        status = .testing
        let isValid = await provider.validate(apiKey: apiKeyInput)
        status = isValid ? .valid : .invalid
    }
}

// MARK: - Onboarding Sheet
struct APIKeyOnboardingView: View {
    @Binding var isPresented: Bool
    @StateObject private var viewModel = ProviderViewModel(provider: OpenAIProvider())
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: "key.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.bitcoinOrange)
                
                Text("Welcome to VoiceFlow")
                    .font(.title.bold())
                
                Text("To get started, enter your OpenAI API key.\nYour key is stored securely in the Keychain.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                VStack(spacing: 12) {
                    SecureField("sk-...", text: $viewModel.apiKeyInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding()
                        .background(Color.darkSurface)
                        .cornerRadius(12)
                    
                    Button {
                        viewModel.saveKey()
                        Task {
                            await viewModel.testKey()
                            if viewModel.status == .valid {
                                isPresented = false
                            }
                        }
                    } label: {
                        Text("Save & Test")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(viewModel.apiKeyInput.isEmpty ? Color.gray : Color.bitcoinOrange)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(viewModel.apiKeyInput.isEmpty)
                    
                    if viewModel.status == .invalid {
                        Text("Invalid API key. Please try again.")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    if viewModel.status == .testing {
                        ProgressView()
                            .tint(.bitcoinOrange)
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                Button("Skip for now") {
                    isPresented = false
                }
                .foregroundColor(.gray)
                .padding(.bottom)
            }
            .background(Color.darkBackground.ignoresSafeArea())
        }
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
