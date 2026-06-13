import Foundation
import Network

/// Localhost/LAN TCP transport. Verifiable stand-in for the spec's LAN fast-path:
/// same `OutboundTransport`/`InboundTransport` seam, so swapping in
/// MultipeerConnectivity or a push relay later touches only this file.
///
/// Security posture (public-release defaults):
///  - Every frame is AEAD-encrypted via `SecureCodec` — no plaintext on the wire.
///  - The server binds to **loopback only** unless `lanExposed` is opted in.
///  - Inbound framing is capped to prevent unbounded-buffer DoS.

private let maxInboundBuffer = 1 << 20  // 1 MB hard cap per connection

/// Agent side: accepts paired subscribers and broadcasts every (encrypted) envelope.
public final class TCPServer: OutboundTransport {
    public enum ServerError: Error { case invalidPort }

    private let listener: NWListener
    private let codec: SecureCodec
    private let queue = DispatchQueue(label: "com.glance.tcp.server")
    private var connections: [ObjectIdentifier: NWConnection] = [:]

    /// - Parameters:
    ///   - lanExposed: when false (default) the listener binds to 127.0.0.1 only,
    ///     so nothing off-box can connect even though frames are encrypted.
    public init(port: UInt16, codec: SecureCodec, lanExposed: Bool = false) throws {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { throw ServerError.invalidPort }
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        self.codec = codec
        if lanExposed {
            listener = try NWListener(using: params, on: nwPort)
        } else {
            params.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: nwPort)
            listener = try NWListener(using: params)
        }
    }

    public func start() {
        listener.newConnectionHandler = { [weak self] conn in
            guard let self else { return }
            self.queue.async { self.connections[ObjectIdentifier(conn)] = conn }
            conn.stateUpdateHandler = { [weak self] state in
                switch state {
                case .failed, .cancelled:
                    self?.queue.async { self?.connections[ObjectIdentifier(conn)] = nil }
                default:
                    break
                }
            }
            conn.start(queue: self.queue)
        }
        listener.start(queue: queue)
    }

    public func stop() {
        listener.cancel()
        queue.async {
            self.connections.values.forEach { $0.cancel() }
            self.connections.removeAll()
        }
    }

    public func send(_ envelope: TaskEnvelope) {
        let data = codec.seal(envelope)
        guard !data.isEmpty else { return }
        queue.async {
            for conn in self.connections.values {
                conn.send(content: data, completion: .contentProcessed { _ in })
            }
        }
    }
}

/// Subscriber side: connects to the agent and surfaces decrypted envelopes.
/// Re-assembles the newline-framed stream across packet boundaries, dropping the
/// connection if a single frame ever exceeds the buffer cap.
public final class TCPClient: InboundTransport {
    public enum ClientError: Error { case invalidPort }

    public var onReceive: ((TaskEnvelope) -> Void)?
    private let connection: NWConnection
    private let codec: SecureCodec
    private let queue = DispatchQueue(label: "com.glance.tcp.client")
    private var buffer = Data()

    public init(host: String, port: UInt16, codec: SecureCodec) throws {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { throw ClientError.invalidPort }
        connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
        self.codec = codec
    }

    public func start() {
        connection.start(queue: queue)
        receiveLoop()
    }

    public func stop() {
        connection.cancel()
    }

    private func receiveLoop() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.buffer.append(data)
                if self.buffer.count > maxInboundBuffer {
                    // A peer streaming with no delimiter — refuse to grow unbounded.
                    self.buffer.removeAll(keepingCapacity: false)
                    self.connection.cancel()
                    return
                }
                self.drainLines()
            }
            if isComplete || error != nil { return }
            self.receiveLoop()
        }
    }

    private func drainLines() {
        while let nl = buffer.firstIndex(of: 0x0A) {
            let frame = Data(buffer[buffer.startIndex..<nl])
            buffer.removeSubrange(buffer.startIndex...nl)
            if let env = codec.open(frame) { onReceive?(env) }
        }
    }
}
