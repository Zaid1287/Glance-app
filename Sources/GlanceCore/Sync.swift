import Foundation

/// The wire message. Versioned so the phone and agent can evolve independently.
/// In production this payload is what gets end-to-end encrypted before it leaves
/// the Mac (N3) — only task metadata, never file contents or command output.
public struct TaskEnvelope: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable {
        case update     // task created or changed
        case remove     // task dropped from history
        case heartbeat  // liveness / Mac-awake ping
    }

    public static let protocolVersion = 1

    public let v: Int
    public let kind: Kind
    public let task: TrackedTask?
    public let sentAt: Date

    public init(v: Int = TaskEnvelope.protocolVersion, kind: Kind, task: TrackedTask?, sentAt: Date) {
        self.v = v
        self.kind = kind
        self.task = task
        self.sentAt = sentAt
    }

    public static func update(_ task: TrackedTask, now: Date = Date()) -> TaskEnvelope {
        TaskEnvelope(kind: .update, task: task, sentAt: now)
    }

    public static func heartbeat(now: Date = Date()) -> TaskEnvelope {
        TaskEnvelope(kind: .heartbeat, task: nil, sentAt: now)
    }
}

/// JSON framing. Default date strategy (Double since reference date) round-trips
/// exactly, so envelopes survive encode→decode unchanged. Newline-delimited for
/// streaming over a socket.
public enum WireCodec {
    public static func encode(_ e: TaskEnvelope) -> Data {
        (try? JSONEncoder().encode(e)) ?? Data()
    }

    public static func decode(_ data: Data) -> TaskEnvelope? {
        try? JSONDecoder().decode(TaskEnvelope.self, from: data)
    }

    /// One envelope + "\n", for line-framed transports.
    public static func encodeLine(_ e: TaskEnvelope) -> Data {
        var d = encode(e)
        d.append(0x0A)
        return d
    }
}

/// Anything that can ship an envelope toward a peer (TCP, MultipeerConnectivity,
/// or a push relay). Publisher only depends on this — the transport is swappable.
public protocol OutboundTransport: AnyObject {
    func send(_ envelope: TaskEnvelope)
}

/// Anything that surfaces envelopes arriving from a peer.
public protocol InboundTransport: AnyObject {
    var onReceive: ((TaskEnvelope) -> Void)? { get set }
}

/// Rate-limits per-task updates to respect Live Activity push budgets (N5).
/// State changes and terminal states always flush immediately so completion is
/// never delayed or dropped (N7); steady progress is throttled to `minInterval`.
public final class SyncCoalescer {
    public let minInterval: TimeInterval
    private var lastSentAt: [String: Date] = [:]
    private var lastState: [String: TaskState] = [:]

    public init(minInterval: TimeInterval = 1.0) {
        self.minInterval = minInterval
    }

    public func shouldSend(_ task: TrackedTask, now: Date = Date()) -> Bool {
        let stateChanged = lastState[task.id] != task.state
        let due = lastSentAt[task.id].map { now.timeIntervalSince($0) >= minInterval } ?? true
        guard stateChanged || task.state.isTerminal || due else { return false }
        lastSentAt[task.id] = now
        lastState[task.id] = task.state
        return true
    }
}

/// Subscribes to local task updates and ships them through a transport, coalesced.
/// Wire this as the `TaskStore.onUpdate` sink to put the agent on the wire.
public final class SyncPublisher {
    private let transport: OutboundTransport
    private let coalescer: SyncCoalescer

    public init(transport: OutboundTransport, coalescer: SyncCoalescer = SyncCoalescer()) {
        self.transport = transport
        self.coalescer = coalescer
    }

    public func publish(_ task: TrackedTask, now: Date = Date()) {
        guard coalescer.shouldSend(task, now: now) else { return }
        transport.send(.update(task, now: now))
    }
}

/// The peer side (stands in for the phone): rebuilds a task view from envelopes.
public final class SyncSubscriber {
    private let queue = DispatchQueue(label: "com.glance.subscriber")
    private var tasks: [String: TrackedTask] = [:]
    public var onChange: ((TaskEnvelope) -> Void)?

    public init() {}

    public func ingest(_ envelope: TaskEnvelope) {
        queue.sync {
            switch envelope.kind {
            case .update:
                if let t = envelope.task { tasks[t.id] = t }
            case .remove:
                if let t = envelope.task { tasks[t.id] = nil }
            case .heartbeat:
                break
            }
        }
        onChange?(envelope)
    }

    public func task(id: String) -> TrackedTask? { queue.sync { tasks[id] } }
    public var snapshot: [TrackedTask] { queue.sync { Array(tasks.values) } }
    public var activeTasks: [TrackedTask] { queue.sync { tasks.values.filter { !$0.state.isTerminal } } }
}

/// In-process transport for tests: `send` delivers straight to `onReceive`.
public final class LoopbackTransport: OutboundTransport, InboundTransport {
    public var onReceive: ((TaskEnvelope) -> Void)?
    public init() {}
    public func send(_ envelope: TaskEnvelope) {
        // Round-trip through the codec so tests exercise real serialization.
        if let decoded = WireCodec.decode(WireCodec.encode(envelope)) {
            onReceive?(decoded)
        }
    }
}
