import Foundation
import Network
import Combine
import ASCShared

/// Minimal localhost HTTP server exposing stored metrics for scripts and automations.
@MainActor
final class LocalAPIServer: ObservableObject {
    @Published private(set) var isRunning = false
    @Published var port: UInt16 = 8765
    @Published private(set) var lastError: String?

    weak var metricsEngine: MetricsEngine?
    weak var ascService: ASCService?

    private var listener: NWListener?

    func start() {
        guard !isRunning else { return }
        lastError = nil
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in self?.handle(connection) }
            }
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    switch state {
                    case .ready:
                        self?.isRunning = true
                        self?.lastError = nil
                    case .failed(let error):
                        self?.isRunning = false
                        self?.lastError = error.localizedDescription
                        self?.listener = nil
                    default:
                        break
                    }
                }
            }
            listener.start(queue: .global(qos: .utility))
            self.listener = listener
        } catch {
            lastError = error.localizedDescription
            isRunning = false
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .utility))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { [weak self] data, _, _, _ in
            Task { @MainActor in
                guard let self else { return }
                let request = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                let (status, body, contentType) = self.response(for: request)
                let response = Self.httpResponse(status: status, body: body, contentType: contentType)
                connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
            }
        }
    }

    private func response(for request: String) -> (Int, String, String) {
        let line = request.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? ""
        let parts = line.split(separator: " ")
        guard parts.count >= 2, parts[0] == "GET" else {
            return (404, #"{"error":"not found"}"#, "application/json")
        }
        let path = String(parts[1])
        switch path {
        case "/health":
            return (200, #"{"ok":true}"#, "application/json")
        case "/metrics":
            guard let engine = metricsEngine, let service = ascService else {
                return (503, #"{"error":"metrics unavailable"}"#, "application/json")
            }
            return (200, engine.exportPortfolioJSON(apps: service.apps), "application/json")
        default:
            if path.hasPrefix("/metrics/") {
                let appId = String(path.dropFirst("/metrics/".count))
                guard let engine = metricsEngine,
                      let app = ascService?.apps.first(where: { $0.id == appId }) else {
                    return (404, #"{"error":"app not found"}"#, "application/json")
                }
                return (200, engine.exportJSON(for: app), "application/json")
            }
            return (404, #"{"error":"not found"}"#, "application/json")
        }
    }

    private static func httpResponse(status: Int, body: String, contentType: String) -> Data {
        let phrase = status == 200 ? "OK" : "Not Found"
        let text = """
        HTTP/1.1 \(status) \(phrase)\r
        Content-Type: \(contentType)\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """
        return Data(text.utf8)
    }
}
