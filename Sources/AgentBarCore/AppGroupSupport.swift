import Foundation

public enum AppGroupSupport {
    public static let defaultTeamID = "linux"
    public static let teamIDInfoKey = "AgentBarTeamID"
    public static let legacyReleaseGroupID = "agentbar"
    public static let legacyDebugGroupID = "agentbar.debug"
    public static let widgetSnapshotFilename = "widget-snapshot.json"
    public static let migrationVersion = 1
    public static let migrationVersionKey = "appGroupMigrationVersion"

    public struct MigrationResult: Sendable {
        public enum Status: String, Sendable {
            case alreadyCompleted
            case targetUnavailable
            case noChangesNeeded
            case migrated
        }

        public let status: Status
        public let copiedSnapshot: Bool
        public let copiedDefaults: Int

        public init(status: Status, copiedSnapshot: Bool = false, copiedDefaults: Int = 0) {
            self.status = status
            self.copiedSnapshot = copiedSnapshot
            self.copiedDefaults = copiedDefaults
        }
    }

    public static func currentGroupID(for bundleID: String? = Bundle.main.bundleIdentifier) -> String {
        self.currentGroupID(teamID: self.defaultTeamID, bundleID: bundleID)
    }

    static func currentGroupID(teamID: String, bundleID: String?) -> String {
        let base = "\(teamID).\(AppIdentity.bundleIdentifier)"
        return self.isDebugBundleID(bundleID) ? "\(base).debug" : base
    }

    public static func resolvedTeamID(bundle _: Bundle = .main) -> String {
        self.defaultTeamID
    }

    static func resolvedTeamID(
        infoDictionaryOverride _: [String: Any]?,
        bundleURLOverride _: URL?) -> String
    {
        self.defaultTeamID
    }

    public static func legacyGroupID(for bundleID: String? = Bundle.main.bundleIdentifier) -> String {
        self.isDebugBundleID(bundleID) ? self.legacyDebugGroupID : self.legacyReleaseGroupID
    }

    public static func sharedDefaults(
        bundleID _: String? = Bundle.main.bundleIdentifier,
        fileManager _: FileManager = .default)
        -> UserDefaults?
    {
        .standard
    }

    public static func currentContainerURL(
        bundleID _: String? = Bundle.main.bundleIdentifier,
        fileManager: FileManager = .default)
        -> URL?
    {
        self.localFallbackDirectory(fileManager: fileManager)
    }

    public static func snapshotURL(
        bundleID _: String? = Bundle.main.bundleIdentifier,
        fileManager: FileManager = .default,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser)
        -> URL
    {
        self.localFallbackDirectory(fileManager: fileManager, homeDirectory: homeDirectory)
            .appendingPathComponent(self.widgetSnapshotFilename, isDirectory: false)
    }

    public static func localFallbackDirectory(
        fileManager: FileManager = .default,
        homeDirectory _: URL = FileManager.default.homeDirectoryForCurrentUser)
        -> URL
    {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let directory = base.appendingPathComponent("AgentBar", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    public static func legacyContainerCandidateURL(
        bundleID _: String? = Bundle.main.bundleIdentifier,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser)
        -> URL
    {
        self.localFallbackDirectory(homeDirectory: homeDirectory)
    }

    public static func migrateLegacyDataIfNeeded(
        bundleID _: String? = Bundle.main.bundleIdentifier,
        standardDefaults: UserDefaults = .standard,
        fileManager _: FileManager = .default,
        homeDirectory _: URL = FileManager.default.homeDirectoryForCurrentUser,
        currentDefaultsOverride _: UserDefaults? = nil,
        legacyDefaultsOverride _: UserDefaults? = nil,
        currentSnapshotURLOverride _: URL? = nil,
        legacySnapshotURLOverride _: URL? = nil)
        -> MigrationResult
    {
        if standardDefaults.integer(forKey: self.migrationVersionKey) >= self.migrationVersion {
            return MigrationResult(status: .alreadyCompleted)
        }

        standardDefaults.set(self.migrationVersion, forKey: self.migrationVersionKey)
        return MigrationResult(status: .noChangesNeeded)
    }

    private static func isDebugBundleID(_ bundleID: String?) -> Bool {
        guard let bundleID, !bundleID.isEmpty else { return false }
        return bundleID.contains(".debug")
    }
}
