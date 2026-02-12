import UIKit
import AVFoundation

class KeyboardViewController: UIInputViewController {

    // MARK: - State
    private var isRecording = false
    private var audioRecorder: AVAudioRecorder?
    private var transcribedText: String = ""
    private var errorMessage: String?

    // MARK: - UI Elements
    private let micButton = UIButton(type: .system)
    private let nextKeyboardButton = UIButton(type: .system)
    private let previewLabel = UILabel()
    private let containerView = UIView()
    private let recordingIndicator = UIView()
    private let statusLabel = UILabel()

    // MARK: - Theme
    private let bitcoinOrange = UIColor(red: 247/255, green: 147/255, blue: 26/255, alpha: 1)
    private let darkBackground = UIColor(red: 13/255, green: 13/255, blue: 13/255, alpha: 1)
    private let darkSurface = UIColor(red: 26/255, green: 26/255, blue: 30/255, alpha: 1)

    // MARK: - Audio
    private var audioFileURL: URL {
        let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.lubodev.voiceflow")
            ?? FileManager.default.temporaryDirectory
        return dir.appendingPathComponent("keyboard_recording.m4a")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = darkBackground

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = darkBackground
        view.addSubview(containerView)

        // Preview area
        previewLabel.translatesAutoresizingMaskIntoConstraints = false
        previewLabel.text = "Tap mic to transcribe"
        previewLabel.textColor = .lightGray
        previewLabel.textAlignment = .center
        previewLabel.font = .systemFont(ofSize: 14)
        previewLabel.backgroundColor = darkSurface
        previewLabel.layer.cornerRadius = 8
        previewLabel.clipsToBounds = true
        previewLabel.numberOfLines = 3
        containerView.addSubview(previewLabel)

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
            containerView.heightAnchor.constraint(equalToConstant: 180),

            previewLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            previewLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            previewLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            previewLabel.heightAnchor.constraint(equalToConstant: 50),

            recordingIndicator.centerYAnchor.constraint(equalTo: previewLabel.centerYAnchor),
            recordingIndicator.trailingAnchor.constraint(equalTo: previewLabel.trailingAnchor, constant: -8),
            recordingIndicator.widthAnchor.constraint(equalToConstant: 10),
            recordingIndicator.heightAnchor.constraint(equalToConstant: 10),

            statusLabel.topAnchor.constraint(equalTo: previewLabel.bottomAnchor, constant: 4),
            statusLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            micButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            micButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
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

    // MARK: - Recording

    @objc private func micTapped() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        // Check API key
        guard !Config.openAIAPIKey.isEmpty else {
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
            previewLabel.text = "Recording..."
            previewLabel.textColor = .white
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
        previewLabel.text = "Transcribing..."
        previewLabel.textColor = bitcoinOrange
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

        let apiKey = Config.openAIAPIKey
        guard !apiKey.isEmpty else {
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
        // model
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(Config.whisperModel)\r\n".data(using: .utf8)!)
        // file
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
                    let errBody = String(data: data, encoding: .utf8) ?? "Unknown"
                    self?.showError("API error (\(http.statusCode))")
                    return
                }

                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    let text = json?["text"] as? String ?? ""
                    if text.isEmpty {
                        self?.showError("No speech detected")
                    } else {
                        self?.transcribedText = text
                        self?.previewLabel.text = text
                        self?.previewLabel.textColor = .white
                        self?.statusLabel.text = "Tap mic to record again"
                    }
                } catch {
                    self?.showError("Parse error")
                }
            }
        }.resume()
    }

    // MARK: - Error

    private func showError(_ message: String) {
        previewLabel.text = message
        previewLabel.textColor = .systemRed
        statusLabel.text = "Tap mic to try again"
        transcribedText = ""
    }
}
