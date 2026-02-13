import XCTest

final class VoiceFlowUITests: XCTestCase {
    
    let app = XCUIApplication()
    let screenshotPath = "/Users/ralphy-claw/.openclaw/workspace/screenshots/voiceflow/"
    
    override func setUpWithError() throws {
        continueAfterFailure = true
        app.launchArguments = ["UI_TESTING"]
        app.launch()
        
        // Create screenshot directory
        try? FileManager.default.createDirectory(
            atPath: screenshotPath,
            withIntermediateDirectories: true
        )
        
        // Dismiss onboarding if present
        let skipButton = app.buttons["Skip for now"]
        if skipButton.waitForExistence(timeout: 3) {
            skipButton.tap()
        }
    }
    
    // MARK: - Helpers
    
    func takeScreenshot(_ name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        
        // Save to disk
        let data = screenshot.pngRepresentation
        try? data.write(to: URL(fileURLWithPath: screenshotPath + name + ".png"))
    }
    
    // MARK: - 1. Transcribe Tab
    
    func testTranscribeTab() throws {
        // Should already be on Transcribe tab (first tab)
        let transcribeTab = app.tabBars.buttons["Transcribe"]
        XCTAssertTrue(transcribeTab.waitForExistence(timeout: 5))
        transcribeTab.tap()
        
        sleep(1)
        takeScreenshot("01-transcribe-initial")
        
        // Tap record button
        let recordButton = app.buttons["Record"]
        if recordButton.waitForExistence(timeout: 3) {
            recordButton.tap()
            sleep(1)
            takeScreenshot("02-transcribe-recording")
            
            // Tap stop
            let stopButton = app.buttons["Stop"]
            if stopButton.waitForExistence(timeout: 3) {
                stopButton.tap()
                sleep(1)
            }
            takeScreenshot("03-transcribe-after-stop")
        } else {
            // Try the mic icon directly
            takeScreenshot("02-transcribe-controls")
        }
    }
    
    // MARK: - 2. Speak Tab
    
    func testSpeakTab() throws {
        let speakTab = app.tabBars.buttons["Speak"]
        XCTAssertTrue(speakTab.waitForExistence(timeout: 5))
        speakTab.tap()
        sleep(1)
        takeScreenshot("04-speak-initial")
        
        // Enter text
        let textField = app.textFields.firstMatch.exists ? app.textFields.firstMatch : app.textViews.firstMatch
        if textField.waitForExistence(timeout: 3) {
            textField.tap()
            textField.typeText("Hello, this is a test of VoiceFlow text to speech.")
            takeScreenshot("05-speak-text-entered")
        }
        
        // Look for Generate/Speak button
        let generateButton = app.buttons["Generate Speech"]
        if generateButton.exists {
            takeScreenshot("06-speak-generate-button")
        }
        
        // Speed picker
        takeScreenshot("07-speak-full-controls")
    }
    
    // MARK: - 3. Summarize Tab
    
    func testSummarizeTab() throws {
        let summarizeTab = app.tabBars.buttons["Summarize"]
        XCTAssertTrue(summarizeTab.waitForExistence(timeout: 5))
        summarizeTab.tap()
        sleep(1)
        takeScreenshot("08-summarize-initial")
        
        // Enter text
        let textField = app.textFields.firstMatch.exists ? app.textFields.firstMatch : app.textViews.firstMatch
        if textField.waitForExistence(timeout: 3) {
            textField.tap()
            textField.typeText("Artificial intelligence is transforming the world in remarkable ways. From healthcare to finance, AI systems are being deployed to solve complex problems.")
            takeScreenshot("09-summarize-text-entered")
        }
        
        // Length segmented controls - try tapping Brief
        let briefButton = app.buttons["Brief"]
        if briefButton.waitForExistence(timeout: 2) {
            briefButton.tap()
            takeScreenshot("10-summarize-brief-selected")
        }
        
        let detailedButton = app.buttons["Detailed"]
        if detailedButton.exists {
            detailedButton.tap()
            takeScreenshot("11-summarize-detailed-selected")
        }
        
        // Format: Bullets
        let bulletsButton = app.buttons["Bullets"]
        if bulletsButton.exists {
            bulletsButton.tap()
            takeScreenshot("12-summarize-bullets-format")
        }
        
        // Back to Prose
        let proseButton = app.buttons["Prose"]
        if proseButton.exists {
            proseButton.tap()
        }
        
        takeScreenshot("13-summarize-full-controls")
    }
    
    // MARK: - 4. Settings
    
    func testSettingsTab() throws {
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()
        sleep(1)
        takeScreenshot("14-settings-initial")
        
        // Scroll to see more settings
        app.swipeUp()
        sleep(1)
        takeScreenshot("15-settings-scrolled")
        
        // Scroll more for API key section
        app.swipeUp()
        sleep(1)
        takeScreenshot("16-settings-api-keys")
        
        // Scroll back up
        app.swipeDown()
        app.swipeDown()
        sleep(1)
        takeScreenshot("17-settings-top")
    }
    
    // MARK: - 5. Full Tab Tour (all tabs in sequence)
    
    func testFullTabTour() throws {
        // Transcribe
        let transcribeTab = app.tabBars.buttons["Transcribe"]
        if transcribeTab.waitForExistence(timeout: 5) {
            transcribeTab.tap()
            sleep(1)
            takeScreenshot("tour-01-transcribe")
        }
        
        // Speak
        let speakTab = app.tabBars.buttons["Speak"]
        if speakTab.exists {
            speakTab.tap()
            sleep(1)
            takeScreenshot("tour-02-speak")
        }
        
        // Summarize
        let summarizeTab = app.tabBars.buttons["Summarize"]
        if summarizeTab.exists {
            summarizeTab.tap()
            sleep(1)
            takeScreenshot("tour-03-summarize")
        }
        
        // Settings
        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.exists {
            settingsTab.tap()
            sleep(1)
            takeScreenshot("tour-04-settings")
        }
    }
}
