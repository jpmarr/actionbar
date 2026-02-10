import Foundation

enum SmeeConnectionState: Sendable {
    case disconnected
    case connecting
    case connected
}

struct WebhookEvent: Sendable {
    let action: String
    let workflowRun: WorkflowRun
    let repositoryFullName: String
}

actor SmeeService {
    private var connectionTask: Task<Void, Never>?
    private var onWebhookEvent: (@Sendable (WebhookEvent) -> Void)?
    private var onConnectionStateChanged: (@Sendable (SmeeConnectionState) -> Void)?

    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    init() {}

    func setOnWebhookEvent(_ handler: (@Sendable (WebhookEvent) -> Void)?) {
        self.onWebhookEvent = handler
    }

    func setOnConnectionStateChanged(_ handler: (@Sendable (SmeeConnectionState) -> Void)?) {
        self.onConnectionStateChanged = handler
    }

    // MARK: - Channel Creation

    /// Creates a new Smee channel by requesting smee.io/new and extracting the redirect Location.
    func createChannel() async throws -> String {
        let config = URLSessionConfiguration.ephemeral
        let delegate = NoRedirectDelegate()
        let noRedirectSession = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        defer { noRedirectSession.finishTasksAndInvalidate() }

        let url = URL(string: "https://smee.io/new")!
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"

        let (_, response) = try await noRedirectSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (300..<400).contains(httpResponse.statusCode),
              let location = httpResponse.value(forHTTPHeaderField: "Location"),
              location.hasPrefix("https://smee.io/") else {
            throw SmeeError.channelCreationFailed
        }
        return location
    }

    // MARK: - Connection Lifecycle

    func start(url: String) {
        stop()
        smeeLog("[Smee] Starting with URL: \(url)")
        let eventHandler = self.onWebhookEvent
        let stateHandler = self.onConnectionStateChanged
        let decoder = self.jsonDecoder
        connectionTask = Task.detached {
            await Self.connectionLoop(
                url: url,
                decoder: decoder,
                onEvent: eventHandler,
                onStateChanged: stateHandler
            )
        }
    }

    func stop() {
        connectionTask?.cancel()
        connectionTask = nil
        onConnectionStateChanged?(.disconnected)
    }

    // MARK: - Connection Loop with Exponential Backoff

    private static func connectionLoop(
        url: String,
        decoder: JSONDecoder,
        onEvent: (@Sendable (WebhookEvent) -> Void)?,
        onStateChanged: (@Sendable (SmeeConnectionState) -> Void)?
    ) async {
        var backoff: TimeInterval = 1

        while !Task.isCancelled {
            onStateChanged?(.connecting)
            smeeLog("[Smee] Attempting connection to \(url)")
            do {
                try await connect(
                    to: url,
                    decoder: decoder,
                    onEvent: onEvent,
                    onStateChanged: onStateChanged
                )
                smeeLog("[Smee] Connection ended normally")
            } catch is CancellationError {
                smeeLog("[Smee] Connection cancelled")
                break
            } catch {
                smeeLog("[Smee] Connection error: \(error)")
            }

            if Task.isCancelled { break }
            onStateChanged?(.disconnected)

            try? await Task.sleep(for: .seconds(backoff))
            backoff = min(backoff * 2, 60)
        }
        onStateChanged?(.disconnected)
    }

    // MARK: - SSE Connection (delegate-based streaming)

    private static func connect(
        to urlString: String,
        decoder: JSONDecoder,
        onEvent: (@Sendable (WebhookEvent) -> Void)?,
        onStateChanged: (@Sendable (SmeeConnectionState) -> Void)?
    ) async throws {
        guard let url = URL(string: urlString) else {
            throw SmeeError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 300 // 5 min timeout, SSE connections are long-lived

        smeeLog("[Smee] Sending SSE request to \(urlString)")

        // Use a delegate-based session that streams data incrementally
        let sseDelegate = SSEDelegate()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 86400 // keep alive for a day
        let session = URLSession(configuration: config, delegate: sseDelegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        let task = session.dataTask(with: request)
        task.resume()

        smeeLog("[Smee] Task started, waiting for lines...")

        var didConnect = false

        for await line in sseDelegate.lines {
            if Task.isCancelled { break }

            if !didConnect {
                didConnect = true
                onStateChanged?(.connected)
                smeeLog("[Smee] First data received, connected")
            }

            smeeLog("[Smee] Line: \(String(line.prefix(200)))")

            let parsed = sseDelegate.feedLine(line)
            if let (eventType, data) = parsed {
                smeeLog("[Smee] SSE event: type=\(eventType ?? "nil"), len=\(data.count)")
                smeeLog("[Smee] Data prefix: \(String(data.prefix(500)))")
                if eventType == nil || eventType == "message" {
                    if let event = parseWebhookEvent(from: data, decoder: decoder) {
                        smeeLog("[Smee] Parsed: action=\(event.action), repo=\(event.repositoryFullName), run=\(event.workflowRun.id)")
                        onEvent?(event)
                    } else {
                        smeeLog("[Smee] Failed to parse webhook event")
                    }
                } else {
                    smeeLog("[Smee] Skipping event type: \(eventType ?? "")")
                }
            }
        }

        if let error = sseDelegate.error {
            throw error
        }
    }

    // MARK: - Payload Decoding

    /// Parses a Smee SSE data payload into a WebhookEvent.
    /// Smee wraps the GitHub payload: `{"body": <GitHub payload as JSON object>, ...}`
    static func parseWebhookEvent(from data: String, decoder: JSONDecoder? = nil) -> WebhookEvent? {
        let decoder = decoder ?? {
            let d = JSONDecoder()
            d.dateDecodingStrategy = .iso8601
            return d
        }()

        guard let outerData = data.data(using: .utf8) else { return nil }

        // Smee wrapper has a "body" field containing the GitHub webhook payload
        struct SmeeWrapper: Decodable {
            let body: AnyCodable?
            let action: String?

            enum CodingKeys: String, CodingKey {
                case body
                case action
            }
        }

        guard let wrapper = try? decoder.decode(SmeeWrapper.self, from: outerData) else {
            return nil
        }

        // The body could be a JSON string (double-encoded) or a JSON object
        let payloadData: Data?
        if let body = wrapper.body {
            switch body {
            case .string(let jsonString):
                payloadData = jsonString.data(using: .utf8)
            case .dictionary:
                payloadData = try? JSONSerialization.data(withJSONObject: body.rawValue)
            default:
                payloadData = nil
            }
        } else {
            // Maybe the outer data IS the GitHub payload directly
            payloadData = outerData
        }

        guard let payloadData else { return nil }

        struct GitHubWebhookPayload: Decodable {
            let action: String?
            let workflowRun: WorkflowRun?
            let repository: Repository?

            struct Repository: Decodable {
                let fullName: String
                enum CodingKeys: String, CodingKey {
                    case fullName = "full_name"
                }
            }

            enum CodingKeys: String, CodingKey {
                case action
                case workflowRun = "workflow_run"
                case repository
            }
        }

        guard let payload = try? decoder.decode(GitHubWebhookPayload.self, from: payloadData),
              let workflowRun = payload.workflowRun,
              let repoName = payload.repository?.fullName else {
            return nil
        }

        return WebhookEvent(
            action: payload.action ?? "unknown",
            workflowRun: workflowRun,
            repositoryFullName: repoName
        )
    }
}

// MARK: - SSE Delegate (streams data incrementally)

/// URLSession delegate that receives data chunks incrementally and produces lines via an AsyncStream.
private final class SSEDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private var continuation: AsyncStream<String>.Continuation?
    private var buffer = ""
    private(set) var error: Error?

    // SSE parser state
    private var currentEventType: String?
    private var dataLines: [String] = []

    lazy var lines: AsyncStream<String> = {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }()

    /// Feed a line into the SSE parser. Returns (eventType, data) when a complete event is ready.
    func feedLine(_ line: String) -> (String?, String)? {
        if line.hasPrefix(":") {
            return nil
        } else if line.hasPrefix("event:") {
            currentEventType = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            return nil
        } else if line.hasPrefix("data:") {
            dataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
            return nil
        } else if line.isEmpty {
            if !dataLines.isEmpty {
                let result = (currentEventType, dataLines.joined(separator: "\n"))
                currentEventType = nil
                dataLines = []
                return result
            }
            currentEventType = nil
            dataLines = []
            return nil
        }
        return nil
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let http = response as? HTTPURLResponse {
            smeeLog("[Smee] Delegate got HTTP \(http.statusCode)")
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let chunk = String(data: data, encoding: .utf8) else { return }
        buffer += chunk

        // Split buffer into complete lines
        while let newlineRange = buffer.rangeOfCharacter(from: .newlines) {
            let line = String(buffer[buffer.startIndex..<newlineRange.lowerBound])
            buffer = String(buffer[newlineRange.upperBound...])
            continuation?.yield(line)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            smeeLog("[Smee] Delegate error: \(error)")
            self.error = error
        } else {
            smeeLog("[Smee] Delegate completed normally")
        }
        continuation?.finish()
    }
}

// MARK: - Helper Types

enum SmeeError: LocalizedError, Sendable {
    case channelCreationFailed
    case invalidURL
    case connectionFailed

    var errorDescription: String? {
        switch self {
        case .channelCreationFailed:
            "Failed to create Smee channel."
        case .invalidURL:
            "Invalid Smee URL."
        case .connectionFailed:
            "Failed to connect to Smee."
        }
    }
}

/// A simple any-JSON type for decoding the Smee wrapper's body field.
enum AnyCodable: Decodable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case dictionary([String: AnyCodable])
    case array([AnyCodable])
    case null

    var rawValue: Any {
        switch self {
        case .string(let v): return v
        case .int(let v): return v
        case .double(let v): return v
        case .bool(let v): return v
        case .dictionary(let v): return v.mapValues { $0.rawValue }
        case .array(let v): return v.map { $0.rawValue }
        case .null: return NSNull()
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(String.self) { self = .string(v) }
        else if let v = try? container.decode(Int.self) { self = .int(v) }
        else if let v = try? container.decode(Double.self) { self = .double(v) }
        else if let v = try? container.decode(Bool.self) { self = .bool(v) }
        else if let v = try? container.decode([String: AnyCodable].self) { self = .dictionary(v) }
        else if let v = try? container.decode([AnyCodable].self) { self = .array(v) }
        else if container.decodeNil() { self = .null }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type") }
    }
}

/// URLSession delegate that prevents following redirects.
private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

private let smeeLogURL: URL = {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent("actionbar-smee.log")
    FileManager.default.createFile(atPath: path.path, contents: nil)
    return path
}()

func smeeLog(_ message: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = "[\(timestamp)] \(message)\n"
    if let handle = try? FileHandle(forWritingTo: smeeLogURL) {
        handle.seekToEndOfFile()
        handle.write(Data(line.utf8))
        handle.closeFile()
    }
}
