import XCTest
@testable import VoiceFlow

final class ElevenLabsServiceTests: XCTestCase {
    
    // MARK: - ElevenLabsVoice model
    
    func testElevenLabsVoiceDecoding() throws {
        let json = """
        {
            "voice_id": "abc123",
            "name": "Test Voice",
            "preview_url": "https://example.com/preview.mp3",
            "category": "premade"
        }
        """.data(using: .utf8)!
        
        let voice = try JSONDecoder().decode(ElevenLabsVoice.self, from: json)
        XCTAssertEqual(voice.voice_id, "abc123")
        XCTAssertEqual(voice.name, "Test Voice")
        XCTAssertEqual(voice.preview_url, "https://example.com/preview.mp3")
        XCTAssertEqual(voice.category, "premade")
        XCTAssertEqual(voice.id, "abc123") // Identifiable
    }
    
    func testElevenLabsVoiceDecodingOptionalFields() throws {
        let json = """
        {
            "voice_id": "abc123",
            "name": "Minimal Voice"
        }
        """.data(using: .utf8)!
        
        let voice = try JSONDecoder().decode(ElevenLabsVoice.self, from: json)
        XCTAssertEqual(voice.voice_id, "abc123")
        XCTAssertNil(voice.preview_url)
        XCTAssertNil(voice.category)
    }
    
    func testVoicesResponseDecoding() throws {
        let json = """
        {
            "voices": [
                {"voice_id": "v1", "name": "Voice One"},
                {"voice_id": "v2", "name": "Voice Two", "preview_url": "https://example.com/v2.mp3", "category": "cloned"}
            ]
        }
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(VoicesResponse.self, from: json)
        XCTAssertEqual(response.voices.count, 2)
        XCTAssertEqual(response.voices[0].name, "Voice One")
        XCTAssertEqual(response.voices[1].category, "cloned")
    }
    
    // MARK: - ElevenLabsError
    
    func testErrorDescriptions() {
        XCTAssertNotNil(ElevenLabsError.invalidResponse.errorDescription)
        XCTAssertNotNil(ElevenLabsError.apiError("test").errorDescription)
        XCTAssertTrue(ElevenLabsError.apiError("custom msg").errorDescription!.contains("custom msg"))
        
        let underlying = NSError(domain: "test", code: 42, userInfo: [NSLocalizedDescriptionKey: "network fail"])
        XCTAssertTrue(ElevenLabsError.networkError(underlying).errorDescription!.contains("network fail"))
    }
    
    // MARK: - ElevenLabsProvider
    
    func testProviderProperties() {
        let provider = ElevenLabsProvider()
        XCTAssertEqual(provider.id, "elevenlabs")
        XCTAssertEqual(provider.name, "ElevenLabs")
        XCTAssertEqual(provider.keychainKey, "elevenlabs-api-key")
        XCTAssertFalse(provider.iconName.isEmpty)
    }
}
