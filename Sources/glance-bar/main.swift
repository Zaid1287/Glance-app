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

        store = TaskStore(stallAfter: 120) { [weak self] _ in
            DispatchQueue.main.async { self?.rebuildMenu() }
        }
        detectors = [DownloadsDetector(store: store), ProcessDetector(store: store)]
        detectors.forEach { $0.start() }
        stallTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.store.checkStalls()
        }
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let active = store.activeTasks.sorted { $0.createdAt < $1.createdAt }
        let recent = store.allTasks
            .filter { $0.state.isTerminal }
            .sorted { ($0.finishedAt ?? .distantPast) > ($1.finishedAt ?? .distantPast) }
            .prefix(5)

        if let button = statusItem.button {
            button.title = active.isEmpty ? "" : " \(active.count)"
        }

        if active.isEmpty {
            menu.addItem(disabled("No active tasks"))
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
        let quit = NSMenuItem(title: "Quit Glance", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
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
