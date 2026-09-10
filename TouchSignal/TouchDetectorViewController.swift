import UIKit

final class TouchDetectorViewController: UIViewController {
    private let canvas = TouchCanvasView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        canvas.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(canvas)

        NSLayoutConstraint.activate([
            canvas.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            canvas.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            canvas.topAnchor.constraint(equalTo: view.topAnchor),
            canvas.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
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
