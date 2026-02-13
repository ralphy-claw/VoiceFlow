import SwiftUI

/// A simple audio level meter that displays bars representing the current audio level
struct AudioLevelMeter: View {
    let level: Float // 0.0 to 1.0
    let barCount: Int
    
    init(level: Float, barCount: Int = 20) {
        self.level = level
        self.barCount = barCount
    }
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                let threshold = Float(index) / Float(barCount)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(barColor(for: index))
                    .frame(width: 4, height: barHeight(for: index))
                    .opacity(level > threshold ? 1.0 : 0.2)
            }
        }
        .frame(height: 30)
        .animation(.easeOut(duration: 0.08), value: level)
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let progress = CGFloat(index) / CGFloat(barCount)
        return 8 + progress * 22
    }
    
    private func barColor(for index: Int) -> Color {
        let progress = Float(index) / Float(barCount)
        if progress < 0.6 {
            return .bitcoinOrange
        } else if progress < 0.85 {
            return .orange
        } else {
            return .red
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        AudioLevelMeter(level: 0.3)
        AudioLevelMeter(level: 0.7)
        AudioLevelMeter(level: 0.95)
    }
    .padding()
    .background(Color.darkBackground)
    .preferredColorScheme(.dark)
}
