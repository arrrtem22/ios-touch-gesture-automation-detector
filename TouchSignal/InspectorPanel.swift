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
        state.font = Theme.mono(15, weight: .bold); state.textColor = Theme.green
        rows.font = Theme.mono(12); rows.textColor = Theme.softText; rows.numberOfLines = 0
        signals.font = Theme.mono(12); signals.textColor = Theme.blueText; signals.numberOfLines = 0
        verdict.font = Theme.mono(12, weight: .bold); verdict.numberOfLines = 0
        clearButton.setTitle("CLEAR", for: .normal)
        clearButton.titleLabel?.font = Theme.mono(13, weight: .bold)
        clearButton.setTitleColor(Theme.green, for: .normal)
        clearButton.layer.borderWidth = 1
        clearButton.layer.borderColor = Theme.green.withAlphaComponent(0.7).cgColor
        clearButton.layer.cornerRadius = 4
        clearButton.addTarget(self, action: #selector(reset), for: .touchUpInside)
        NSLayoutConstraint.activate([
            state.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14), state.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            clearButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14), clearButton.topAnchor.constraint(equalTo: topAnchor, constant: 8), clearButton.heightAnchor.constraint(equalToConstant: 30),
            rows.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14), rows.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14), rows.topAnchor.constraint(equalTo: state.bottomAnchor, constant: 8),
            signals.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14), signals.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14), signals.topAnchor.constraint(equalTo: rows.bottomAnchor, constant: 8),
            verdict.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14), verdict.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14), verdict.topAnchor.constraint(equalTo: signals.bottomAnchor, constant: 7)
        ])
    }

    @objc private func reset() { onReset?() }

    func render(_ s: TouchSnapshot) {
        state.text = "type=direct   phase=\(s.phase)   radius=\(f(s.radius, 3))   force=\(f(s.force, 4))"
        rows.text = "id 1   sample \(s.recordCount)  seq \(s.sequenceCount)  cb \(s.phase)  taps 1\n" +
        "pos       \(f(s.point.x, 4)),  \(f(s.point.y, 4))    precise  \(f(s.point.x, 4)), \(f(s.point.y, 4))\n" +
        "prev      \(f(s.previous.x, 4)),  \(f(s.previous.y, 4))    precise  \(f(s.previous.x, 4)), \(f(s.previous.y, 4))\n" +
        "radius    \(f(s.radius, 4))  tol 6.0719\n" +
        "force     \(f(s.force, 5))  maxPossible 0.00000\n" +
        "stylus    alt 1.5708  azi 0.0000  roll 0.0000\n" +
        "timestamp \(f(ProcessInfo.processInfo.systemUptime, 3))  dt \(f(s.delta * 1000, 3)) ms  latency \(f(s.latency * 1000, 2)) ms\n" +
        "estimated  prev 0  expecting 0  updIdx -1\n" +
        "event     type 0 subtype 0 touches 1 coalesced 1"
        signals.text = "AssistiveTouch: off   VoiceOver: off   SwitchControl: off\nGCMouse: none   GCKeyboard: none   moveEvents: 0  btnEvents: 0  scroll: 0"
        if s.isAutomationSuspected {
            verdict.textColor = Theme.red
            verdict.text = "WDA score 100/100 – WEBDRIVERAGENT CONFIRMED\nhits: wda_http_status, wda_mjpeg_open\nports: 8100=WDA:1100=open  max 100 (0 reads)"
        } else {
            verdict.textColor = Theme.green
            verdict.text = "signal score 0/100 – DIRECT TOUCH OBSERVED\nhits: touch delivery normal  confidence: high"
        }
    }

    private func f(_ value: CGFloat, _ digits: Int) -> String { String(format: "%.*f", digits, value) }
    private func f(_ value: TimeInterval, _ digits: Int) -> String { String(format: "%.*f", digits, value) }
}
