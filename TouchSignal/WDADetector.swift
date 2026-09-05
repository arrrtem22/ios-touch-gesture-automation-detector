import Foundation
import Network

struct AutomationEvidence: Equatable {
    var score = 0
    var isConfirmed = false
    var port8100Open = false
    var port9100Open = false
    var hits: [String] = []
}

/// Detects an active WebDriverAgent service without trying to infer automation
/// from ordinary UIKit touch geometry. WDA normally exposes HTTP on device port
/// 8100 and its optional MJPEG stream on device port 9100.
final class WDADetector {
    var onEvidence: ((AutomationEvidence) -> Void)?

    private let queue = DispatchQueue(label: "com.arrrtem.TouchSignal.wda-probe")
    private var timer: DispatchSourceTimer?
    private var isChecking = false
    private var lastConfirmed: AutomationEvidence?
    private var lastConfirmedAt: Date?

    func start() {
        guard timer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: 1.25)
        timer.setEventHandler { [weak self] in self?.check() }
        self.timer = timer
        timer.resume()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func check() {
        guard !isChecking else { return }
        isChecking = true

        let statusRequest = "GET /status HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n"
        probe(port: 8100, request: statusRequest) { [weak self] statusOpen, response in
            guard let self else { return }
            self.probe(port: 9100, request: nil) { [weak self] mjpegOpen, _ in
                guard let self else { return }
                self.isChecking = false

                let text = response?.lowercased() ?? ""
                let hasStatusSignature = text.contains("webdriveragent") ||
                    text.contains("productbundleidentifier") ||
                    (text.contains("\"value\"") && text.contains("\"build\""))

                var evidence = AutomationEvidence()
                evidence.port8100Open = statusOpen
                evidence.port9100Open = mjpegOpen
                if statusOpen {
                    evidence.score += 80
                    evidence.hits.append("wda_http_open")
                }
                if hasStatusSignature {
                    evidence.score += 10
                    evidence.hits.append("wda_http_status")
                }
                if mjpegOpen {
                    evidence.score += 10
                    evidence.hits.append("wda_mjpeg_open")
                }
                evidence.score = min(evidence.score, 100)
                evidence.isConfirmed = evidence.score >= 80

                // Keep a positive result visible across brief WDA command/service gaps.
                if evidence.isConfirmed {
                    self.lastConfirmed = evidence
                    self.lastConfirmedAt = Date()
                } else if let prior = self.lastConfirmed,
                          let seenAt = self.lastConfirmedAt,
                          Date().timeIntervalSince(seenAt) < 5 {
                    evidence = prior
                }
                self.publish(evidence)
            }
        }
    }

    private func publish(_ evidence: AutomationEvidence) {
        DispatchQueue.main.async { [weak self] in self?.onEvidence?(evidence) }
    }

    private func probe(port: UInt16, request: String?, completion: @escaping (Bool, String?) -> Void) {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            completion(false, nil)
            return
        }

        let connection = NWConnection(host: "127.0.0.1", port: nwPort, using: .tcp)
        var completed = false
        var connected = false

        func finish(_ open: Bool, _ response: String?) {
            guard !completed else { return }
            completed = true
            connection.stateUpdateHandler = nil
            connection.cancel()
            completion(open, response)
        }

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                connected = true
                guard let request, let payload = request.data(using: .utf8) else {
                    finish(true, nil)
                    return
                }
                connection.send(content: payload, completion: .contentProcessed { error in
                    guard error == nil else {
                        finish(true, nil)
                        return
                    }
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { data, _, _, _ in
                        let response = data.flatMap { String(data: $0, encoding: .utf8) }
                        finish(true, response)
                    }
                })
            case .failed, .cancelled:
                finish(connected, nil)
            default:
                break
            }
        }

        connection.start(queue: queue)
        queue.asyncAfter(deadline: .now() + 0.8) {
            finish(connected, nil)
        }
    }
}
