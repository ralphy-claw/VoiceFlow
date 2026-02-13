import UIKit
import Social
import UniformTypeIdentifiers
import AVFoundation

class ShareViewController: UIViewController {
    
    // MARK: - UI Elements
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let openButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private let iconImageView = UIImageView()
    
    // MARK: - State
    private var audioFileURL: URL?
    
    // MARK: - Theme
    private let bitcoinOrange = UIColor(red: 247/255, green: 147/255, blue: 26/255, alpha: 1)
    private let darkBackground = UIColor(red: 13/255, green: 13/255, blue: 13/255, alpha: 1)
    private let darkSurface = UIColor(red: 26/255, green: 26/255, blue: 30/255, alpha: 1)
    
    private let appGroupID = "group.com.lubodev.voiceflow"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        extractSharedAudio()
    }
    
    // MARK: - Extract Audio
    
    private func extractSharedAudio() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            updateStatus("No audio file found", isError: true)
            return
        }
        
        updateStatus("Processing audio file...")
        
        let audioTypes = [
            UTType.audio.identifier,
            UTType.mpeg4Audio.identifier,
            UTType.mp3.identifier,
            "public.audio",
            "public.mp3",
            "public.mpeg-4-audio"
        ]
        
        for attachment in attachments {
            for typeIdentifier in audioTypes {
                if attachment.hasItemConformingToTypeIdentifier(typeIdentifier) {
                    attachment.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { [weak self] (data, error) in
                        DispatchQueue.main.async {
                            if let error = error {
                                self?.updateStatus("Error: \(error.localizedDescription)", isError: true)
                                return
                            }
                            
                            if let url = data as? URL {
                                self?.copyAudioFile(from: url)
                            } else if let data = data as? Data {
                                self?.saveAudioData(data)
                            } else {
                                self?.updateStatus("Unsupported audio format", isError: true)
                            }
                        }
                    }
                    return
                }
            }
        }
        
        updateStatus("No audio file found", isError: true)
    }
    
    private func copyAudioFile(from sourceURL: URL) {
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            updateStatus("App Group access failed", isError: true)
            return
        }
        
        let filename = "shared_audio_\(UUID().uuidString).\(sourceURL.pathExtension)"
        let destURL = groupURL.appendingPathComponent(filename)
        
        do {
            // Start accessing security-scoped resource
            let accessing = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }
            
            let data = try Data(contentsOf: sourceURL)
            try data.write(to: destURL)
            
            audioFileURL = destURL
            saveMetadata(filename: filename)
            updateStatus("Audio ready to transcribe", isError: false)
            openButton.isEnabled = true
            
        } catch {
            updateStatus("Copy failed: \(error.localizedDescription)", isError: true)
        }
    }
    
    private func saveAudioData(_ data: Data) {
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            updateStatus("App Group access failed", isError: true)
            return
        }
        
        let filename = "shared_audio_\(UUID().uuidString).m4a"
        let destURL = groupURL.appendingPathComponent(filename)
        
        do {
            try data.write(to: destURL)
            audioFileURL = destURL
            saveMetadata(filename: filename)
            updateStatus("Audio ready to transcribe", isError: false)
            openButton.isEnabled = true
        } catch {
            updateStatus("Save failed: \(error.localizedDescription)", isError: true)
        }
    }
    
    private func saveMetadata(filename: String) {
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return
        }
        
        let metadataURL = groupURL.appendingPathComponent("shared_audio.json")
        let metadata: [String: Any] = [
            "filename": filename,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: metadata, options: []) {
            try? jsonData.write(to: metadataURL)
        }
    }
    
    // MARK: - Setup UI
    
    private func setupUI() {
        view.backgroundColor = darkBackground.withAlphaComponent(0.95)
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = darkSurface
        containerView.layer.cornerRadius = 16
        containerView.clipsToBounds = true
        view.addSubview(containerView)
        
        // Icon
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.image = UIImage(systemName: "waveform.circle.fill")
        iconImageView.tintColor = bitcoinOrange
        iconImageView.contentMode = .scaleAspectFit
        containerView.addSubview(iconImageView)
        
        // Title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Import Audio to VoiceFlow"
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        containerView.addSubview(titleLabel)
        
        // Status
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Preparing..."
        statusLabel.font = .systemFont(ofSize: 14)
        statusLabel.textColor = .lightGray
        statusLabel.numberOfLines = 3
        statusLabel.textAlignment = .center
        containerView.addSubview(statusLabel)
        
        // Progress
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progressTintColor = bitcoinOrange
        progressView.isHidden = true
        containerView.addSubview(progressView)
        
        // Open Button
        openButton.translatesAutoresizingMaskIntoConstraints = false
        openButton.setTitle("Open in VoiceFlow", for: .normal)
        openButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        openButton.setTitleColor(.white, for: .normal)
        openButton.backgroundColor = bitcoinOrange
        openButton.layer.cornerRadius = 12
        openButton.addTarget(self, action: #selector(openTapped), for: .touchUpInside)
        openButton.isEnabled = false
        openButton.alpha = 0.5
        containerView.addSubview(openButton)
        
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
            
            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            iconImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 60),
            iconImageView.heightAnchor.constraint(equalToConstant: 60),
            
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            progressView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 16),
            progressView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 32),
            progressView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -32),
            
            openButton.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 24),
            openButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            openButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            openButton.heightAnchor.constraint(equalToConstant: 50),
            
            cancelButton.topAnchor.constraint(equalTo: openButton.bottomAnchor, constant: 12),
            cancelButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            cancelButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            cancelButton.heightAnchor.constraint(equalToConstant: 44),
            cancelButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
        ])
    }
    
    private func updateStatus(_ message: String, isError: Bool) {
        statusLabel.text = message
        statusLabel.textColor = isError ? .systemRed : .lightGray
    }
    
    // MARK: - Actions
    
    @objc private func openTapped() {
        // Open main app with transcribe tab
        let urlString = "voiceflow://transcribe"
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
    
    @objc private func cancelTapped() {
        // Clean up the copied audio file
        if let url = audioFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
    
    @objc private func openURL(_ url: URL) {
        // This method exists to be called via the responder chain
    }
}
