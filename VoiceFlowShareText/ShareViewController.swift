import UIKit
import Social
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    
    // MARK: - UI Elements
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let previewLabel = UILabel()
    private let ttsButton = UIButton(type: .system)
    private let summarizeButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    
    // MARK: - State
    private var sharedText: String = ""
    
    // MARK: - Theme
    private let bitcoinOrange = UIColor(red: 247/255, green: 147/255, blue: 26/255, alpha: 1)
    private let darkBackground = UIColor(red: 13/255, green: 13/255, blue: 13/255, alpha: 1)
    private let darkSurface = UIColor(red: 26/255, green: 26/255, blue: 30/255, alpha: 1)
    
    private let appGroupID = "group.com.lubodev.voiceflow"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        extractSharedContent()
        setupUI()
    }
    
    // MARK: - Extract Content
    
    private func extractSharedContent() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            dismissWithError("No content to share")
            return
        }
        
        for attachment in attachments {
            // Handle plain text
            if attachment.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { [weak self] (data, error) in
                    DispatchQueue.main.async {
                        if let text = data as? String {
                            self?.sharedText = text
                            self?.updatePreview()
                        } else if let error = error {
                            self?.dismissWithError("Error: \(error.localizedDescription)")
                        }
                    }
                }
                return
            }
            
            // Handle URL
            if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (data, error) in
                    DispatchQueue.main.async {
                        if let url = data as? URL {
                            self?.sharedText = url.absoluteString
                            self?.updatePreview()
                        } else if let error = error {
                            self?.dismissWithError("Error: \(error.localizedDescription)")
                        }
                    }
                }
                return
            }
        }
        
        dismissWithError("Unsupported content type")
    }
    
    private func updatePreview() {
        let preview = sharedText.count > 200 ? String(sharedText.prefix(200)) + "..." : sharedText
        previewLabel.text = preview
    }
    
    // MARK: - Setup UI
    
    private func setupUI() {
        view.backgroundColor = darkBackground.withAlphaComponent(0.95)
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = darkSurface
        containerView.layer.cornerRadius = 16
        containerView.clipsToBounds = true
        view.addSubview(containerView)
        
        // Title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Open with VoiceFlow"
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        containerView.addSubview(titleLabel)
        
        // Preview
        previewLabel.translatesAutoresizingMaskIntoConstraints = false
        previewLabel.text = "Loading..."
        previewLabel.font = .systemFont(ofSize: 14)
        previewLabel.textColor = .lightGray
        previewLabel.numberOfLines = 4
        previewLabel.textAlignment = .center
        containerView.addSubview(previewLabel)
        
        // TTS Button
        ttsButton.translatesAutoresizingMaskIntoConstraints = false
        ttsButton.setTitle("🔊 Text to Speech", for: .normal)
        ttsButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        ttsButton.setTitleColor(.white, for: .normal)
        ttsButton.backgroundColor = bitcoinOrange
        ttsButton.layer.cornerRadius = 12
        ttsButton.addTarget(self, action: #selector(ttsTapped), for: .touchUpInside)
        containerView.addSubview(ttsButton)
        
        // Summarize Button
        summarizeButton.translatesAutoresizingMaskIntoConstraints = false
        summarizeButton.setTitle("✨ Summarize", for: .normal)
        summarizeButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        summarizeButton.setTitleColor(.white, for: .normal)
        summarizeButton.backgroundColor = bitcoinOrange
        summarizeButton.layer.cornerRadius = 12
        summarizeButton.addTarget(self, action: #selector(summarizeTapped), for: .touchUpInside)
        containerView.addSubview(summarizeButton)
        
        // Cancel Button
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .regular)
        cancelButton.setTitleColor(.lightGray, for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        containerView.addSubview(cancelButton)
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            previewLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            previewLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            previewLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            ttsButton.topAnchor.constraint(equalTo: previewLabel.bottomAnchor, constant: 20),
            ttsButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            ttsButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            ttsButton.heightAnchor.constraint(equalToConstant: 50),
            
            summarizeButton.topAnchor.constraint(equalTo: ttsButton.bottomAnchor, constant: 12),
            summarizeButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            summarizeButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            summarizeButton.heightAnchor.constraint(equalToConstant: 50),
            
            cancelButton.topAnchor.constraint(equalTo: summarizeButton.bottomAnchor, constant: 12),
            cancelButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            cancelButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            cancelButton.heightAnchor.constraint(equalToConstant: 44),
            cancelButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
        ])
    }
    
    // MARK: - Actions
    
    @objc private func ttsTapped() {
        routeToMainApp(action: "tts", text: sharedText)
    }
    
    @objc private func summarizeTapped() {
        routeToMainApp(action: "summarize", text: sharedText)
    }
    
    @objc private func cancelTapped() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
    
    // MARK: - Routing
    
    private func routeToMainApp(action: String, text: String) {
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            dismissWithError("App Group access failed")
            return
        }
        
        let sharedDataURL = groupURL.appendingPathComponent("shared_text.json")
        let sharedData: [String: Any] = [
            "action": action,
            "text": text,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: sharedData, options: [])
            try jsonData.write(to: sharedDataURL)
        } catch {
            dismissWithError("Failed to save data: \(error.localizedDescription)")
            return
        }
        
        // Open main app with custom URL scheme
        let urlString = "voiceflow://share?action=\(action)"
        if let url = URL(string: urlString) {
            var responder = self as UIResponder?
            let selector = #selector(openURL(_:))
            while responder != nil {
                if responder!.responds(to: selector) && responder != self {
                    responder!.perform(selector, with: url)
                    break
                }
                responder = responder?.next
            }
        }
        
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
    
    @objc private func openURL(_ url: URL) {
        // This method exists to be called via the responder chain
    }
    
    private func dismissWithError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        })
        present(alert, animated: true)
    }
}
