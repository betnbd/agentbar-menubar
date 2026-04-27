import Foundation

public enum TrayAutoRefreshPolicy {
    public static let environmentKey = "AGENTBAR_REFRESH_SECONDS"
    public static let defaultInterval: TimeInterval = 60
    public static let minimumInterval: TimeInterval = 15

    public static func interval(environment: [String: String] = ProcessInfo.processInfo.environment) -> TimeInterval {
        guard let rawValue = environment[self.environmentKey],
              let interval = TimeInterval(rawValue),
              interval >= self.minimumInterval
        else {
            return self.defaultInterval
        }

        return interval
    }
}
