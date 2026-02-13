import SwiftUI

struct KeyboardSetupGuideView: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0

    private let steps: [(icon: String, title: String, description: String)] = [
        ("gear", "Open Settings", "Tap the button below to open Settings, or navigate manually."),
        ("keyboard", "Add Keyboard", "Go to General → Keyboard → Keyboards → Add New Keyboard, then select VoiceFlow."),
        ("lock.shield", "Allow Full Access", "Tap VoiceFlow in your keyboards list and enable \"Allow Full Access\". This is required for microphone access."),
        ("checkmark.circle", "You're All Set!", "Switch to the VoiceFlow keyboard in any app by tapping the globe 🌐 icon on your keyboard."),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Step indicator
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Capsule()
                            .fill(index <= currentStep ? Color.bitcoinOrange : Color.darkSurfaceLight)
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

                // Current step content
                VStack(spacing: 24) {
                    Image(systemName: steps[currentStep].icon)
                        .font(.system(size: 64))
                        .foregroundStyle(Color.bitcoinOrange)
                        .symbolEffect(.pulse, isActive: currentStep < steps.count - 1)

                    Text("Step \(currentStep + 1) of \(steps.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(steps[currentStep].title)
                        .font(.title2.bold())

                    Text(steps[currentStep].description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                // Actions
                VStack(spacing: 12) {
                    if currentStep == 0 {
                        Button {
                            openSettings()
                        } label: {
                            Label("Open Settings", systemImage: "arrow.up.forward.app")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.bitcoinOrange)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal, 32)
                    }

                    if currentStep < steps.count - 1 {
                        Button {
                            withAnimation { currentStep += 1 }
                        } label: {
                            Text("Next")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(currentStep == 0 ? Color.darkSurfaceLight : Color.bitcoinOrange)
                                .foregroundColor(currentStep == 0 ? .bitcoinOrange : .white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal, 32)
                    } else {
                        Button {
                            dismiss()
                        } label: {
                            Text("Done")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.bitcoinOrange)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal, 32)
                    }

                    if currentStep > 0 && currentStep < steps.count - 1 {
                        Button {
                            withAnimation { currentStep -= 1 }
                        } label: {
                            Text("Back")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.bottom, 32)
            }
            .background(Color.darkBackground.ignoresSafeArea())
            .navigationTitle("Keyboard Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.bitcoinOrange)
                }
            }
        }
    }

    private func openSettings() {
        // Try keyboard settings first, fall back to general settings
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    KeyboardSetupGuideView()
        
        .environment(ThemeManager.shared)
        .preferredColorScheme(.dark)
}
