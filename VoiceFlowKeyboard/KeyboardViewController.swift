import UIKit
import AVFoundation

class KeyboardViewController: UIInputViewController {

    // MARK: - State
    private enum KeyboardState {
        case idle
        case recording
        case transcribing
        case error(String)
    }
    
    private var state: KeyboardState = .idle {
        didSet { updateUI(for: state) }
    }
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingStartTime: Date?
    private var recordingTimer: Timer?
    
    /// Known Whisper hallucination outputs on silence/noise (#39)
    private let whisperHallucinations: Set<String> = [
        "you", "thank you", "thank you.", "thanks for watching!",
        "thanks for watching.", "the end.", "the end",
        "thanks for listening.", "thanks for listening!",
        "subscribe", "bye.", "bye", "so",
        "thank you for watching!", "thank you for watching.",
        "subtitles by the amara.org community",
        "subtitles", ".", "..", "...", "♪", "♪♪", "♪ ♪",
        "thank you so much for watching!",
        "please subscribe to the channel",
        "thanks for watching",
    ]

    // MARK: - UI Elements
    private let micButton = UIButton(type: .system)
    private let containerView = UIView()
    private let statusLabel = UILabel()
    private let hintLabel = UILabel()
    private let fullAccessBanner = UILabel()
    private let timerLabel = UILabel()
    private let glowLayer = CAShapeLayer()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let languageButton = UIButton(type: .system) // #39

    // MARK: - Theme
    private let bitcoinOrange = UIColor(red: 247/255, green: 147/255, blue: 26/255, alpha: 1)
    private let darkBackground = UIColor(red: 13/255, green: 13/255, blue: 13/255, alpha: 1)
    private let darkSurface = UIColor(red: 26/255, green: 26/255, blue: 30/255, alpha: 1)

    // MARK: - App Group
    private let appGroupID = "group.com.lubodev.voiceflow"
    
    // MARK: - Language (#39)
    private var selectedLanguage: String {
        get {
            UserDefaults(suiteName: appGroupID)?.string(forKey: "stt_language") ?? "auto"
        }
        set {
            UserDefaults(suiteName: appGroupID)?.set(newValue, forKey: "stt_language")
            updateLanguageButton()
        }
    }
    
    private let supportedLanguages: [(code: String, name: String)] = [
        ("auto", "Auto"),
        ("en", "English"),
        ("bg", "Bulgarian"),
        ("es", "Spanish"),
        ("fr", "French"),
        ("de", "German"),
        ("ja", "Japanese"),
        ("zh", "Chinese"),
        ("ru", "Russian"),
        ("pt", "Portuguese"),
        ("it", "Italian"),
        ("ko", "Korean"),
    ]
    
    // MARK: - Audio
    private var audioFileURL: URL {
        if let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            return dir.appendingPathComponent("keyboard_recording.m4a")
        }
        NSLog("[VoiceFlowKB] App Group container unavailable, using temp directory")
        return FileManager.default.temporaryDirectory.appendingPathComponent("keyboard_recording.m4a")
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
        
        // Prevent UI jumping when switching to this keyboard
        // Set self-sizing and fixed height before the view appears
        inputView?.allowsSelfSizing = true
        
        setupUI()
        checkFullAccess()
        
