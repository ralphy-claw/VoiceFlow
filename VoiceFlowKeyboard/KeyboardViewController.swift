import UIKit
import AVFoundation

class KeyboardViewController: UIInputViewController {

    // MARK: - State
    private var isRecording = false
    private var audioRecorder: AVAudioRecorder?
    private var transcribedText: String = ""

    // MARK: - UI Elements
    private let micButton = UIButton(type: .system)
    private let nextKeyboardButton = UIButton(type: .system)
    private let previewTextView = UITextView()
    private let containerView = UIView()
    private let recordingIndicator = UIView()
    private let statusLabel = UILabel()
    private let insertButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private let actionStack = UIStackView()
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
        // Try Keychain first
        if let keychainKey = KeychainService.read(key: "openai-api-key"), !keychainKey.isEmpty {
            return keychainKey
        }
        // Fall back to App Group UserDefaults
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

        // Editable preview text view
        previewTextView.translatesAutoresizingMaskIntoConstraints = false
        previewTextView.text = "Tap mic to transcribe"
        previewTextView.textColor = .lightGray
        previewTextView.backgroundColor = darkSurface
        previewTextView.layer.cornerRadius = 8
        previewTextView.clipsToBounds = true
        previewTextView.font = .systemFont(ofSize: 14)
        previewTextView.isEditable = true
        previewTextView.isScrollEnabled = true
        previewTextView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        containerView.addSubview(previewTextView)

        // Recording indicator (red dot)
        recordingIndicator.translatesAutoresizingMaskIntoConstraints = false
        recordingIndicator.backgroundColor = .red
        recordingIndicator.layer.cornerRadius = 5
        recordingIndicator.isHidden = true
        containerView.addSubview(recordingIndicator)

        // Status label
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = ""
        statusLabel.textColor = .lightGray
        statusLabel.textAlignment = .center
        statusLabel.font = .systemFont(ofSize: 11)
        containerView.addSubview(statusLabel)

        // Action buttons stack (Insert + Cancel)
        actionStack.translatesAutoresizingMaskIntoConstraints = false
        actionStack.axis = .horizontal
        actionStack.spacing = 12
        actionStack.distribution = .fillEqually
        actionStack.isHidden = true
        containerView.addSubview(actionStack)

        // Insert button
        insertButton.setTitle("Insert", for: .normal)
        insertButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        insertButton.setTitleColor(darkBackground, for: .normal)
        insertButton.backgroundColor = bitcoinOrange
        insertButton.layer.cornerRadius = 8
        insertButton.addTarget(self, action: #selector(insertTapped), for: .touchUpInside)
        actionStack.addArrangedSubview(insertButton)

        // Cancel button
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        cancelButton.setTitleColor(.lightGray, for: .normal)
        cancelButton.backgroundColor = darkSurface
        cancelButton.layer.cornerRadius = 8
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        actionStack.addArrangedSubview(cancelButton)

        // Mic button
        micButton.translatesAutoresizingMaskIntoConstraints = false
        updateMicButtonAppearance()
        micButton.layer.cornerRadius = 28
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
            containerView.heightAnchor.constraint(equalToConstant: 220),
            
            fullAccessBanner.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 4),
            fullAccessBanner.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            fullAccessBanner.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            fullAccessBanner.heightAnchor.constraint(equalToConstant: 32),

            previewTextView.topAnchor.constraint(equalTo: fullAccessBanner.bottomAnchor, constant: 4),
            previewTextView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            previewTextView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            previewTextView.heightAnchor.constraint(equalToConstant: 56),

            recordingIndicator.topAnchor.constraint(equalTo: previewTextView.topAnchor, constant: 8),
            recordingIndicator.trailingAnchor.constraint(equalTo: previewTextView.trailingAnchor, constant: -8),
            recordingIndicator.widthAnchor.constraint(equalToConstant: 10),
            recordingIndicator.heightAnchor.constraint(equalToConstant: 10),

            actionStack.topAnchor.constraint(equalTo: previewTextView.bottomAnchor, constant: 6),
            actionStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            actionStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            actionStack.heightAnchor.constraint(equalToConstant: 32),

            statusLabel.topAnchor.constraint(equalTo: actionStack.bottomAnchor, constant: 2),
            statusLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            micButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            micButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 6),
            micButton.widthAnchor.constraint(equalToConstant: 56),
            micButton.heightAnchor.constraint(equalToConstant: 56),

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
            UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        )
        micButton.setImage(micImage, for: .normal)
        micButton.tintColor = darkBackground
        micButton.backgroundColor = bgColor
    }

    // MARK: - Actions

    @objc private func insertTapped() {
        let text = previewTextView.text ?? ""
        guard !text.isEmpty, text != "Tap mic to transcribe" else { return }
        textDocumentProxy.insertText(text)
        resetPreview()
    }

    @objc private func cancelTapped() {
        resetPreview()
    }

    private func resetPreview() {
        transcribedText = ""
        previewTextView.text = "Tap mic to transcribe"
        previewTextView.textColor = .lightGray
        previewTextView.isEditable = false
        actionStack.isHidden = true
        statusLabel.text = ""
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
            showError("No API key. Set it in the VoiceFlow app.")
            return
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .default)
            try session.setActive(true)
        } catch {
            showError("Audio session error: \(error.localizedDescription)")
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
            previewTextView.text = "Recording..."
            previewTextView.textColor = .white
            previewTextView.isEditable = false
            actionStack.isHidden = true
            statusLabel.text = "Tap stop when done"
            startRecordingAnimation()
        } catch {
            showError("Recorder error: \(error.localizedDescription)")
        }
    }

    private func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        updateMicButtonAppearance()
        recordingIndicator.isHidden = true
        stopRecordingAnimation()
        previewTextView.text = "Transcribing..."
        previewTextView.textColor = bitcoinOrange
        statusLabel.text = ""

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
            showError("No audio file found")
            return
        }

        guard let audioData = try? Data(contentsOf: audioFileURL) else {
            showError("Failed to read audio")
            return
        }

        guard let apiKey = readAPIKey(), !apiKey.isEmpty else {
            showError("No API key configured")
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
                    self?.showError("Network: \(error.localizedDescription)")
                    return
                }

                guard let data = data,
                      let http = response as? HTTPURLResponse else {
                    self?.showError("Invalid response")
                    return
                }

                if http.statusCode != 200 {
                    self?.showError("API error (\(http.statusCode))")
                    return
                }

                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    let text = json?["text"] as? String ?? ""
                    if text.isEmpty {
                        self?.showError("No speech detected")
                    } else {
                        self?.showTranscription(text)
                    }
                } catch {
                    self?.showError("Parse error")
                }
            }
        }.resume()
    }

    // MARK: - Display

    private func showTranscription(_ text: String) {
        transcribedText = text
        previewTextView.text = text
        previewTextView.textColor = .white
        previewTextView.isEditable = true
        actionStack.isHidden = false
        statusLabel.text = "Edit text, then Insert or Cancel"
    }

    private func showError(_ message: String) {
        previewTextView.text = message
        previewTextView.textColor = .systemRed
        previewTextView.isEditable = false
        actionStack.isHidden = true
        statusLabel.text = "Tap mic to try again"
        transcribedText = ""
    }
}
