import XCTest
@testable import VoiceFlow

final class STTSettingsTests: XCTestCase {
    
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "stt_provider")
        super.tearDown()
    }
    
    func testSTTProviderAllCases() {
        let cases = STTProvider.allCases
        XCTAssertEqual(cases.count, 2)
        XCTAssertTrue(cases.contains(.cloud))
        XCTAssertTrue(cases.contains(.local))
    }
    
    func testSTTProviderRawValues() {
        XCTAssertEqual(STTProvider.cloud.rawValue, "Cloud (OpenAI Whisper)")
        XCTAssertEqual(STTProvider.local.rawValue, "On-Device (WhisperKit)")
    }
    
    func testDefaultProvider() {
        let settings = STTSettings()
        XCTAssertEqual(settings.provider, .cloud)
    }
    
    func testPersistence() {
        let settings1 = STTSettings()
        settings1.provider = .local
        
        let settings2 = STTSettings()
        XCTAssertEqual(settings2.provider, .local)
    }
    
    func testSTTProviderCodable() throws {
        let original = STTProvider.local
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(STTProvider.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}