        // Start invisible, fade in during viewDidAppear to avoid layout flash
        containerView.alpha = 0
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.15) {
            self.containerView.alpha = 1
        }
    }
    
    private func checkFullAccess() {
        if !hasFullAccess {
            fullAccessBanner.isHidden = false
            micButton.isEnabled = false
            hintLabel.text = "Full Access required"
            hintLabel.textColor = bitcoinOrange.withAlphaComponent(0.7)
        } else {
            fullAccessBanner.isHidden = true
            micButton.isEnabled = true
        }
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = UIColor.clear

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = UIColor.clear
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
        fullAccessBanner.accessibilityLabel = "Full Access required. Enable in Settings, Keyboards, VoiceFlow."
        containerView.addSubview(fullAccessBanner)

        // Language button (#39)
        languageButton.translatesAutoresizingMaskIntoConstraints = false
        languageButton.titleLabel?.font = .monospacedSystemFont(ofSize: 12, weight: .bold)
        languageButton.setTitleColor(bitcoinOrange, for: .normal)
        languageButton.backgroundColor = darkSurface
        languageButton.layer.cornerRadius = 12
        languageButton.clipsToBounds = true
        var langConfig = UIButton.Configuration.plain()
        langConfig.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
        languageButton.configuration = langConfig
        languageButton.showsMenuAsPrimaryAction = true
        languageButton.accessibilityLabel = "Language selector"
        languageButton.accessibilityHint = "Tap to change transcription language"
        updateLanguageButton()
        buildLanguageMenu()
        containerView.addSubview(languageButton)

        // Mic button
        micButton.translatesAutoresizingMaskIntoConstraints = false
        micButton.layer.cornerRadius = 36
        micButton.clipsToBounds = false
        micButton.addTarget(self, action: #selector(micTapped), for: .touchUpInside)
        micButton.accessibilityLabel = "Record"
        micButton.accessibilityHint = "Tap to start voice recording"
        containerView.addSubview(micButton)
        
        // Glow layer
        glowLayer.fillColor = UIColor.clear.cgColor
        glowLayer.strokeColor = bitcoinOrange.cgColor
        glowLayer.lineWidth = 3
        glowLayer.opacity = 0
        let glowPath = UIBezierPath(ovalIn: CGRect(x: -6, y: -6, width: 84, height: 84))
        glowLayer.path = glowPath.cgPath
        micButton.layer.addSublayer(glowLayer)

        // Hint label
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.text = "Tap to speak"
        hintLabel.textColor = .lightGray
        hintLabel.textAlignment = .center
        hintLabel.font = .systemFont(ofSize: 13, weight: .regular)
        containerView.addSubview(hintLabel)
        
        // Timer label
        timerLabel.translatesAutoresizingMaskIntoConstraints = false
        timerLabel.text = "0:00"
        timerLabel.textColor = .white
        timerLabel.textAlignment = .center
        timerLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        timerLabel.isHidden = true
        containerView.addSubview(timerLabel)

        // Status label
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = ""
        statusLabel.textColor = .lightGray
        statusLabel.textAlignment = .center
        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        statusLabel.numberOfLines = 2
        containerView.addSubview(statusLabel)
        
        // Activity indicator
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.color = bitcoinOrange
        activityIndicator.hidesWhenStopped = true
        containerView.addSubview(activityIndicator)

        updateMicButtonAppearance(recording: false)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.heightAnchor.constraint(equalToConstant: 200),
            
            fullAccessBanner.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 4),
            fullAccessBanner.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            fullAccessBanner.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            fullAccessBanner.heightAnchor.constraint(equalToConstant: 32),

            // Language button top-right
            languageButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            languageButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            languageButton.heightAnchor.constraint(equalToConstant: 28),

            micButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            micButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor, constant: -8),
            micButton.widthAnchor.constraint(equalToConstant: 72),
            micButton.heightAnchor.constraint(equalToConstant: 72),

            timerLabel.bottomAnchor.constraint(equalTo: micButton.topAnchor, constant: -10),
            timerLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            hintLabel.topAnchor.constraint(equalTo: micButton.bottomAnchor, constant: 10),
            hintLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            activityIndicator.topAnchor.constraint(equalTo: micButton.bottomAnchor, constant: 10),
            activityIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            statusLabel.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 4),
            statusLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
        ])
    }
    
    // MARK: - Language UI (#39)
    
    private func updateLanguageButton() {
        let code = selectedLanguage == "auto" ? "AUTO" : selectedLanguage.uppercased()
        languageButton.setTitle(code, for: .normal)
    }
    
    private func buildLanguageMenu() {
        let actions = supportedLanguages.map { lang in
            UIAction(
                title: lang.name,
                subtitle: lang.code == "auto" ? nil : lang.code.uppercased(),
                state: selectedLanguage == lang.code ? .on : .off
            ) { [weak self] _ in
                self?.selectedLanguage = lang.code
                self?.buildLanguageMenu() // Refresh checkmarks
            }
        }
        languageButton.menu = UIMenu(title: "Transcription Language", children: actions)
    }

    private func updateMicButtonAppearance(recording: Bool) {
        let iconName = recording ? "stop.fill" : "mic.fill"
        let bgColor = recording ? UIColor.systemRed : bitcoinOrange
        let micImage = UIImage(systemName: iconName)?.withConfiguration(
            UIImage.SymbolConfiguration(pointSize: 32, weight: .medium)
        )
        micButton.setImage(micImage, for: .normal)
        micButton.tintColor = darkBackground
        micButton.backgroundColor = bgColor
        micButton.accessibilityLabel = recording ? "Stop recording" : "Start recording"
    }
    
    // MARK: - UI State Machine
    
    private func updateUI(for state: KeyboardState) {
        statusLabel.text = ""
        statusLabel.textColor = .lightGray
        timerLabel.isHidden = true
        activityIndicator.stopAnimating()
        
        switch state {
        case .idle:
            updateMicButtonAppearance(recording: false)
            hintLabel.text = "Tap to speak"
            hintLabel.textColor = .lightGray
            hintLabel.isHidden = false
            stopGlowAnimation()
            animateButtonScale(to: 1.0)
            micButton.isEnabled = hasFullAccess
            languageButton.isHidden = false
            
        case .recording:
            updateMicButtonAppearance(recording: true)
            hintLabel.text = "Recording… tap to stop"
            hintLabel.textColor = .white
            hintLabel.isHidden = false
            timerLabel.isHidden = false
            timerLabel.text = "0:00"
            startGlowAnimation()
            animateButtonScale(to: 1.12)
            languageButton.isHidden = true
            UIAccessibility.post(notification: .announcement, argument: "Recording started")
            
        case .transcribing:
            updateMicButtonAppearance(recording: false)
            hintLabel.isHidden = true
            activityIndicator.startAnimating()
            stopGlowAnimation()
            animateButtonScale(to: 1.0)
            micButton.isEnabled = false
            languageButton.isHidden = true
            UIAccessibility.post(notification: .announcement, argument: "Transcribing audio")
            
        case .error(let message):
            updateMicButtonAppearance(recording: false)
            hintLabel.isHidden = true
            statusLabel.text = message
            statusLabel.textColor = .systemRed
            stopGlowAnimation()
            animateButtonScale(to: 1.0)
            micButton.isEnabled = hasFullAccess
            languageButton.isHidden = false
            UIAccessibility.post(notification: .announcement, argument: "Error: \(message)")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
                if case .error = self?.state {
                    self?.state = .idle
                }
            }
        }
    }

    // MARK: - Animations
    
    private func animateButtonScale(to scale: CGFloat) {
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.micButton.transform = CGAffineTransform(scaleX: scale, y: scale)
        }
    }
    
    private func startGlowAnimation() {
        glowLayer.opacity = 1
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 0.9
        pulse.toValue = 0.2
        pulse.duration = 0.8
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        glowLayer.add(pulse, forKey: "glowPulse")
        
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1.0
        scale.toValue = 1.15
        scale.duration = 0.8
        scale.autoreverses = true
        scale.repeatCount = .infinity
        scale.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        glowLayer.add(scale, forKey: "glowScale")
    }
    
    private func stopGlowAnimation() {
        glowLayer.removeAllAnimations()
        glowLayer.opacity = 0
    }

    // MARK: - Recording

    @objc private func micTapped() {
        UIView.animate(withDuration: 0.1, animations: {
            self.micButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            if case .recording = self.state {
                self.stopRecording()
            } else {
                self.startRecording()
            }
        }
    }

    private func startRecording() {
        guard hasFullAccess else {
            state = .error("Enable Full Access in Settings → Keyboards → VoiceFlow")
            return
        }
        
        // AVAudioApplication doesn't work in keyboard extensions — must use AVAudioSession
        // nonisolated(unsafe) suppression: AVAudioSession is the only working API in extensions
        let micPermission = AVAudioSession.sharedInstance().recordPermission // Deprecated in iOS 17, but AVAudioApplication reports .denied in extension sandbox
        switch micPermission {
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.startRecording()
                    } else {
                        self?.state = .error("🎤 Microphone access denied. Allow in Settings → Privacy → Microphone.")
                    }
                }
            }
            return
        case .denied:
            state = .error("🎤 Microphone access denied. Allow in Settings → Privacy → Microphone.")
            return
        case .granted:
            break
        @unknown default:
            break
        }
        
        guard let apiKey = readAPIKey(), !apiKey.isEmpty else {
            state = .error("No API key. Set it in the VoiceFlow app.")
            return
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .default)
            try session.setActive(true)
        } catch let error as NSError {
            NSLog("[VoiceFlowKB] Audio session error: \(error.domain) \(error.code) - \(error.localizedDescription)")
            if error.code == 561017449 || error.domain == "NSOSStatusErrorDomain" {
                state = .error("🎤 Microphone access denied. Enable Full Access in Settings.")
            } else {
                state = .error("Audio session failed: \(error.localizedDescription)")
            }
            return
        }

        let fileURL = audioFileURL
        try? FileManager.default.removeItem(at: fileURL)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.isMeteringEnabled = true
        } catch {
            NSLog("[VoiceFlowKB] Recorder init error: \(error)")
            state = .error("Failed to create recorder: \(error.localizedDescription)")
            return
        }
        
        let started = audioRecorder?.record() ?? false
        if !started || audioRecorder?.isRecording != true {
            NSLog("[VoiceFlowKB] Recorder failed to start. isRecording=\(audioRecorder?.isRecording ?? false)")
            audioRecorder = nil
            state = .error("Recorder failed to start. Check microphone permissions.")
            return
        }
        
        recordingStartTime = Date()
        state = .recording
        
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.recordingStartTime else { return }
            let elapsed = Int(-start.timeIntervalSinceNow)
            let mins = elapsed / 60
            let secs = elapsed % 60
            self.timerLabel.text = "\(mins):\(String(format: "%02d", secs))"
        }
    }

    private func stopRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        let duration = -(recordingStartTime ?? Date()).timeIntervalSinceNow
        audioRecorder?.stop()
        audioRecorder = nil
        UIAccessibility.post(notification: .announcement, argument: "Recording stopped")

        guard duration >= 0.5 else {
            state = .error("Recording too short")
            return
        }
        
        let fileURL = audioFileURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            NSLog("[VoiceFlowKB] Audio file missing after recording at: \(fileURL.path)")
            state = .error("No audio file created. Microphone may be unavailable.")
            return
        }
        
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = attrs[.size] as? UInt64 ?? 0
            NSLog("[VoiceFlowKB] Audio file size: \(fileSize) bytes, duration: \(String(format: "%.1f", duration))s")
            if fileSize == 0 {
                state = .error("No audio captured. Microphone may not be accessible.")
                return
            }
        } catch {
            NSLog("[VoiceFlowKB] Cannot read file attributes: \(error)")
            state = .error("Cannot read audio file")
            return
        }

        state = .transcribing
        transcribeAudio()
    }

    // MARK: - Hallucination Filtering (#39)
    
    private func isHallucination(_ text: String, noSpeechProb: Double) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Empty or very short
        if trimmed.isEmpty { return true }
        
        // High no-speech probability
        if noSpeechProb > 0.5 { return true }
        
        // Known hallucination phrases
        if whisperHallucinations.contains(trimmed.lowercased()) { return true }
        
        // Repeated single character/word patterns (e.g. "you you you")
        let words = trimmed.lowercased().split(separator: " ")
        if words.count >= 3 {
            let unique = Set(words)
            if unique.count == 1 { return true }
        }
        
        // Very short with moderate no-speech probability
        if trimmed.count < 5 && noSpeechProb > 0.3 { return true }
        
        return false
    }

    // MARK: - Transcription

    private func transcribeAudio() {
        let fileURL = audioFileURL
        
        guard let audioData = try? Data(contentsOf: fileURL), !audioData.isEmpty else {
            state = .error("Failed to read audio file")
            return
        }

        guard let apiKey = readAPIKey(), !apiKey.isEmpty else {
            state = .error("No API key configured")
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
        
        // Language (#39)
        let lang = selectedLanguage
        if lang != "auto" && !lang.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(lang)\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("verbose_json\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    NSLog("[VoiceFlowKB] Network error: \(error)")
                    self.state = .error("Network: \(error.localizedDescription)")
                    return
                }

                guard let data = data,
                      let http = response as? HTTPURLResponse else {
                    self.state = .error("No response from server")
                    return
                }

                if http.statusCode != 200 {
                    let body = String(data: data, encoding: .utf8) ?? "unknown"
                    NSLog("[VoiceFlowKB] API error \(http.statusCode): \(body)")
                    self.state = .error("API error \(http.statusCode)")
                    return
                }

                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    let text = (json?["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Get no_speech_prob from segments (#39)
                    var noSpeechProb: Double = 0
                    if let segments = json?["segments"] as? [[String: Any]], let first = segments.first {
                        noSpeechProb = first["no_speech_prob"] as? Double ?? 0
                    }
                    
                    if self.isHallucination(text, noSpeechProb: noSpeechProb) {
                        self.state = .error("No speech detected. Try again.")
                    } else {
                        self.textDocumentProxy.insertText(text)
                        self.statusLabel.text = "✓ Inserted"
                        self.statusLabel.textColor = .lightGray
                        self.hintLabel.isHidden = true
                        self.activityIndicator.stopAnimating()
                        self.micButton.isEnabled = self.hasFullAccess
                        UIAccessibility.post(notification: .announcement, argument: "Transcription complete. Text inserted.")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            self.state = .idle
                        }
                    }
                } catch {
                    NSLog("[VoiceFlowKB] JSON parse error: \(error)")
                    self.state = .error("Failed to parse response")
                }
            }
        }.resume()
    }
}
