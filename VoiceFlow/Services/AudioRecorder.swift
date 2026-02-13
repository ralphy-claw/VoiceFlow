import AVFoundation
import Foundation

@MainActor
class AudioRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var audioLevel: Float = 0 // 0.0 to 1.0 for waveform display
    @Published var isContinuousMode = false
    
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var fileURL: URL?
    
    // Continuous mode
    private var audioEngine: AVAudioEngine?
    private var silenceStart: Date?
    private let silenceThreshold: Float = 0.05
    private let silenceDuration: TimeInterval = 1.5
    private var continuousSegments: [URL] = []
    private var currentSegmentURL: URL?
    private var onSegmentComplete: ((URL) -> Void)?
    
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
        recorder?.isMeteringEnabled = true
        recorder?.record()
        fileURL = url
        isRecording = true
        recordingTime = 0
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.recordingTime += 0.1
                self.recorder?.updateMeters()
                let power = self.recorder?.averagePower(forChannel: 0) ?? -160
                // Convert dB to 0-1 range (-50dB to 0dB)
                let normalised = max(0, min(1, (power + 50) / 50))
                self.audioLevel = normalised
            }
        }
    }
    
    func stopRecording() -> URL? {
        recorder?.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        audioLevel = 0
        return fileURL
    }
    
    // MARK: - Continuous Mode
    
    func startContinuousRecording(onSegment: @escaping (URL) -> Void) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default)
        try session.setActive(true)
        
        isContinuousMode = true
        isRecording = true
        recordingTime = 0
        onSegmentComplete = onSegment
        continuousSegments = []
        silenceStart = nil
        
        startNewSegment()
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.recordingTime += 0.1
                self.recorder?.updateMeters()
                let power = self.recorder?.averagePower(forChannel: 0) ?? -160
                let normalised = max(0, min(1, (power + 50) / 50))
                self.audioLevel = normalised
                
                // Silence detection
                if normalised < self.silenceThreshold {
                    if self.silenceStart == nil {
                        self.silenceStart = Date()
                    } else if let start = self.silenceStart,
                              Date().timeIntervalSince(start) >= self.silenceDuration,
                              self.recordingTime > 2.0 {
                        // Pause detected — finalize segment
                        self.finalizeSegment()
                    }
                } else {
                    self.silenceStart = nil
                }
            }
        }
    }
    
    func stopContinuousRecording() -> [URL] {
        recorder?.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        isContinuousMode = false
        audioLevel = 0
        
        if let url = currentSegmentURL {
            continuousSegments.append(url)
        }
        
        let segments = continuousSegments
        continuousSegments = []
        return segments
    }
    
    private func startNewSegment() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("segment_\(UUID().uuidString).m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        recorder?.stop()
        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.isMeteringEnabled = true
            recorder?.record()
            currentSegmentURL = url
        } catch {
            print("[AudioRecorder] Failed to start new segment: \(error.localizedDescription)")
            currentSegmentURL = nil
        }
    }
    
    private func finalizeSegment() {
        guard let url = currentSegmentURL else { return }
        recorder?.stop()
        continuousSegments.append(url)
        onSegmentComplete?(url)
        silenceStart = nil
        
        // Start a new segment immediately
        startNewSegment()
    }
    
    func reset() {
        if let url = fileURL {
            try? FileManager.default.removeItem(at: url)
        }
        fileURL = nil
        recordingTime = 0
        isRecording = false
        audioLevel = 0
    }
}
