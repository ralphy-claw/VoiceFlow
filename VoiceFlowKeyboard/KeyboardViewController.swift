import UIKit
import AVFoundation

class KeyboardViewController: UIInputViewController {

    // MARK: - State
    private var isRecording = false
    private var audioRecorder: AVAudioRecorder?

    // MARK: - UI Elements
    private let micButton = UIButton(type: .system)
    private let nextKeyboardButton = UIButton(type: .system)
    private let containerView = UIView()
    private let recordingIndicator = UIView()
    private let statusLabel = UILabel()
    private let fullAccessBanner = UILabel()

    // MARK: - Theme
    private let bitcoinOrange = UIColor(red: 247/255, green: 147/255, blue: 26/255, alpha: 1)
    private let darkBackground = UIColor(red: 13/255, green: 13/255, blue: 13/255, alpha: 1)
    private let darkSurface = UIColor(red: 26/255, green: 26/255, blue: 30/255, alpha: 1)

    // MARK: - App Group
    private let appGroupID = "group.com.lubodev.voiceflow"
    
    // MARK: - Audio
    private var audioFileURL: URL {
        let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? FileManager.default.temporaryDirectory
        return dir.appendingPathComponent("keyboard_recording.m4a")
    }
    
    // MARK: - API Key Reading
    private func readAPIKey() -> String? {
        if let keychainKey = KeychainService.read(key: "openai-api-key"), !keychainKey.isEmpty {
            return keychainKey
        }
        if let defaults = UserDefaults(suiteName: appGroupID),
           let key = defaults.string(forKey: "openai-api-key"), !key.isEmpty {
            return key
        }
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        checkFullAccess()
    }
    
    private func checkFullAccess() {
        if !hasFullAccess {
            fullAccessBanner.isHidden = false
            micButton.isEnabled = false
        } else {
            fullAccessBanner.isHidden = true
            micButton.isEnabled = true
        }
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = darkBackground

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = darkBackground
        view.addSubview(containerView)
        
        // Full access banner
        fullAccessBanner.translatesAutoresizingMaskIntoConstraints = false
        fullAccessBanner.text = "⚠️ Enable Full Access in Settings → Keyboards → VoiceFlow"
        fullAccessBanner.textColor = bitcoinOrange
        fullAccessBanner.textAlignment = .center
        fullAccessBanner.font = .systemFont(ofSize: 12, weight: .medium)
        fullAccessBanner.numberOfLines = 0
        fullAccessBanner.backgroundColor = darkSurface
        fullAccessBanner.layer.cornerRadius = 8
        fullAccessBanner.clipsToBounds = true
        fullAccessBanner.isHidden = true
        containerView.addSubview(fullAccessBanner)

        // Recording indicator (pulsing orange dot)
        recordingIndicator.translatesAutoresizingMaskIntoConstraints = false
        recordingIndicator.backgroundColor = .red
        recordingIndicator.layer.cornerRadius = 6
        recordingIndicator.isHidden = true
        containerView.addSubview(recordingIndicator)

        // Status label
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = ""
        statusLabel.textColor = .lightGray
        statusLabel.textAlignment = .center
        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        containerView.addSubview(statusLabel)

        // Mic button — large, centered, Bitcoin orange
        micButton.translatesAutoresizingMaskIntoConstraints = false
        updateMicButtonAppearance()
        micButton.layer.cornerRadius = 36
        micButton.clipsToBounds = true
        micButton.addTarget(self, action: #selector(micTapped), for: .touchUpInside)
        containerView.addSubview(micButton)

        // Next keyboard button
        nextKeyboardButton.translatesAutoresizingMaskIntoConstraints = false
        let globeImage = UIImage(systemName: "globe")?.withConfiguration(
            UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        )
        nextKeyboardButton.setImage(globeImage, for: .normal)
        nextKeyboardButton.tintColor = .lightGray
        nextKeyboardButton.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        containerView.addSubview(nextKeyboardButton)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.heightAnchor.constraint(equalToConstant: 200),
            
            fullAccessBanner.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 4),
            fullAccessBanner.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            fullAccessBanner.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            fullAccessBanner.heightAnchor.constraint(equalToConstant: 32),

            micButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            micButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor, constant: 4),
            micButton.widthAnchor.constraint(equalToConstant: 72),
            micButton.heightAnchor.constraint(equalToConstant: 72),

