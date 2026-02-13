import XCTest
@testable import VoiceFlow

final class SummarizeSettingsTests: XCTestCase {
    
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "summarize_length")
        UserDefaults.standard.removeObject(forKey: "summarize_format")
        super.tearDown()
    }
    
    // MARK: - SummaryLength
    
    func testSummaryLengthAllCases() {
        let cases = SummaryLength.allCases
        XCTAssertEqual(cases.count, 3)
        XCTAssertTrue(cases.contains(.brief))
        XCTAssertTrue(cases.contains(.standard))
        XCTAssertTrue(cases.contains(.detailed))
    }
    
    func testSummaryLengthRawValues() {
        XCTAssertEqual(SummaryLength.brief.rawValue, "Brief")
        XCTAssertEqual(SummaryLength.standard.rawValue, "Standard")
        XCTAssertEqual(SummaryLength.detailed.rawValue, "Detailed")
    }
    
    func testSummaryLengthSystemPrompts() {
        XCTAssertFalse(SummaryLength.brief.systemPrompt.isEmpty)
        XCTAssertFalse(SummaryLength.standard.systemPrompt.isEmpty)
        XCTAssertFalse(SummaryLength.detailed.systemPrompt.isEmpty)
        // Brief should mention 1-2 sentences
        XCTAssertTrue(SummaryLength.brief.systemPrompt.contains("brief"))
    }
    
    // MARK: - SummaryFormat
    
    func testSummaryFormatAllCases() {
        let cases = SummaryFormat.allCases
        XCTAssertEqual(cases.count, 3)
        XCTAssertTrue(cases.contains(.prose))
        XCTAssertTrue(cases.contains(.bullets))
        XCTAssertTrue(cases.contains(.keyTakeaways))
    }
    
    func testSummaryFormatRawValues() {
        XCTAssertEqual(SummaryFormat.prose.rawValue, "Prose")
        XCTAssertEqual(SummaryFormat.bullets.rawValue, "Bullets")
        XCTAssertEqual(SummaryFormat.keyTakeaways.rawValue, "Key Takeaways")
    }
    
    func testSummaryFormatSystemPrompts() {
        XCTAssertTrue(SummaryFormat.prose.systemPrompt.lowercased().contains("prose"))
        XCTAssertTrue(SummaryFormat.bullets.systemPrompt.lowercased().contains("bullet"))
        XCTAssertTrue(SummaryFormat.keyTakeaways.systemPrompt.lowercased().contains("key takeaways"))
    }
    
    // MARK: - SummarizeSettings
    
    func testDefaultValues() {
        let settings = SummarizeSettings()
        XCTAssertEqual(settings.length, .standard)
        XCTAssertEqual(settings.format, .prose)
    }
    
    func testPersistence() {
        // Set values
        let settings1 = SummarizeSettings()
        settings1.length = .detailed
        settings1.format = .bullets
        
        // Create new instance — should load persisted values
        let settings2 = SummarizeSettings()
        XCTAssertEqual(settings2.length, .detailed)
        XCTAssertEqual(settings2.format, .bullets)
    }
    
    func testBuildSystemPrompt() {
        let settings = SummarizeSettings()
        settings.length = .brief
        settings.format = .keyTakeaways
        
        let prompt = settings.buildSystemPrompt()
        XCTAssertTrue(prompt.contains(SummaryLength.brief.systemPrompt))
        XCTAssertTrue(prompt.contains(SummaryFormat.keyTakeaways.systemPrompt))
        XCTAssertTrue(prompt.lowercased().contains("summarize"))
    }
    
    // MARK: - Codable roundtrip
    
    func testSummaryLengthCodable() throws {
        let original = SummaryLength.detailed
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SummaryLength.self, from: data)
        XCTAssertEqual(original, decoded)
    }
    
    func testSummaryFormatCodable() throws {
        let original = SummaryFormat.keyTakeaways
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SummaryFormat.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}
