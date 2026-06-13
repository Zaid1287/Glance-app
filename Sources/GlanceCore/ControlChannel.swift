#if canImport(Network)
import Foundation
import Network

/// Local control channel: lets short-lived `glance` commands (`run`, `watch`,
/// `attach`) inject their task updates into a running Glance agent (menu-bar app
/// or `sync-serve`) so those tasks reach the phone too — and, because they carry
/// a real progress fraction, fill the progress bar.
///
/// Loopback-only and encrypted with the same pairing key. Newline-framed
/// `SecureCodec` envelopes, same as the sync transports.

private let controlMaxBuffer = 1 << 20

/// Agent side: accepts local injectors and surfaces their envelopes.
public final class ControlServer {
    public enum ServerError: Error { case invalidPort }

    private let listener: NWListener
    private let codec: SecureCodec
    private let queue = DispatchQueue(label: "com.glance.control.server")
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private var buffers: [ObjectIdentifier: Data] = [:]

    public var onReceive: ((TaskEnvelope) -> Void)?

    public init(port: UInt16, codec: SecureCodec) throws {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { throw ServerError.invalidPort }
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        params.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: nwPort)  // loopback only
        listener = try NWListener(using: params)
        self.codec = codec
    }

    public func start() {
        listener.newConnectionHandler = { [weak self] conn in
            guard let self else { return }
            let id = ObjectIdentifier(conn)
            self.queue.async { self.connections[id] = conn; self.buffers[id] = Data() }
            conn.stateUpdateHandler = { [weak self] state in
                switch state {
                case .failed, .cancelled:
                    self?.queue.async { self?.connections[id] = nil; self?.buffers[id] = nil }
                default: break
                }
            }
            conn.start(queue: self.queue)
            self.receive(conn, id)
        }
        listener.start(queue: queue)
    }

    public func stop() {
        listener.cancel()
        queue.async { self.connections.values.forEach { $0.cancel() }; self.connections.removeAll() }
    }

    private func receive(_ conn: NWConnection, _ id: ObjectIdentifier) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.queue.async {
                    var buf = self.buffers[id] ?? Data()
                    buf.append(data)
                    if buf.count > controlMaxBuffer { buf.removeAll(); conn.cancel(); return }
                    while let nl = buf.firstIndex(of: 0x0A) {
                        let frame = Data(buf[buf.startIndex..<nl])
                        buf.removeSubrange(buf.startIndex...nl)
                        if let env = self.codec.open(frame) { self.onReceive?(env) }
                    }
                    self.buffers[id] = buf
                }
            }
            if isComplete || error != nil { return }
            self.receive(conn, id)
        }
    }
}

/// Command side: connects to a running agent and forwards task updates.
public final class ControlClient {
    public enum ClientError: Error { case invalidPort }

    private let connection: NWConnection
    private let codec: SecureCodec
    private let queue = DispatchQueue(label: "com.glance.control.client")

    public init(host: String = "127.0.0.1", port: UInt16, codec: SecureCodec) throws {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { throw ClientError.invalidPort }
        connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
        self.codec = codec
    }

    public func start() { connection.start(queue: queue) }
    public func stop() { connection.cancel() }

    public func send(_ envelope: TaskEnvelope) {
        let data = codec.seal(envelope)
        guard !data.isEmpty else { return }
        connection.send(content: data, completion: .contentProcessed { _ in })
    }
}

public let glanceControlPort: UInt16 = 7788
#endif
