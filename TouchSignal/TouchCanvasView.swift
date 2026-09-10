import UIKit

struct TouchSnapshot {
    var recordCount = 0
    var sequenceCount = 0
    var fingerText = "–"
    var phase = "ready"
    var point = CGPoint.zero
    var previous = CGPoint.zero
    var radius: CGFloat = 0
    var radiusTolerance: CGFloat = 0
    var force: CGFloat = 0
    var maximumPossibleForce: CGFloat = 0
    var rawTerminalRadius: CGFloat = 0
    var rawTerminalForce: CGFloat = 0
    var delta: TimeInterval = 0
    var latency: TimeInterval = 0
    var wdaScore = 0
    var wdaHits: [String] = []
    var inspectedSampleCount = 0
    var zeroRadiusRatio: CGFloat = 0
    var zeroForceRatio: CGFloat = 0
    var zeroToleranceRatio: CGFloat = 0
    var minimumGestureRadius: CGFloat = 0
    var maximumGestureRadius: CGFloat = 0
    var isAutomationSuspected = false
    var isEnded = false
}

private struct Sample {
    let point: CGPoint
    let radius: CGFloat
    let timestamp: TimeInterval
}

private struct GestureMetrics {
    var sampleCount = 0
    var zeroRadiusCount = 0
    var zeroForceCount = 0
    var zeroToleranceCount = 0
    var maximumRadius: CGFloat = 0
    var maximumForce: CGFloat = 0
    var minimumRadius: CGFloat = .greatestFiniteMagnitude
    var lastRadius: CGFloat = 0
    var lastRadiusTolerance: CGFloat = 0
    var lastForce: CGFloat = 0
    var lastMaximumPossibleForce: CGFloat = 0
    var maximumRadiusTolerance: CGFloat = 0

    mutating func observe(_ touch: UITouch) {
        sampleCount += 1
        maximumRadius = max(maximumRadius, touch.majorRadius)
        maximumForce = max(maximumForce, touch.force)
        minimumRadius = min(minimumRadius, touch.majorRadius)
        lastRadius = touch.majorRadius
        lastRadiusTolerance = touch.majorRadiusTolerance
        lastForce = touch.force
        lastMaximumPossibleForce = touch.maximumPossibleForce
        maximumRadiusTolerance = max(maximumRadiusTolerance, touch.majorRadiusTolerance)
        if touch.majorRadius <= 0.5 { zeroRadiusCount += 1 }
        if touch.force <= 0.001 { zeroForceCount += 1 }
        if touch.majorRadiusTolerance <= 0.01 { zeroToleranceCount += 1 }
    }

    var zeroRadiusRatio: CGFloat {
        sampleCount == 0 ? 0 : CGFloat(zeroRadiusCount) / CGFloat(sampleCount)
    }

    var zeroForceRatio: CGFloat {
        sampleCount == 0 ? 0 : CGFloat(zeroForceCount) / CGFloat(sampleCount)
    }

    var zeroToleranceRatio: CGFloat {
        sampleCount == 0 ? 0 : CGFloat(zeroToleranceCount) / CGFloat(sampleCount)
    }

    var evidence: AutomationEvidence {
        let enoughSamples = sampleCount >= 6
        let radiusSpread = maximumRadius - (minimumRadius == .greatestFiniteMagnitude ? 0 : minimumRadius)
        let sustainedZeroRadius = enoughSamples && zeroRadiusRatio >= 0.9 && maximumRadius <= 0.5
        let unnaturallyStableRadius = enoughSamples && minimumRadius > 0.5 && radiusSpread <= 0.10
        let sustainedZeroForce = enoughSamples && zeroForceRatio >= 0.9 && maximumForce <= 0.001
        // Real fingers on this device may also report zero force, but retain a
        // nonzero radius tolerance. WDA samples use exact, zero-tolerance geometry.
        let sustainedZeroTolerance = enoughSamples && zeroToleranceRatio >= 0.9 && maximumRadiusTolerance <= 0.01
        let confirmed = sustainedZeroForce && sustainedZeroTolerance && (sustainedZeroRadius || unnaturallyStableRadius)
        var hits: [String] = []
        if sustainedZeroRadius { hits.append("radius_zero_stream") }
        if unnaturallyStableRadius { hits.append("radius_constant_stream") }
        if sustainedZeroForce { hits.append("force_zero_stream") }
        if sustainedZeroTolerance { hits.append("tolerance_zero_stream") }
        return AutomationEvidence(
            score: confirmed ? 100 : 0,
            isConfirmed: confirmed,
            hits: confirmed ? hits : [],
            sampleCount: sampleCount,
            zeroRadiusRatio: zeroRadiusRatio,
            zeroForceRatio: zeroForceRatio,
            zeroToleranceRatio: zeroToleranceRatio,
            minimumRadius: minimumRadius == .greatestFiniteMagnitude ? 0 : minimumRadius,
            maximumRadius: maximumRadius
        )
    }
}

