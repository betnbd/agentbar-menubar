import Foundation

public enum AppIdentity {
    public static let productName = "AgentBar"
    public static let bundleIdentifier = "com.agentbar.app"
    public static let debugBundleIdentifier = "com.agentbar.app.debug"
    public static let osLogSubsystem = "com.agentbar.app"
    public static let configDirectoryName = ".agentbar"
    public static let applicationSupportDirectoryName = "agentbar"
    public static let historyDirectoryName = "history"
    public static let sharedDefaultsMigrationKeyPrefix = "agentbar"
    public static let keychainCacheService = "com.agentbar.app.cache"
    public static let legacyDisplayName = "AgentBar"

    public static var appHomeURL: URL? {
        nil
    }

    public static var supportURL: URL? {
        nil
    }
}
