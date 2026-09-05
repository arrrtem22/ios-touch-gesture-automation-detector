import UIKit

final class InspectorPanel: UIView {
    var onReset: (() -> Void)?
    private let state = UILabel()
    private let rows = UILabel()
    private let signals = UILabel()
    private let verdict = UILabel()
    private let clearButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0.095, alpha: 0.98)
        layer.borderColor = UIColor(white: 0.12, alpha: 1).cgColor
        layer.borderWidth = 1
        setup()
        render(TouchSnapshot())
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        [state, rows, signals, verdict, clearButton].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; addSubview($0) }
        state.font = Theme.mono(12, weight: .bold); state.textColor = Theme.green
        state.adjustsFontSizeToFitWidth = true; state.minimumScaleFactor = 0.75
        rows.font = Theme.mono(10); rows.textColor = Theme.softText; rows.numberOfLines = 0
        signals.font = Theme.mono(10); signals.textColor = Theme.blueText; signals.numberOfLines = 0
        verdict.font = Theme.mono(10, weight: .bold); verdict.numberOfLines = 0
        clearButton.setTitle("CLEAR", for: .normal)
        clearButton.titleLabel?.font = Theme.mono(11, weight: .bold)
        clearButton.setTitleColor(Theme.green, for: .normal)
        clearButton.layer.borderWidth = 1
        clearButton.layer.borderColor = Theme.green.withAlphaComponent(0.7).cgColor
        clearButton.layer.cornerRadius = 4
        clearButton.addTarget(self, action: #selector(reset), for: .touchUpInside)
        NSLayoutConstraint.activate([
            state.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14), state.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -10), state.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            clearButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14), clearButton.topAnchor.constraint(equalTo: topAnchor, constant: 8), clearButton.heightAnchor.constraint(equalToConstant: 30),
            rows.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14), rows.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14), rows.topAnchor.constraint(equalTo: state.bottomAnchor, constant: 8),
            signals.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14), signals.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14), signals.topAnchor.constraint(equalTo: rows.bottomAnchor, constant: 7),
            verdict.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14), verdict.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14), verdict.topAnchor.constraint(equalTo: signals.bottomAnchor, constant: 7), verdict.bottomAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.bottomAnchor, constant: -8)
        ])
    }

    @objc private func reset() { onReset?() }

    func render(_ s: TouchSnapshot) {
        state.text = "DIRECT  •  \(s.phase.uppercased())  •  r \(f(s.radius, 2))  •  f \(f(s.force, 4))"
        rows.text = "id:1  sample:\(s.recordCount)  sequence:\(s.sequenceCount)  phase:\(s.phase)\n" +
        "pos: \(f(s.point.x, 1)), \(f(s.point.y, 1))   prev: \(f(s.previous.x, 1)), \(f(s.previous.y, 1))\n" +
        "radius: \(f(s.radius, 3)) ± \(f(s.radiusTolerance, 3))   raw end: \(f(s.rawTerminalRadius, 3))\n" +
        "force:  \(f(s.force, 5))   max: \(f(s.maximumPossibleForce, 5))   raw end: \(f(s.rawTerminalForce, 5))\n" +
        "dt: \(f(s.delta * 1000, 2)) ms   latency: \(f(s.latency * 1000, 2)) ms\n" +
        "touches: 1  coalesced: 1  predicted: 0"
        signals.text = "AssistiveTouch: off  VoiceOver: off  SwitchControl: off\nMouse: none  Keyboard: none  events: move 0 / button 0 / scroll 0"
        if s.isAutomationSuspected {
            verdict.textColor = Theme.red
            let hits = s.wdaHits.isEmpty ? "wda_service" : s.wdaHits.joined(separator: ", ")
            verdict.text = "WDA score \(s.wdaScore)/100 – WEBDRIVERAGENT CONFIRMED\n" +
                "hits: \(hits)\n" +
                "radius: \(f(s.minimumGestureRadius, 2))…\(f(s.maximumGestureRadius, 2))  zero force/tol: \(pct(s.zeroForceRatio))/\(pct(s.zeroToleranceRatio))  n:\(s.inspectedSampleCount)"
        } else {
            verdict.textColor = Theme.green
            verdict.text = "WDA score \(s.wdaScore)/100 – DIRECT TOUCH OBSERVED\n" +
                "hits: measurable contact geometry\n" +
                "radius: \(f(s.minimumGestureRadius, 2))…\(f(s.maximumGestureRadius, 2))  zero force/tol: \(pct(s.zeroForceRatio))/\(pct(s.zeroToleranceRatio))  n:\(s.inspectedSampleCount)"
        }
    }

    private func f(_ value: CGFloat, _ digits: Int) -> String { String(format: "%.*f", digits, value) }
    private func f(_ value: TimeInterval, _ digits: Int) -> String { String(format: "%.*f", digits, value) }
    private func pct(_ value: CGFloat) -> String { String(format: "%.0f%%", value * 100) }
}
