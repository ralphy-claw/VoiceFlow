import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var ctaTitle: String? = nil
    var ctaIcon: String? = nil
    var ctaAction: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(Color.bitcoinOrange.opacity(0.6))
            
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            
            if let ctaTitle, let action = ctaAction {
                Button {
                    HapticService.impact(.light)
                    action()
                } label: {
                    Label(ctaTitle, systemImage: ctaIcon ?? "plus")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.bordered)
                .tint(.bitcoinOrange)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

#Preview {
    EmptyStateView(
        icon: "clock.arrow.circlepath",
        title: "No History Yet",
        subtitle: "Your transcriptions will appear here",
        ctaTitle: "Start Recording",
        ctaIcon: "mic.fill",
        ctaAction: {}
    )
    .background(Color.darkBackground)
    .preferredColorScheme(.dark)
}
