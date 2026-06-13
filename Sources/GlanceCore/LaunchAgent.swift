import Foundation

/// Generates the `launchd` plist that keeps the agent running across logins
/// (F-table persistence). Pure string generation so it's unit-testable; the
/// actual file write + `launchctl load` lives in the menu-bar executable.
public enum LaunchAgent {
    public static let defaultLabel = "com.glance.agent"

    public static func installURL(label: String = defaultLabel) -> URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    public static func plistXML(
        label: String = defaultLabel,
        programArguments: [String],
        runAtLoad: Bool = true,
        keepAlive: Bool = true
    ) -> String {
        let args = programArguments
            .map { "        <string>\($0.xmlEscaped)</string>" }
            .joined(separator: "\n")
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label.xmlEscaped)</string>
            <key>ProgramArguments</key>
            <array>
        \(args)
            </array>
            <key>RunAtLoad</key>
            <\(runAtLoad ? "true" : "false")/>
            <key>KeepAlive</key>
            <\(keepAlive ? "true" : "false")/>
            <key>ProcessType</key>
            <string>Background</string>
        </dict>
        </plist>
        """
    }
}

extension String {
    /// Minimal XML escaping for plist string values.
    var xmlEscaped: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
