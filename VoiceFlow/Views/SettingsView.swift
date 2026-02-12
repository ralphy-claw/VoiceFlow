import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    apiKeyRow
                    testButton
                } header: {
                    Label("OpenAI", systemImage: "brain.head.profile")
                        .foregroundColor(.bitcoinOrange)
                } footer: {
                    Text("Your API key is stored securely in the iOS Keychain.")
                        .foregroundColor(.gray)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.darkBackground)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // MARK: - API Key Row
    private var apiKeyRow: some View {
        HStack {
            if viewModel.isRevealed {
                TextField("sk-...", text: $viewModel.apiKeyInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
            } else {
                SecureField("Enter API Key", text: $viewModel.apiKeyInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            
            Button {
                viewModel.isRevealed.toggle()
            } label: {
                Image(systemName: viewModel.isRevealed ? "eye.slash" : "eye")
                    .foregroundColor(.bitcoinOrange)
            }
            .buttonStyle(.plain)
        }
        .listRowBackground(Color.darkSurface)
        .onChange(of: viewModel.apiKeyInput) {
            viewModel.saveKey()
        }
    }
    
    // MARK: - Test Button
    private var testButton: some View {
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
            
            statusBadge
        }
        .listRowBackground(Color.darkSurface)
    }
    
    // MARK: - Status Badge
    @ViewBuilder
    private var statusBadge: some View {
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
class SettingsViewModel: ObservableObject {
    @Published var apiKeyInput: String = ""
    @Published var isRevealed = false
    @Published var status: APIKeyStatus = .untested
    
    private let provider = OpenAIProvider()
    
    init() {
        apiKeyInput = provider.apiKey ?? ""
        if !apiKeyInput.isEmpty {
            // Key exists but untested this session
            status = .untested
        }
    }
    
    func saveKey() {
        provider.apiKey = apiKeyInput.isEmpty ? nil : apiKeyInput
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
    @StateObject private var viewModel = SettingsViewModel()
    
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
