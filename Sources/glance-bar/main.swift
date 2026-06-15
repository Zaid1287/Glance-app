import AppKit
import GlanceCore

// Glance menu-bar agent. Runs as an accessory app (no Dock icon), auto-detects
// tasks, and shows them live in the status menu. The same `TaskStore` that feeds
// this menu also feeds the sync layer — the GUI is just another subscriber.

final class GlanceBarController: NSObject {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private var store: TaskStore!
    private var detectors: [Detector] = []
    private var stallTimer: Timer?
    private var advertiser: MultipeerAdvertiser?
    private var server: TCPServer?
    private var control: ControlServer?
    private var publishers: [SyncPublisher] = []
    private var keyFingerprint: String?

    func start() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let img = NSImage(systemSymbolName: "gauge.with.dots.needle.bottom.50percent",
                             accessibilityDescription: "Glance") {
            img.isTemplate = true
            statusItem.button?.image = img
        } else {
            statusItem.button?.title = "Glance"
        }
        statusItem.menu = menu

        store = TaskStore(stallAfter: 120) { [weak self] task in
            guard let self else { return }
            self.publishers.forEach { $0.publish(task) }
            DispatchQueue.main.async { self.rebuildMenu() }
        }

        // The menu-bar app IS the agent (Ollama-style): detect tasks, advertise
        // over the LAN, hold the pairing key — no Terminal needed.
        if let key = try? GlanceCrypto.loadOrCreateKey(at: GlanceCrypto.defaultKeyURL()) {
            keyFingerprint = GlanceCrypto.fingerprint(key)
            let codec = SecureCodec(key: key)
            let adv = MultipeerAdvertiser(displayName: Host.current().localizedName ?? "Mac", codec: codec)
            adv.start()
            advertiser = adv
            adv.snapshotProvider = { [weak self] in self?.snapshotTasks() ?? [] }
            publishers.append(SyncPublisher(transport: adv))
            if let srv = try? TCPServer(port: 7777, codec: codec, lanExposed: false) {
                srv.start()
                server = srv
                publishers.append(SyncPublisher(transport: srv))
            }
            // Accept local task injection from `glance run`/`watch`/`attach`
            // (their tasks carry a real % → fills the phone's progress bar).
            if let ctl = try? ControlServer(port: glanceControlPort, codec: codec) {
                ctl.onReceive = { [weak self] env in
                    guard let self, let t = env.task else { return }
                    self.store.upsert(t)
                }
                ctl.start()
                control = ctl
            }
        }

        detectors = [DownloadsDetector(store: store), ProcessDetector(store: store)]
        detectors.forEach { $0.start() }
        stallTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.store.checkStalls()
        }
        rebuildMenu()
    }

    /// Active tasks + the few most-recent finished ones, replayed to a freshly
    /// connected phone so it never stays stuck on a stale state.
    private func snapshotTasks() -> [TrackedTask] {
        let active = store.activeTasks
        let recent = store.allTasks
            .filter { $0.state.isTerminal }
            .sorted { ($0.finishedAt ?? .distantPast) > ($1.finishedAt ?? .distantPast) }
            .prefix(10)
        return active + Array(recent)
    }

    /// Minimal layout: lead with what the app is *for* (running tasks), keep a few
    /// recent finishes, and tuck pairing into a submenu so it isn't shouting on
    /// every open.
    private func rebuildMenu() {
        menu.removeAllItems()

        let active = store.activeTasks.sorted { $0.createdAt < $1.createdAt }
        let recent = store.allTasks
            .filter { $0.state.isTerminal }
            .sorted { ($0.finishedAt ?? .distantPast) > ($1.finishedAt ?? .distantPast) }
            .prefix(3)

        if let button = statusItem.button {
            button.title = active.isEmpty ? "" : " \(active.count)"
        }

        if active.isEmpty {
            menu.addItem(disabled("Nothing running"))
        } else {
            menu.addItem(header("Active"))
            active.forEach { menu.addItem(taskItem($0)) }
        }

        if !recent.isEmpty {
            menu.addItem(.separator())
            menu.addItem(header("Recent"))
            recent.forEach { menu.addItem(taskItem($0)) }
        }

        menu.addItem(.separator())

        if let fp = keyFingerprint {
            let pairing = NSMenuItem(title: "Pairing", action: nil, keyEquivalent: "")
            let sub = NSMenu()
            sub.addItem(disabled("Key fingerprint: \(fp)"))
            let copy = NSMenuItem(title: "Copy pairing key", action: #selector(copyPairingKey), keyEquivalent: "c")
            copy.target = self
            sub.addItem(copy)
            pairing.submenu = sub
            menu.addItem(pairing)
        }

        let quit = NSMenuItem(title: "Quit Glance", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    @objc private func copyPairingKey() {
        guard let data = try? Data(contentsOf: GlanceCrypto.defaultKeyURL()),
              let key = String(data: data, encoding: .utf8) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(key.trimmingCharacters(in: .whitespacesAndNewlines), forType: .string)
    }

    private func header(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title.uppercased(), action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.attributedTitle = NSAttributedString(
            string: title.uppercased(),
            attributes: [
                .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
                .foregroundColor: NSColor.secondaryLabelColor,
            ])
        return item
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func taskItem(_ task: TrackedTask) -> NSMenuItem {
        let item = NSMenuItem(title: TaskFormatter.line(for: task), action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }
}

// MARK: - LaunchAgent install/uninstall

func resolvedBinaryPath() -> String {
    URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath().path
}

func installLaunchAgent() {
    let url = LaunchAgent.installURL()
    let xml = LaunchAgent.plistXML(programArguments: [resolvedBinaryPath()])
    do {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try xml.write(to: url, atomically: true, encoding: .utf8)
        runLaunchctl(["load", "-w", url.path])
        print("Installed LaunchAgent at \(url.path)")
    } catch {
        FileHandle.standardError.write(Data("install failed: \(error)\n".utf8))
        exit(1)
    }
}

func uninstallLaunchAgent() {
    let url = LaunchAgent.installURL()
    runLaunchctl(["unload", "-w", url.path])
    try? FileManager.default.removeItem(at: url)
    print("Removed LaunchAgent at \(url.path)")
}

func runLaunchctl(_ args: [String]) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    p.arguments = args
    try? p.run()
    p.waitUntilExit()
}

// MARK: - Entry

let args = Array(CommandLine.arguments.dropFirst())
if args.contains("--install-agent") { installLaunchAgent(); exit(0) }
if args.contains("--uninstall-agent") { uninstallLaunchAgent(); exit(0) }

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // menu-bar only, no Dock icon
let controller = GlanceBarController()
controller.start()
app.run()
