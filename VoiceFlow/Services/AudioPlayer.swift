import AVFoundation
import Foundation

@MainActor
class AudioPlayer: ObservableObject {
    @Published var isPlaying = false
    
    private var player: AVAudioPlayer?
    private var playerDelegate: PlayerDelegate?
    
    func play(data: Data, rate: Float = 1.0) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
        
        player = try AVAudioPlayer(data: data)
        let delegate = PlayerDelegate { [weak self] in
            Task { @MainActor in
                self?.isPlaying = false
            }
        }
        playerDelegate = delegate
        player?.delegate = delegate
        player?.enableRate = true
        player?.rate = rate
        player?.play()
        isPlaying = true
    }
    
    func stop() {
        player?.stop()
        isPlaying = false
    }
    
    func toggle(data: Data, rate: Float = 1.0) throws {
        if isPlaying {
            stop()
        } else {
            try play(data: data, rate: rate)
        }
    }
}

private class PlayerDelegate: NSObject, AVAudioPlayerDelegate {
    let onFinish: () -> Void
    init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
}
