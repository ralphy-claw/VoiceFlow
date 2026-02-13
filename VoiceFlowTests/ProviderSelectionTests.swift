import XCTest
@testable import VoiceFlow

final class ProviderSelectionTests: XCTestCase {
    
    // MARK: - OpenAIProvider
    
    func testOpenAIProviderProperties() {
        let provider = OpenAIProvider()
        XCTAssertEqual(provider.id, "openai")
        XCTAssertEqual(provider.name, "OpenAI")
        XCTAssertEqual(provider.keychainKey, "openai-api-key")
        XCTAssertFalse(provider.iconName.isEmpty)
    }
    
    // MARK: - ElevenLabsProvider
    
    func testElevenLabsProviderProperties() {
        let provider = ElevenLabsProvider()
        XCTAssertEqual(provider.id, "elevenlabs")
        XCTAssertEqual(provider.name, "ElevenLabs")
        XCTAssertEqual(provider.keychainKey, "elevenlabs-api-key")
    }
    
    // MARK: - APIKeyStatus
    
    func testAPIKeyStatusRawValues() {
        XCTAssertEqual(APIKeyStatus.untested.rawValue, "Untested")
        XCTAssertEqual(APIKeyStatus.valid.rawValue, "Valid")
        XCTAssertEqual(APIKeyStatus.invalid.rawValue, "Invalid")
        XCTAssertEqual(APIKeyStatus.testing.rawValue, "Testing...")
    }
    
    // MARK: - hasKey extension
    
    func testHasKeyWhenNoKey() {
        let provider = OpenAIProvider()
        // In test environment, keychain may be empty
        // Just verify it doesn't crash
        _ = provider.hasKey
    }
    
    // MARK: - Provider uniqueness
    
    func testProviderIdsAreUnique() {
        let openai = OpenAIProvider()
        let elevenlabs = ElevenLabsProvider()
        XCTAssertNotEqual(openai.id, elevenlabs.id)
        XCTAssertNotEqual(openai.keychainKey, elevenlabs.keychainKey)
    }
}
