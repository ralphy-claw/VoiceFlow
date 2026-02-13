import XCTest
@testable import VoiceFlow

final class HapticServiceTests: XCTestCase {
    
    // Verify HapticService methods don't crash on simulator
    
    func testImpactDoesNotCrash() {
        HapticService.impact(.light)
        HapticService.impact(.medium)
        HapticService.impact(.heavy)
    }
    
    func testNotificationDoesNotCrash() {
        HapticService.notification(.success)
        HapticService.notification(.warning)
        HapticService.notification(.error)
    }
    
    func testSelectionDoesNotCrash() {
        HapticService.selection()
    }
}
