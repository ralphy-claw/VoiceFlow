import AVFoundation
import Foundation

@MainActor
class AudioRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var fileURL: URL?
    
    var recordedFileURL: URL? { fileURL }
    
    func startRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default)
        try session.setActive(true)
        
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("recording_\(UUID().uuidString).m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder?.record()
        fileURL = url
        isRecording = true
        recordingTime = 0
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingTime += 0.1
            }
        }
    }
    
    func stopRecording() -> URL? {
        recorder?.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        return fileURL
    }
    
    func reset() {
        if let url = fileURL {
            try? FileManager.default.removeItem(at: url)
        }
        fileURL = nil
        recordingTime = 0
        isRecording = false
    }
}
