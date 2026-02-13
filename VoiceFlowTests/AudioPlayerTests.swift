import XCTest
@testable import VoiceFlow

final class AudioPlayerTests: XCTestCase {
    
    @MainActor
    func testInitialState() {
        let player = AudioPlayer()
        XCTAssertFalse(player.isPlaying)
    }
    
    @MainActor
    func testStopWhenNotPlaying() {
        let player = AudioPlayer()
        // Should not crash
        player.stop()
        XCTAssertFalse(player.isPlaying)
    }
    
    @MainActor
    func testPlayInvalidDataThrows() {
        let player = AudioPlayer()
        let badData = Data([0x00, 0x01, 0x02])
        
        XCTAssertThrowsError(try player.play(data: badData, rate: 1.0))
        XCTAssertFalse(player.isPlaying)
    }
    
    @MainActor
    func testPlayWithDifferentRates() throws {
        // Generate a valid WAV file (silence, 0.1s, 44100Hz, 16-bit mono)
        let wavData = makeWAVData(durationSeconds: 0.1)
        
        let player = AudioPlayer()
        
        // Normal speed
        try player.play(data: wavData, rate: 1.0)
        XCTAssertTrue(player.isPlaying)
        player.stop()
        
        // Fast
        try player.play(data: wavData, rate: 2.0)
        XCTAssertTrue(player.isPlaying)
        player.stop()
        
        // Slow
        try player.play(data: wavData, rate: 0.5)
        XCTAssertTrue(player.isPlaying)
        player.stop()
    }
    
    @MainActor
    func testToggle() throws {
        let wavData = makeWAVData(durationSeconds: 0.1)
        let player = AudioPlayer()
        
        try player.toggle(data: wavData, rate: 1.0)
        XCTAssertTrue(player.isPlaying)
        
        try player.toggle(data: wavData, rate: 1.0)
        XCTAssertFalse(player.isPlaying)
    }
    
    // MARK: - Helpers
    
    private func makeWAVData(durationSeconds: Double) -> Data {
        let sampleRate: UInt32 = 44100
        let numSamples = UInt32(Double(sampleRate) * durationSeconds)
        let bitsPerSample: UInt16 = 16
        let numChannels: UInt16 = 1
        let byteRate = sampleRate * UInt32(numChannels) * UInt32(bitsPerSample / 8)
        let blockAlign = numChannels * (bitsPerSample / 8)
        let dataSize = numSamples * UInt32(blockAlign)
        let chunkSize = 36 + dataSize
        
        var data = Data()
        data.append(contentsOf: "RIFF".utf8)
        data.append(contentsOf: withUnsafeBytes(of: chunkSize.littleEndian) { Array($0) })
        data.append(contentsOf: "WAVE".utf8)
        data.append(contentsOf: "fmt ".utf8)
        data.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) }) // PCM
        data.append(contentsOf: withUnsafeBytes(of: numChannels.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: sampleRate.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })
        data.append(contentsOf: "data".utf8)
        data.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })
        data.append(Data(count: Int(dataSize))) // silence
        
        return data
    }
}