            recordingIndicator.centerXAnchor.constraint(equalTo: micButton.centerXAnchor),
            recordingIndicator.bottomAnchor.constraint(equalTo: micButton.topAnchor, constant: -8),
            recordingIndicator.widthAnchor.constraint(equalToConstant: 12),
            recordingIndicator.heightAnchor.constraint(equalToConstant: 12),

            statusLabel.topAnchor.constraint(equalTo: micButton.bottomAnchor, constant: 8),
            statusLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),

            nextKeyboardButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            nextKeyboardButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -8),
            nextKeyboardButton.widthAnchor.constraint(equalToConstant: 36),
            nextKeyboardButton.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    private func updateMicButtonAppearance() {
        let iconName = isRecording ? "stop.fill" : "mic.fill"
        let bgColor = isRecording ? UIColor.red : bitcoinOrange
        let micImage = UIImage(systemName: iconName)?.withConfiguration(
            UIImage.SymbolConfiguration(pointSize: 32, weight: .medium)
        )
        micButton.setImage(micImage, for: .normal)
        micButton.tintColor = darkBackground
        micButton.backgroundColor = bgColor
    }

    // MARK: - Recording

    @objc private func micTapped() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        guard let apiKey = readAPIKey(), !apiKey.isEmpty else {
            showStatus("No API key. Set it in the VoiceFlow app.", isError: true)
            return
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .default)
            try session.setActive(true)
        } catch {
            showStatus("Audio session error", isError: true)
            return
        }

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: audioFileURL, settings: settings)
            audioRecorder?.record()
            isRecording = true
            updateMicButtonAppearance()
            recordingIndicator.isHidden = false
            statusLabel.text = "Recording… tap to stop"
            statusLabel.textColor = .white
            startRecordingAnimation()
        } catch {
            showStatus("Recorder error", isError: true)
        }
    }

    private func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        updateMicButtonAppearance()
        recordingIndicator.isHidden = true
        stopRecordingAnimation()
        statusLabel.text = "Transcribing…"
        statusLabel.textColor = bitcoinOrange

        transcribeAudio()
    }

    private func startRecordingAnimation() {
        UIView.animate(withDuration: 0.6, delay: 0, options: [.repeat, .autoreverse]) {
            self.recordingIndicator.alpha = 0.3
        }
    }

    private func stopRecordingAnimation() {
        recordingIndicator.layer.removeAllAnimations()
        recordingIndicator.alpha = 1.0
    }

    // MARK: - Transcription

    private func transcribeAudio() {
        guard FileManager.default.fileExists(atPath: audioFileURL.path) else {
            showStatus("No audio file found", isError: true)
            return
        }

        guard let audioData = try? Data(contentsOf: audioFileURL) else {
            showStatus("Failed to read audio", isError: true)
            return
        }

        guard let apiKey = readAPIKey(), !apiKey.isEmpty else {
            showStatus("No API key configured", isError: true)
            return
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: Config.whisperEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(Config.whisperModel)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.showStatus("Network: \(error.localizedDescription)", isError: true)
                    return
                }

                guard let data = data,
                      let http = response as? HTTPURLResponse else {
                    self?.showStatus("Invalid response", isError: true)
                    return
                }

                if http.statusCode != 200 {
                    self?.showStatus("API error (\(http.statusCode))", isError: true)
                    return
                }

                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    let text = json?["text"] as? String ?? ""
                    if text.isEmpty {
                        self?.showStatus("No speech detected", isError: true)
                    } else {
                        // Insert directly into the host app's text field
                        self?.textDocumentProxy.insertText(text)
                        self?.showStatus("✓ Inserted", isError: false)
                        // Clear status after a moment
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            self?.statusLabel.text = ""
                        }
                    }
                } catch {
                    self?.showStatus("Parse error", isError: true)
                }
            }
        }.resume()
    }

    // MARK: - Display

    private func showStatus(_ message: String, isError: Bool) {
        statusLabel.text = message
        statusLabel.textColor = isError ? .systemRed : .lightGray
    }
}
