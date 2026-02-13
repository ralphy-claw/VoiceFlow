import SwiftUI

struct RecordingIndicator: View {
    var isRecording: Bool
    @State private var isPulsing = false
    
    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 12, height: 12)
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 0.6 : 1.0)
            .animation(
                isRecording
                    ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                    : .default,
                value: isPulsing
            )
            .onChange(of: isRecording) { _, newValue in
                isPulsing = newValue
            }
            .onAppear {
                isPulsing = isRecording
            }
    }
}

#Preview {
    HStack(spacing: 20) {
        RecordingIndicator(isRecording: true)
        RecordingIndicator(isRecording: false)
    }
    .padding()
    .background(Color.darkBackground)
    .preferredColorScheme(.dark)
}
