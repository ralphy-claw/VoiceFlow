//
//  BrandConfiguration.swift
//  VoiceFlow
//
//  Runtime brand configuration loaded from Info.plist.
//  Values are injected at build time via xcconfig files.
//

import Foundation
import SwiftUI

/// Runtime brand configuration for variants.
///
/// Values flow: `xcconfig → Info.plist → BrandConfiguration`
///
/// Usage:
/// ```swift
/// let email = BrandConfiguration.current.supportEmail
/// let name = BrandConfiguration.current.brandName
/// ```
struct BrandConfiguration {
    // MARK: - Identity

    /// Unique identifier for this brand variant (e.g., "VoiceFlow")
    let identifier: String

    /// Bundle identifier from the app bundle
    let bundleIdentifier: String

    /// Display name of the app
    let displayName: String

    // MARK: - Contact

    /// Support email address
    let supportEmail: String

    // MARK: - Branding

    /// The brand name used in UI text
    let brandName: String

    // MARK: - Web

    /// Base URL for the brand's website
    let websiteBaseURL: URL

    // MARK: - Appearance

    /// Preferred color scheme: nil = system, .dark, .light
    let preferredColorScheme: ColorScheme?

    // MARK: - Legal Document URLs

    var termsOfUseURL: URL {
        URL(string: "\(websiteBaseURL.absoluteString)/terms-of-use")!
    }

    var privacyPolicyURL: URL {
        URL(string: "\(websiteBaseURL.absoluteString)/privacy-policy")!
    }

    // MARK: - Shared Instance

    static let current: BrandConfiguration = {
        guard let infoPlist = Bundle.main.infoDictionary else {
            fatalError("BrandConfiguration: Unable to read Info.plist")
        }

        guard let brandDict = infoPlist["BrandConfiguration"] as? [String: Any] else {
            fatalError("""
                BrandConfiguration: Missing 'BrandConfiguration' dictionary in Info.plist.
                Ensure your xcconfig and Info.plist are properly configured.
                """)
        }

        let identifier = brandDict["identifier"] as? String ?? "unknown"
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.unknown.app"
        let displayName = infoPlist["CFBundleDisplayName"] as? String
            ?? infoPlist["CFBundleName"] as? String
            ?? "App"

        let websiteBaseURL: URL
        if let urlString = brandDict["websiteBaseURL"] as? String,
           let url = URL(string: urlString) {
            websiteBaseURL = url
        } else {
            websiteBaseURL = URL(string: "https://voiceflow.app")!
        }

        let preferredColorScheme: ColorScheme?
        if let schemeString = brandDict["preferredColorScheme"] as? String {
            switch schemeString.lowercased() {
            case "dark": preferredColorScheme = .dark
            case "light": preferredColorScheme = .light
            default: preferredColorScheme = nil
            }
        } else {
            preferredColorScheme = nil
        }

        return BrandConfiguration(
            identifier: identifier,
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            supportEmail: brandDict["supportEmail"] as? String ?? "",
            brandName: brandDict["brandName"] as? String ?? displayName,
            websiteBaseURL: websiteBaseURL,
            preferredColorScheme: preferredColorScheme
        )
    }()
}

#if DEBUG
extension BrandConfiguration {
    func debugPrint() {
        let schemeString: String
        switch preferredColorScheme {
        case .dark: schemeString = "dark"
        case .light: schemeString = "light"
        case nil: schemeString = "system"
        @unknown default: schemeString = "unknown"
        }

        print("""
        ┌─────────────────────────────────────────────────┐
        │ BrandConfiguration                              │
        ├─────────────────────────────────────────────────┤
        │ Identifier:      \(identifier)
        │ Bundle ID:       \(bundleIdentifier)
        │ Display Name:    \(displayName)
        │ Brand Name:      \(brandName)
        │ Support Email:   \(supportEmail)
        │ Website URL:     \(websiteBaseURL.absoluteString)
        │ Color Scheme:    \(schemeString)
        └─────────────────────────────────────────────────┘
        """)
    }
}
#endif
