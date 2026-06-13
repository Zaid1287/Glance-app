import Foundation
import GlanceCore

// Unbuffered stdout: long-lived watchers are killed with a signal, so block
// buffering would lose updates that never get flushed. Also keeps `--json`
// pipeable line-by-line.
setvbuf(stdout, nil, _IONBF, 0)

let version = "0.1.0"

func usage() {
    print("""
    glance \(version) — track long-running Mac tasks

    USAGE:
      glance watch-downloads [--dir PATH] [--json]   Auto-detect browser downloads
      glance watch-processes [--json]                Auto-detect builds/installs/transfers
      glance run [--name N] [--progress RE] -- CMD   Wrap a command, report exit + progress
      glance attach --pid PID [--json]               Watch an existing process
      glance watch --file PATH [--size BYTES] [--json]  Watch a file grow
      glance sync-serve [--port N] [--key PATH] [--lan]  Auto-detect + publish (encrypted; loopback unless --lan)
      glance sync-listen [--host H] [--port N] [--key PATH] [--json]  Receive updates (phone stand-in)
      glance version

    EXAMPLES:
      glance watch-downloads
      glance run --progress 'Epoch.*?([0-9]+)%' -- python train.py
      glance attach --pid 4213
      glance watch --file ~/render.mov --size 524288000
    """)
}

/// Build the local sink + store. `--json` emits one JSON object per update;
/// otherwise a human status line.
func makeStore(json: Bool) -> TaskStore {
    // If a Glance agent (menu-bar app / sync-serve) is running locally, forward
    // task updates to it so this command's task reaches the phone too — and,
    // for `run --progress`, carries a real % that fills the phone's bar.
    var forwarder: ControlClient?
    if let key = try? GlanceCrypto.loadKey(at: GlanceCrypto.defaultKeyURL()) {
        forwarder = try? ControlClient(port: glanceControlPort, codec: SecureCodec(key: key))
        forwarder?.start()
    }
    return TaskStore(stallAfter: 120) { task in
        print(json ? TaskFormatter.json(for: task) : TaskFormatter.line(for: task))
        forwarder?.send(.update(task))
    }
}

func optionValue(_ name: String, in args: [String]) -> String? {
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
    return args[i + 1]
}

/// Keep a periodic stall check running while a long-lived watcher is active.
func startStallTimer(_ store: TaskStore) {
    let timer = Timer(timeInterval: 15, repeats: true) { _ in store.checkStalls() }
    RunLoop.main.add(timer, forMode: .common)
}

let args = Array(CommandLine.arguments.dropFirst())
guard let command = args.first else { usage(); exit(0) }
let rest = Array(args.dropFirst())
let json = rest.contains("--json")

switch command {
case "version", "--version", "-v":
    print("glance \(version)")

case "help", "--help", "-h":
    usage()

case "watch-downloads":
    let dir = optionValue("--dir", in: rest).map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
    let store = makeStore(json: json)
    let detector = DownloadsDetector(directory: dir, store: store)
    detector.start()
    FileHandle.standardError.write(Data("glance: watching downloads — Ctrl-C to stop\n".utf8))
    startStallTimer(store)
    RunLoop.main.run()

case "watch-processes":
    let store = makeStore(json: json)
    let detector = ProcessDetector(store: store)
    detector.start()
    FileHandle.standardError.write(Data("glance: watching processes (builds/installs/transfers) — Ctrl-C to stop\n".utf8))
    startStallTimer(store)
    RunLoop.main.run()

case "sync-serve":
    let port = UInt16(optionValue("--port", in: rest) ?? "7777") ?? 7777
    let keyURL = optionValue("--key", in: rest)
        .map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) } ?? GlanceCrypto.defaultKeyURL()
    let lan = rest.contains("--lan")
    do {
        let key = try GlanceCrypto.loadOrCreateKey(at: keyURL)
        let codec = SecureCodec(key: key)
        // Two transports: MultipeerConnectivity (what the iPhone app browses for,
        // zero-config LAN) and TCP (the verifiable/scriptable fallback).
        let advertiser = MultipeerAdvertiser(displayName: Host.current().localizedName ?? "Mac", codec: codec)
        advertiser.start()
        let server = try TCPServer(port: port, codec: codec, lanExposed: lan)
        server.start()
        let mpcPub = SyncPublisher(transport: advertiser)
        let tcpPub = SyncPublisher(transport: server)
        let store = TaskStore(stallAfter: 120) { task in
            mpcPub.publish(task)
            tcpPub.publish(task)
            print(TaskFormatter.line(for: task))   // local echo
        }
        let control = try? ControlServer(port: glanceControlPort, codec: codec)
        control?.onReceive = { env in if let t = env.task { store.upsert(t) } }
        control?.start()
        advertiser.snapshotProvider = {
            let active = store.activeTasks
            let recent = store.allTasks.filter { $0.state.isTerminal }
                .sorted { ($0.finishedAt ?? .distantPast) > ($1.finishedAt ?? .distantPast) }.prefix(10)
            return active + Array(recent)
        }
        let detectors: [Detector] = [DownloadsDetector(store: store), ProcessDetector(store: store)]
        detectors.forEach { $0.start() }
        startStallTimer(store)
        let scope = lan ? "LAN (all interfaces)" : "loopback only"
        FileHandle.standardError.write(Data("""
        glance: serving encrypted task updates — MultipeerConnectivity (LAN) + tcp/\(port) (\(scope))
          key: \(keyURL.path)  ·  fingerprint: \(GlanceCrypto.fingerprint(key))
          (macOS may ask to allow Local Network access — allow it for the phone to connect)
          Ctrl-C to stop

        """.utf8))
        withExtendedLifetime((advertiser, server, control as Any, mpcPub, tcpPub, store, detectors)) {
            RunLoop.main.run()
        }
    } catch {
        FileHandle.standardError.write(Data("glance sync-serve: \(error)\n".utf8))
        exit(2)
    }

