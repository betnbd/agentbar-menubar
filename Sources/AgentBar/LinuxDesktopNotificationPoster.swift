import AgentBarCore
import Foundation

struct LinuxDesktopNotificationPoster: NotificationPosting {
    func requestAuthorizationIfNeeded() async -> Bool {
        self.notifySendURL != nil
    }

    func post(idPrefix _: String, title: String, body: String, badge _: NSNumber?) async {
        guard let notifySendURL else { return }

        let process = Process()
        process.executableURL = notifySendURL
        process.arguments = [title, body]
        try? process.run()
    }

    private var notifySendURL: URL? {
        let path = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/usr/local/bin"
        for directory in path.split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(directory)).appendingPathComponent("notify-send")
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }
}
