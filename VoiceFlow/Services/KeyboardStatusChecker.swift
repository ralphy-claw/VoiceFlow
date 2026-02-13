import UIKit

/// Checks whether the VoiceFlow keyboard extension is installed and active.
enum KeyboardStatusChecker {
    
    private static let keyboardBundleID = "com.lubodev.voiceflow.keyboard"
    
    /// Returns `true` when VoiceFlow keyboard appears in the active keyboards list.
    static var isKeyboardEnabled: Bool {
        guard let keyboards = UserDefaults.standard.object(forKey: "AppleKeyboards") as? [String] else {
            // Fallback: check via text input mode
            return UITextInputMode.activeInputModes.contains { mode in
                mode.value(forKey: "identifier") as? String == keyboardBundleID
            }
        }
        return keyboards.contains(keyboardBundleID)
    }
    
    /// Opens the system keyboard settings.
    static func openKeyboardSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
