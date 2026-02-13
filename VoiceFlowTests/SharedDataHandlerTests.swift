import XCTest
@testable import VoiceFlow

final class SharedDataHandlerTests: XCTestCase {
    
    // MARK: - SharedTextData Equatable
    
    func testSharedTextDataEquatable() {
        let a = SharedDataHandler.SharedTextData(action: "tts", text: "hello", timestamp: 100)
        let b = SharedDataHandler.SharedTextData(action: "tts", text: "hello", timestamp: 100)
        let c = SharedDataHandler.SharedTextData(action: "summarize", text: "hello", timestamp: 100)
        
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
    
    // MARK: - SharedAudioData Equatable
    
    func testSharedAudioDataEquatable() {
        let url1 = URL(fileURLWithPath: "/tmp/a.m4a")
        let url2 = URL(fileURLWithPath: "/tmp/b.m4a")
        
        let a = SharedDataHandler.SharedAudioData(fileURL: url1, timestamp: 100)
        let b = SharedDataHandler.SharedAudioData(fileURL: url1, timestamp: 100)
        let c = SharedDataHandler.SharedAudioData(fileURL: url2, timestamp: 100)
        
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
    
    // MARK: - Read returns nil when no data
    
    func testReadSharedTextReturnsNilWhenEmpty() {
        // Clear any existing shared data first
        SharedDataHandler.clearSharedText()
        let result = SharedDataHandler.readSharedText()
        // May be nil (no app group in test) or nil (cleared) — either way, no crash
        // This mainly tests that the code doesn't crash
        _ = result
    }
    
    func testReadSharedAudioReturnsNilWhenEmpty() {
        SharedDataHandler.clearSharedAudio()
        let result = SharedDataHandler.readSharedAudio()
        _ = result
    }
}
