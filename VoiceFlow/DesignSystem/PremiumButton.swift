import SwiftUI

enum PremiumButtonStyle {
    case primary
    case secondary
}

struct PremiumButton: View {
    let title: String
    let icon: String
    var style: PremiumButtonStyle = .primary
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button {
            HapticService.impact(.medium)
            action()
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(style == .primary ? .white : .bitcoinOrange)
                } else {
                    Image(systemName: icon)
                        .font(.body.weight(.semibold))
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.5 : 1)
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary: return .bitcoinOrange
        case .secondary: return .darkSurface
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary: return .white
        case .secondary: return .bitcoinOrange
        }
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: 16) {
        PremiumButton(title: "Generate Speech", icon: "waveform", action: {})
        PremiumButton(title: "Secondary", icon: "square.and.arrow.up", style: .secondary, action: {})
        PremiumButton(title: "Loading", icon: "waveform", isLoading: true, action: {})
    }
    .padding()
    .background(Color.darkBackground)
    .preferredColorScheme(.dark)
}
