import UIKit

class KeyboardViewController: UIInputViewController {

    // MARK: - UI Elements
    private let micButton = UIButton(type: .system)
    private let nextKeyboardButton = UIButton(type: .system)
    private let previewLabel = UILabel()
    private let containerView = UIView()

    // MARK: - Theme Constants
    private let bitcoinOrange = UIColor(red: 247/255, green: 147/255, blue: 26/255, alpha: 1)
    private let darkBackground = UIColor(red: 13/255, green: 13/255, blue: 13/255, alpha: 1)
    private let darkSurface = UIColor(red: 26/255, green: 26/255, blue: 30/255, alpha: 1)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = darkBackground

        // Container
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = darkBackground
        view.addSubview(containerView)

        // Preview label (placeholder for transcription preview)
        previewLabel.translatesAutoresizingMaskIntoConstraints = false
        previewLabel.text = "Tap mic to transcribe"
        previewLabel.textColor = .lightGray
        previewLabel.textAlignment = .center
        previewLabel.font = .systemFont(ofSize: 14)
        previewLabel.backgroundColor = darkSurface
        previewLabel.layer.cornerRadius = 8
        previewLabel.clipsToBounds = true
        containerView.addSubview(previewLabel)

        // Mic button (placeholder)
        micButton.translatesAutoresizingMaskIntoConstraints = false
        let micImage = UIImage(systemName: "mic.fill")?.withConfiguration(
            UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        )
        micButton.setImage(micImage, for: .normal)
        micButton.tintColor = darkBackground
        micButton.backgroundColor = bitcoinOrange
        micButton.layer.cornerRadius = 28
        micButton.clipsToBounds = true
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
            containerView.heightAnchor.constraint(equalToConstant: 160),

            previewLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            previewLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            previewLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            previewLabel.heightAnchor.constraint(equalToConstant: 44),

            micButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            micButton.topAnchor.constraint(equalTo: previewLabel.bottomAnchor, constant: 16),
            micButton.widthAnchor.constraint(equalToConstant: 56),
            micButton.heightAnchor.constraint(equalToConstant: 56),

            nextKeyboardButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            nextKeyboardButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -8),
            nextKeyboardButton.widthAnchor.constraint(equalToConstant: 36),
            nextKeyboardButton.heightAnchor.constraint(equalToConstant: 36),
        ])
    }
}
