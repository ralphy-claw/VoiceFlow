import XCTest
@testable import VoiceFlow

final class WhisperKitServiceTests: XCTestCase {
    
    // MARK: - WhisperKitError
    
    func testErrorDescriptions() {
        XCTAssertNotNil(WhisperKitError.notAvailable.errorDescription)
        XCTAssertNotNil(WhisperKitError.modelNotDownloaded.errorDescription)
        XCTAssertTrue(WhisperKitError.transcriptionFailed("oops").errorDescription!.contains("oops"))
    }
    
    // MARK: - WhisperKitService
    
    @MainActor
    func testInitialState() {
        let service = WhisperKitService.shared
        XCTAssertFalse(service.isModelDownloaded)
        XCTAssertFalse(service.isDownloading)
        XCTAssertEqual(service.downloadProgress, 0)
    }
    
    @MainActor
    func testTranscribeWithoutModelThrows() async {
        let service = WhisperKitService.shared
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.m4a")
        
        do {
            _ = try await service.transcribe(audioURL: tempURL)
            XCTFail("Should throw modelNotDownloaded")
        } catch let error as WhisperKitError {
            if case .modelNotDownloaded = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    @MainActor
    func testDownloadModelThrowsNotAvailable() async {
        let service = WhisperKitService.shared
        
        do {
            try await service.downloadModel()
            XCTFail("Should throw notAvailable")
        } catch let error as WhisperKitError {
            if case .notAvailable = error {
                // Expected — WhisperKit not linked yet
            } else {
                XCTFail("Wrong error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        // isDownloading should be reset
        XCTAssertFalse(service.isDownloading)
    }
}
