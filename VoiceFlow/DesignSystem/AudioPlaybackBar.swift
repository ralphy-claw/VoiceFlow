import SwiftUI
import AVFoundation

@MainActor
class AudioPlaybackViewModel: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackSpeed: Float = 1.0
    
    private var player: AVAudioPlayer?
    private var playerDelegate: PlaybackDelegate?
    private var timer: Timer?
    
    let speeds: [Float] = [0.5, 1.0, 1.5, 2.0]
    
    func load(data: Data) throws {
        stop()
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
        
        player = try AVAudioPlayer(data: data)
        player?.enableRate = true
        player?.prepareToPlay()
        duration = player?.duration ?? 0
        currentTime = 0
    }
    
    func togglePlayPause() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            stopTimer()
        } else {
            player.rate = playbackSpeed
            let delegate = PlaybackDelegate { [weak self] in
                Task { @MainActor in
                    self?.isPlaying = false
                    self?.stopTimer()
                    self?.currentTime = 0
                }
            }
            playerDelegate = delegate
            player.delegate = delegate
            player.play()
            startTimer()
        }
        isPlaying = !isPlaying
    }
    
    func seek(to time: TimeInterval) {
        player?.currentTime = time
        currentTime = time
    }
    
    func setSpeed(_ speed: Float) {
        playbackSpeed = speed
        if isPlaying {
            player?.rate = speed
        }
    }
    
    func stop() {
        player?.stop()
        stopTimer()
        isPlaying = false
        currentTime = 0
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.currentTime = self?.player?.currentTime ?? 0
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

private class PlaybackDelegate: NSObject, AVAudioPlayerDelegate {
    let onFinish: () -> Void
    init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
}

struct AudioPlaybackBar: View {
    @ObservedObject var viewModel: AudioPlaybackViewModel
    var onSave: (() -> Void)? = nil
    var onShare: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 12) {
            // Play/Pause + Slider + Time
            HStack(spacing: 12) {
                Button {
                    HapticService.impact(.light)
                    viewModel.togglePlayPause()
                } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.bitcoinOrange)
                }
                .buttonStyle(ScaleButtonStyle())
                
                VStack(spacing: 4) {
                    Slider(
                        value: Binding(
                            get: { viewModel.currentTime },
                            set: { viewModel.seek(to: $0) }
                        ),
                        in: 0...max(viewModel.duration, 0.01)
                    )
                    .tint(.bitcoinOrange)
                    
                    HStack {
                        Text(formatTime(viewModel.currentTime))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatTime(viewModel.duration))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Speed + Actions
            HStack {
                // Speed selector
                HStack(spacing: 4) {
                    ForEach(viewModel.speeds, id: \.self) { speed in
                        Button {
                            HapticService.impact(.light)
                            viewModel.setSpeed(speed)
                        } label: {
                            Text("\(String(format: "%.2g", speed))x")
                                .font(.caption2.weight(viewModel.playbackSpeed == speed ? .bold : .regular))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(viewModel.playbackSpeed == speed ? Color.bitcoinOrange : Color.darkSurfaceLight)
                                .foregroundStyle(viewModel.playbackSpeed == speed ? .white : .secondary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
                
                // Save + Share
                HStack(spacing: 12) {
                    if let onSave {
                        Button {
                            HapticService.impact(.light)
                            onSave()
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                                .font(.body)
                                .foregroundStyle(Color.bitcoinOrange)
                                .frame(width: 36, height: 36)
                                .background(Color.darkSurfaceLight)
                                .clipShape(Circle())
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    
                    if let onShare {
                        Button {
                            HapticService.impact(.light)
                            onShare()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.body)
                                .foregroundStyle(Color.bitcoinOrange)
                                .frame(width: 36, height: 36)
                                .background(Color.darkSurfaceLight)
                                .clipShape(Circle())
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
        }
        .padding(16)
        .background(Color.darkSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    AudioPlaybackBar(viewModel: AudioPlaybackViewModel())
        .padding()
        .background(Color.darkBackground)
        .preferredColorScheme(.dark)
}