struct AutomationEvidence: Equatable {
    var score = 0
    var isConfirmed = false
    var hits: [String] = []
    var sampleCount = 0
    var zeroRadiusRatio: CGFloat = 0
    var zeroForceRatio: CGFloat = 0
    var zeroToleranceRatio: CGFloat = 0
    var minimumRadius: CGFloat = 0
    var maximumRadius: CGFloat = 0
}

final class TouchCanvasView: UIView {
    var onSnapshot: ((TouchSnapshot) -> Void)?
    private var samples: [ObjectIdentifier: [Sample]] = [:]
    private var latest = TouchSnapshot()
    private var gestureMetrics: [ObjectIdentifier: GestureMetrics] = [:]
    private var recordCount = 0
    private var sequenceCount = 0
    private var activeFingerCount = 0
    private var displayLink: CADisplayLink?
    private var pointerTrails: [[Sample]] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = Theme.background
        displayLink = CADisplayLink(target: self, selector: #selector(refresh))
        displayLink?.add(to: .main, forMode: .common)

        if #available(iOS 13.4, *) {
            let pointerPan = UIPanGestureRecognizer(target: self, action: #selector(handlePointerPan(_:)))
            pointerPan.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirectPointer.rawValue)]
            pointerPan.cancelsTouchesInView = false
            addGestureRecognizer(pointerPan)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { displayLink?.invalidate() }

    func reset() {
        samples.removeAll(); pointerTrails.removeAll(); gestureMetrics.removeAll(); recordCount = 0; sequenceCount = 0; activeFingerCount = 0
        latest = TouchSnapshot()
        setNeedsDisplay(); onSnapshot?(latest)
    }

    @available(iOS 13.4, *)
    @objc private func handlePointerPan(_ recognizer: UIPanGestureRecognizer) {
        let sample = Sample(
            point: recognizer.location(in: self),
            radius: 13,
            timestamp: ProcessInfo.processInfo.systemUptime
        )
        switch recognizer.state {
        case .began:
            pointerTrails.append([sample])
            if pointerTrails.count > 12 { pointerTrails.removeFirst(pointerTrails.count - 12) }
        case .changed, .ended, .cancelled:
            if pointerTrails.isEmpty { pointerTrails.append([]) }
            pointerTrails[pointerTrails.count - 1].append(sample)
            if pointerTrails[pointerTrails.count - 1].count > 96 {
                pointerTrails[pointerTrails.count - 1].removeFirst(pointerTrails[pointerTrails.count - 1].count - 96)
            }
        default:
            break
        }
        setNeedsDisplay()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        sequenceCount += 1
        activeFingerCount += touches.count
        for touch in touches { gestureMetrics[ObjectIdentifier(touch)] = GestureMetrics() }
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
            if phase == "began" || phase == "moved" {
                gestureMetrics[id, default: GestureMetrics()].observe(touch)
            }
            let evidence = gestureMetrics[id]?.evidence ?? AutomationEvidence()
            let metrics = gestureMetrics[id]
            let isTerminal = phase == "ended" || phase == "cancelled"
            let retainedRadius = isTerminal ? (metrics?.lastRadius ?? radius) : radius
            let retainedRadiusTolerance = isTerminal ? (metrics?.lastRadiusTolerance ?? touch.majorRadiusTolerance) : touch.majorRadiusTolerance
            let retainedForce = isTerminal ? (metrics?.lastForce ?? touch.force) : touch.force
            let retainedMaximumForce = isTerminal ? (metrics?.lastMaximumPossibleForce ?? touch.maximumPossibleForce) : touch.maximumPossibleForce
            let snapshot = TouchSnapshot(
                recordCount: recordCount,
                sequenceCount: sequenceCount,
                fingerText: String(activeFingerCount),
                phase: phase,
                point: point,
                previous: previous,
                radius: retainedRadius,
                radiusTolerance: retainedRadiusTolerance,
                force: retainedForce,
                maximumPossibleForce: retainedMaximumForce,
                rawTerminalRadius: isTerminal ? radius : retainedRadius,
                rawTerminalForce: isTerminal ? touch.force : retainedForce,
                delta: dt,
                latency: max(0, ProcessInfo.processInfo.systemUptime - touch.timestamp),
                wdaScore: evidence.score,
                wdaHits: evidence.hits,
                inspectedSampleCount: evidence.sampleCount,
                zeroRadiusRatio: evidence.zeroRadiusRatio,
                zeroForceRatio: evidence.zeroForceRatio,
                zeroToleranceRatio: evidence.zeroToleranceRatio,
                minimumGestureRadius: evidence.minimumRadius,
                maximumGestureRadius: evidence.maximumRadius,
                isAutomationSuspected: evidence.isConfirmed,
                isEnded: isTerminal
            )
            latest = snapshot
        }
        setNeedsDisplay(); onSnapshot?(latest)
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

        let trails = Array(samples.values) + pointerTrails
        for trail in trails {
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
