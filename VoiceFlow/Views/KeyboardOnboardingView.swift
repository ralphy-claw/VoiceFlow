import SwiftUI

/// Full-screen first-launch keyboard onboarding flow (#38).
struct KeyboardOnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentStep = 0
    @State private var isCheckingKeyboard = false
    @State private var keyboardDetected = false
    @Environment(\.scenePhase) private var scenePhase

    private struct OnboardingStep {
        let icon: String
        let title: String
        let description: String
        let illustration: String // secondary SF symbol for flair
    }

    private let steps: [OnboardingStep] = [
        OnboardingStep(
            icon: "keyboard.fill",
            title: "Enable VoiceFlow Keyboard",
            description: "Use your voice to type anywhere on your iPhone. Let's set it up in just a few steps.",
            illustration: "waveform.and.mic"
        ),
        OnboardingStep(
            icon: "gear",
            title: "Open Settings",
            description: "Tap the button below to jump to Settings.\nThen go to General → Keyboard → Keyboards → Add New Keyboard and select VoiceFlow.",
            illustration: "arrow.up.forward.app"
        ),
        OnboardingStep(
            icon: "lock.open.fill",
            title: "Allow Full Access",
            description: "Tap VoiceFlow in your keyboards list and toggle \"Allow Full Access\".\nThis is needed so the keyboard can use the microphone.",
            illustration: "lock.shield"
        ),
        OnboardingStep(
            icon: "checkmark.seal.fill",
            title: "Verify Setup",
            description: "Tap \"Check Now\" to confirm VoiceFlow keyboard is active.\nYou can also switch to it in any text field using the 🌐 key.",
            illustration: "magnifyingglass.circle"
        ),
    ]

    var body: some View {
        ZStack {
            Color.darkBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress dots
                HStack(spacing: 10) {
                    ForEach(0..<steps.count, id: \.self) { i in
                        Circle()
                            .fill(i <= currentStep ? Color.bitcoinOrange : Color.darkSurfaceLight)
                            .frame(width: 10, height: 10)
                            .scaleEffect(i == currentStep ? 1.2 : 1.0)
                            .animation(.spring(duration: 0.3), value: currentStep)
                    }
                }
                .padding(.top, 24)

                Spacer()

                // Illustration area
                ZStack {
                    Circle()
                        .fill(Color.bitcoinOrange.opacity(0.1))
                        .frame(width: 160, height: 160)

                    Image(systemName: steps[currentStep].icon)
                        .font(.system(size: 64, weight: .medium))
                        .foregroundStyle(Color.bitcoinOrange)
                        .symbolEffect(.bounce, value: currentStep)
                }
                .padding(.bottom, 8)

                // Secondary icon badge
                Image(systemName: steps[currentStep].illustration)
                    .font(.title3)
                    .foregroundStyle(Color.bitcoinOrange.opacity(0.6))
                    .padding(.bottom, 24)

                // Text
                Text(steps[currentStep].title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text(steps[currentStep].description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                    .padding(.top, 12)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                // Action buttons per step
                VStack(spacing: 14) {
                    switch currentStep {
                    case 0:
                        nextButton(label: "Get Started")

                    case 1:
                        Button {
                            KeyboardStatusChecker.openKeyboardSettings()
                        } label: {
                            Label("Open Settings", systemImage: "arrow.up.forward.app")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(Color.bitcoinOrange)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal, 32)

                        nextButton(label: "I've Added It — Next", style: .secondary)

                    case 2:
                        nextButton(label: "I've Enabled Full Access")

                    case 3:
                        // Verify button
                        Button {
                            checkKeyboard()
                        } label: {
                            HStack(spacing: 8) {
                                if isCheckingKeyboard {
                                    ProgressView()
                                        .tint(.white)
                                } else if keyboardDetected {
                                    Image(systemName: "checkmark.circle.fill")
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                }
                                Text(keyboardDetected ? "Keyboard Active!" : "Check Now")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(keyboardDetected ? Color.green : Color.bitcoinOrange)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal, 32)
                        .disabled(isCheckingKeyboard)

                        if keyboardDetected {
                            Button {
                                completeOnboarding()
                            } label: {
                                Text("Continue to VoiceFlow")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 54)
                                    .background(Color.bitcoinOrange)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .padding(.horizontal, 32)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                    default:
                        EmptyView()
                    }

                    // Back button (steps 1+)
                    if currentStep > 0 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) { currentStep -= 1 }
                            keyboardDetected = false
                        } label: {
                            Text("Back")
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Skip link
                    Button {
                        completeOnboarding()
                    } label: {
                        Text("Skip for now")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.bottom, 6)
                }
                .padding(.bottom, 28)
                .animation(.easeInOut(duration: 0.25), value: keyboardDetected)
            }
        }
        .interactiveDismissDisabled()
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && currentStep == 3 {
                checkKeyboard()
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func nextButton(label: String, style: PremiumButtonStyle = .primary) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) { currentStep += 1 }
        } label: {
            Text(label)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(style == .primary ? Color.bitcoinOrange : Color.darkSurfaceLight)
                .foregroundColor(style == .primary ? .white : .bitcoinOrange)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 32)
    }

    private func checkKeyboard() {
        isCheckingKeyboard = true
        // Small delay for UX polish
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            keyboardDetected = KeyboardStatusChecker.isKeyboardEnabled
            isCheckingKeyboard = false
            if keyboardDetected {
                HapticService.notification(.success)
            } else {
                HapticService.notification(.warning)
            }
        }
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedKeyboardOnboarding")
        isPresented = false
    }
}

// MARK: - Persistent banner for main screen

struct KeyboardSetupBanner: View {
    let onSetup: () -> Void
    @State private var isKeyboardReady = false

    var body: some View {
        if !isKeyboardReady {
            Button(action: onSetup) {
                HStack(spacing: 12) {
                    Image(systemName: "keyboard.badge.exclamationmark")
                        .font(.title3)
                        .foregroundStyle(Color.bitcoinOrange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Keyboard Not Set Up")
                            .font(.subheadline.bold())
                        Text("Tap to enable voice typing everywhere")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .background(Color.darkSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.bitcoinOrange.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .onAppear { checkStatus() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                checkStatus()
            }
        }
    }

    private func checkStatus() {
        isKeyboardReady = KeyboardStatusChecker.isKeyboardEnabled
    }
}

#Preview {
    KeyboardOnboardingView(isPresented: .constant(true))
        .preferredColorScheme(.dark)
}