case "sync-listen":
    let host = optionValue("--host", in: rest) ?? "127.0.0.1"
    let port = UInt16(optionValue("--port", in: rest) ?? "7777") ?? 7777
    let keyURL = optionValue("--key", in: rest)
        .map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) } ?? GlanceCrypto.defaultKeyURL()
    do {
        let key = try GlanceCrypto.loadKey(at: keyURL)
        let codec = SecureCodec(key: key)
        let subscriber = SyncSubscriber()
        subscriber.onChange = { envelope in
            guard let t = envelope.task else { return }
            print(json ? TaskFormatter.json(for: t) : TaskFormatter.line(for: t))
        }
        let client = try TCPClient(host: host, port: port, codec: codec)
        client.onReceive = { subscriber.ingest($0) }
        client.start()
        FileHandle.standardError.write(Data("glance: listening (encrypted) to tcp/\(host):\(port) — fingerprint: \(GlanceCrypto.fingerprint(key)) — Ctrl-C to stop\n".utf8))
        withExtendedLifetime((subscriber, client)) {
            RunLoop.main.run()
        }
    } catch {
        FileHandle.standardError.write(Data("glance sync-listen: no usable key at \(keyURL.path) — run `glance sync-serve` once to create one, then share it to the peer. (\(error))\n".utf8))
        exit(2)
    }

case "run":
    guard let sep = rest.firstIndex(of: "--"), sep + 1 < rest.count else {
        FileHandle.standardError.write(Data("glance run: missing `-- CMD`\n".utf8))
        exit(2)
    }
    let cmd = Array(rest[(sep + 1)...])
    let name = optionValue("--name", in: rest)
    let pattern = optionValue("--progress", in: rest)
    let store = makeStore(json: json)
    do {
        let runner = try CommandRunner(command: cmd, name: name, progressPattern: pattern)
        let final = runner.run(store: store)
        exit(final.exitCode ?? 0)
    } catch {
        FileHandle.standardError.write(Data("glance run: \(error)\n".utf8))
        exit(2)
    }

case "attach":
    guard let pidStr = optionValue("--pid", in: rest), let pid = pid_t(pidStr) else {
        FileHandle.standardError.write(Data("glance attach: need --pid PID\n".utf8))
        exit(2)
    }
    let store = makeStore(json: json)
    let watcher = ProcessWatcher(pid: pid, store: store)
    watcher.start()
    if store.activeTasks.isEmpty { exit(0) } // already exited
    RunLoop.main.run()

case "watch":
    guard let file = optionValue("--file", in: rest) else {
        FileHandle.standardError.write(Data("glance watch: need --file PATH\n".utf8))
        exit(2)
    }
    let url = URL(fileURLWithPath: (file as NSString).expandingTildeInPath)
    let target = optionValue("--size", in: rest).flatMap { Int64($0) }
    let store = makeStore(json: json)
    let watcher = FileGrowthWatcher(url: url, target: target, store: store)
    watcher.start()
    startStallTimer(store)
    RunLoop.main.run()

default:
    FileHandle.standardError.write(Data("glance: unknown command '\(command)'\n".utf8))
    usage()
    exit(2)
}
