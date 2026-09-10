import UIKit

final class TouchDetectorViewController: UIViewController {
    private let canvas = TouchCanvasView()
    private let inspector = InspectorPanel()
    private let topBar = UILabel()
    private let infoButton = UIButton(type: .system)
    private var showsInspector = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        canvas.translatesAutoresizingMaskIntoConstraints = false
        inspector.translatesAutoresizingMaskIntoConstraints = false
        topBar.translatesAutoresizingMaskIntoConstraints = false
        infoButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(canvas)
        view.addSubview(inspector)
        view.addSubview(topBar)
        view.addSubview(infoButton)

        topBar.font = Theme.mono(13, weight: .medium)
        topBar.textAlignment = .right
        topBar.adjustsFontSizeToFitWidth = true
        topBar.minimumScaleFactor = 0.7
        topBar.textColor = Theme.softText
        topBar.backgroundColor = UIColor(white: 0.08, alpha: 0.96)
        topBar.text = "records 0   sequences 0   finger:–"

        infoButton.setImage(UIImage(systemName: "info.circle.fill"), for: .normal)
        infoButton.tintColor = Theme.cyan
        infoButton.backgroundColor = UIColor(white: 0.10, alpha: 0.86)
        infoButton.layer.cornerRadius = 22
        infoButton.accessibilityLabel = "Show gesture info"
        infoButton.addTarget(self, action: #selector(toggleInspector), for: .touchUpInside)

        inspector.onReset = { [weak self] in self?.canvas.reset() }
        canvas.onSnapshot = { [weak self] snapshot in
            self?.topBar.text = "records \(snapshot.recordCount)   sequences \(snapshot.sequenceCount)   finger:\(snapshot.fingerText)"
            self?.inspector.render(snapshot)
        }

        inspector.isHidden = true
        topBar.isHidden = true

        NSLayoutConstraint.activate([
            canvas.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            canvas.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            canvas.topAnchor.constraint(equalTo: view.topAnchor),
            canvas.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            infoButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            infoButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            infoButton.widthAnchor.constraint(equalToConstant: 44),
            infoButton.heightAnchor.constraint(equalToConstant: 44),
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            topBar.trailingAnchor.constraint(equalTo: infoButton.leadingAnchor, constant: -10),
            topBar.heightAnchor.constraint(equalToConstant: 44),
            inspector.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inspector.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inspector.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            inspector.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.42)
        ])
    }

    @objc private func toggleInspector() {
        showsInspector.toggle()
        inspector.isHidden = !showsInspector
        topBar.isHidden = !showsInspector
        let icon = showsInspector ? "xmark.circle.fill" : "info.circle.fill"
        infoButton.setImage(UIImage(systemName: icon), for: .normal)
        infoButton.accessibilityLabel = showsInspector ? "Hide gesture info" : "Show gesture info"
    }

    override var prefersStatusBarHidden: Bool { true }

}

enum Theme {
    static let background = UIColor(red: 0.045, green: 0.049, blue: 0.050, alpha: 1)
    static let grid = UIColor(red: 0.10, green: 0.11, blue: 0.12, alpha: 1)
    static let cyan = UIColor(red: 0.10, green: 0.76, blue: 0.93, alpha: 1)
    static let yellow = UIColor(red: 1.0, green: 0.80, blue: 0.14, alpha: 1)
    static let green = UIColor(red: 0.13, green: 0.78, blue: 0.37, alpha: 1)
    static let blueText = UIColor(red: 0.39, green: 0.66, blue: 0.88, alpha: 1)
    static let red = UIColor(red: 0.88, green: 0.23, blue: 0.24, alpha: 1)
    static let softText = UIColor(red: 0.66, green: 0.68, blue: 0.69, alpha: 1)
    static func mono(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        UIFont.monospacedSystemFont(ofSize: size, weight: weight)
    }
}
