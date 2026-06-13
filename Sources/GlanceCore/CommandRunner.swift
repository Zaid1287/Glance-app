#if os(macOS)
import Foundation

/// Wraps an arbitrary command (`glance run -- python train.py`) and reports
/// start, progress (optional stdout regex), exit code, and duration. This is the
/// always-works escape hatch for tasks auto-detection can't see.
///
/// Only metadata is recorded — captured lines are parsed for a progress number
/// and then discarded; command output is never stored or synced (N3).
public final class CommandRunner {
    public enum RunnerError: Error { case emptyCommand, badRegex }

    private let command: [String]
    private let name: String
    private let progressRegex: NSRegularExpression?
    private let parseQueue = DispatchQueue(label: "com.glance.runner.parse")

    /// - Parameters:
    ///   - command: argv to run, e.g. ["python", "train.py"].
    ///   - name: display name; defaults to the executable.
    ///   - progressPattern: regex whose first capture group is a number. Values
    ///     in 0...100 are treated as a percent.
    public init(command: [String], name: String? = nil, progressPattern: String? = nil) throws {
        guard let first = command.first, !first.isEmpty else { throw RunnerError.emptyCommand }
        self.command = command
        self.name = name ?? first
        if let p = progressPattern {
            guard let re = try? NSRegularExpression(pattern: p) else { throw RunnerError.badRegex }
            self.progressRegex = re
        } else {
            self.progressRegex = nil
        }
    }

    /// Run to completion (blocking) and return the final task. Updates stream to
    /// `store` as the command runs.
    @discardableResult
    public func run(store: TaskStore) -> TrackedTask {
        var task = TrackedTask(
            kind: .command,
            name: name,
            state: .running,
            detail: command.joined(separator: " ")
        )
        let id = task.id
        store.upsert(task)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        var buffer = Data()
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            self?.parseQueue.async {
                buffer.append(chunk)
                while let nl = buffer.firstIndex(of: 0x0A) {
                    let lineData = buffer[buffer.startIndex..<nl]
                    buffer.removeSubrange(buffer.startIndex...nl)
                    guard let line = String(data: lineData, encoding: .utf8) else { continue }
                    self?.applyProgress(line: line, taskId: id, store: store)
                }
            }
        }

        do {
            try process.run()
        } catch {
            task.state = .failed
            task.finishedAt = Date()
            task.detail = "failed to launch: \(error.localizedDescription)"
            return store.upsert(task)
        }

        process.waitUntilExit()
        pipe.fileHandleForReading.readabilityHandler = nil
        parseQueue.sync {} // drain any in-flight parsing

        var finished = store.task(id: id) ?? task
        finished.exitCode = process.terminationStatus
        finished.finishedAt = Date()
        finished.state = process.terminationStatus == 0 ? .done : .failed
        finished.detail = "exit \(process.terminationStatus)"
        return store.upsert(finished)
    }

    /// Parse one line for a progress number and push an update if found.
    public func applyProgress(line: String, taskId: String, store: TaskStore) {
        guard let re = progressRegex else { return }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let m = re.firstMatch(in: line, range: range), m.numberOfRanges >= 2,
              let r = Range(m.range(at: 1), in: line),
              let value = Double(line[r]) else { return }

        guard var task = store.task(id: taskId) else { return }
        if value >= 0, value <= 100 {
            task.progress.completedUnitCount = Int64(value)
            task.progress.totalUnitCount = 100
        }
        store.upsert(task)
    }
}
#endif
