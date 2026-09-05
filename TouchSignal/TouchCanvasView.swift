import UIKit

struct TouchSnapshot {
    var recordCount = 0
    var sequenceCount = 0
    var fingerText = "–"
    var phase = "ready"
    var point = CGPoint.zero
    var previous = CGPoint.zero
    var radius: CGFloat = 0
    var force: CGFloat = 0
    var delta: TimeInterval = 0
    var latency: TimeInterval = 0
    var wdaScore = 0
    var wdaHits: [String] = []
    var wdaPort8100Open = false
    var wdaPort9100Open = false
    var isAutomationSuspected = false
    var isEnded = false
}

private struct Sample {
    let point: CGPoint
    let radius: CGFloat
    let timestamp: TimeInterval
}

final class TouchCanvasView: UIView {
    var onSnapshot: ((TouchSnapshot) -> Void)?
    private var samples: [ObjectIdentifier: [Sample]] = [:]
    private var latest = TouchSnapshot()
    private var recordCount = 0
    private var sequenceCount = 0
    private var activeFingerCount = 0
    private var automationEvidence = AutomationEvidence()
    private var displayLink: CADisplayLink?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = Theme.background
        displayLink = CADisplayLink(target: self, selector: #selector(refresh))
        displayLink?.add(to: .main, forMode: .common)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { displayLink?.invalidate() }

    func reset() {
        samples.removeAll(); recordCount = 0; sequenceCount = 0; activeFingerCount = 0
        latest = TouchSnapshot()
        applyAutomationEvidence(to: &latest)
        setNeedsDisplay(); onSnapshot?(latest)
    }

    func updateAutomationEvidence(_ evidence: AutomationEvidence) {
        automationEvidence = evidence
        applyAutomationEvidence(to: &latest)
        onSnapshot?(latest)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        sequenceCount += 1
        activeFingerCount += touches.count
        ingest(touches, phase: "began", event: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        ingest(touches, phase: "moved", event: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeFingerCount = max(0, activeFingerCount - touches.count)
        ingest(touches, phase: "ended", event: event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeFingerCount = max(0, activeFingerCount - touches.count)
        ingest(touches, phase: "cancelled", event: event)
    }

    private func ingest(_ touches: Set<UITouch>, phase: String, event: UIEvent?) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            let point = touch.location(in: self)
            let previous = touch.previousLocation(in: self)
            let history = samples[id] ?? []
            let dt = history.last.map { touch.timestamp - $0.timestamp } ?? 0
            let radius = touch.majorRadius
            let sample = Sample(point: point, radius: radius, timestamp: touch.timestamp)
            samples[id, default: []].append(sample)
            if samples[id]!.count > 96 { samples[id]!.removeFirst(samples[id]!.count - 96) }
            recordCount += 1
            var snapshot = TouchSnapshot(
                recordCount: recordCount,
                sequenceCount: sequenceCount,
                fingerText: String(activeFingerCount),
                phase: phase,
                point: point,
                previous: previous,
                radius: radius,
                force: touch.force,
                delta: dt,
                latency: max(0, ProcessInfo.processInfo.systemUptime - touch.timestamp),
                isEnded: phase == "ended" || phase == "cancelled"
            )
            applyAutomationEvidence(to: &snapshot)
            latest = snapshot
        }
        setNeedsDisplay(); onSnapshot?(latest)
    }

    private func applyAutomationEvidence(to snapshot: inout TouchSnapshot) {
        snapshot.wdaScore = automationEvidence.score
        snapshot.wdaHits = automationEvidence.hits
        snapshot.wdaPort8100Open = automationEvidence.port8100Open
        snapshot.wdaPort9100Open = automationEvidence.port9100Open
        snapshot.isAutomationSuspected = automationEvidence.isConfirmed
    }

    @objc private func refresh() { setNeedsDisplay() }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.setFillColor(Theme.background.cgColor); context.fill(rect)
        context.setStrokeColor(Theme.grid.cgColor); context.setLineWidth(1)
        let spacing: CGFloat = 96
        for x in stride(from: CGFloat(0), through: bounds.width, by: spacing) { context.move(to: CGPoint(x: x, y: 0)); context.addLine(to: CGPoint(x: x, y: bounds.height)) }
        for y in stride(from: CGFloat(0), through: bounds.height, by: spacing) { context.move(to: CGPoint(x: 0, y: y)); context.addLine(to: CGPoint(x: bounds.width, y: y)) }
        context.strokePath()

        for trail in samples.values {
            guard let first = trail.first else { continue }
            context.setStrokeColor(Theme.cyan.cgColor); context.setLineWidth(2.4); context.setLineJoin(.round)
            context.move(to: first.point)
            for sample in trail.dropFirst() { context.addLine(to: sample.point) }
            context.strokePath()
            for sample in trail {
                let radius = max(8, min(sample.radius, 40))
                context.setStrokeColor(Theme.cyan.withAlphaComponent(0.10).cgColor); context.setLineWidth(2)
                context.strokeEllipse(in: CGRect(x: sample.point.x - radius, y: sample.point.y - radius, width: radius * 2, height: radius * 2))
                context.setFillColor(Theme.yellow.cgColor)
                context.fillEllipse(in: CGRect(x: sample.point.x - 4.2, y: sample.point.y - 4.2, width: 8.4, height: 8.4))
            }
            if let end = trail.last {
                context.setStrokeColor(Theme.green.cgColor); context.setLineWidth(2)
                context.strokeEllipse(in: CGRect(x: end.point.x - 12, y: end.point.y - 12, width: 24, height: 24))
                context.move(to: CGPoint(x: end.point.x - 18, y: end.point.y)); context.addLine(to: CGPoint(x: end.point.x + 18, y: end.point.y))
                context.move(to: CGPoint(x: end.point.x, y: end.point.y - 18)); context.addLine(to: CGPoint(x: end.point.x, y: end.point.y + 18)); context.strokePath()
            }
        }
    }
}
