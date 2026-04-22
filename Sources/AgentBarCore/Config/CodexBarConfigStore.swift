import Foundation

public enum AgentBarConfigStoreError: LocalizedError {
    case invalidURL
    case decodeFailed(String)
    case encodeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid AgentBar config path."
        case let .decodeFailed(details):
            "Failed to decode AgentBar config: \(details)"
        case let .encodeFailed(details):
            "Failed to encode AgentBar config: \(details)"
        }
    }
}

public struct AgentBarConfigStore: @unchecked Sendable {
    public let fileURL: URL
    private let fileManager: FileManager

    public init(fileURL: URL = Self.defaultURL(), fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    public func load() throws -> AgentBarConfig? {
        guard self.fileManager.fileExists(atPath: self.fileURL.path) else { return nil }
        let data = try Data(contentsOf: self.fileURL)
        let decoder = JSONDecoder()
        do {
            let decoded = try decoder.decode(AgentBarConfig.self, from: data)
            return decoded.normalized()
        } catch {
            guard let sanitized = self.sanitizedConfigData(from: data) else {
                throw AgentBarConfigStoreError.decodeFailed(error.localizedDescription)
            }
            do {
                let decoded = try decoder.decode(AgentBarConfig.self, from: sanitized)
                return decoded.normalized()
            } catch {
                throw AgentBarConfigStoreError.decodeFailed(error.localizedDescription)
            }
        }
    }

    public func loadOrCreateDefault() throws -> AgentBarConfig {
        if let existing = try self.load() {
            return existing
        }
        let config = AgentBarConfig.makeDefault()
        try self.save(config)
        return config
    }

    public func save(_ config: AgentBarConfig) throws {
        let normalized = config.normalized()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data: Data
        do {
            data = try encoder.encode(normalized)
        } catch {
            throw AgentBarConfigStoreError.encodeFailed(error.localizedDescription)
        }
        let directory = self.fileURL.deletingLastPathComponent()
        if !self.fileManager.fileExists(atPath: directory.path) {
            try self.fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        try data.write(to: self.fileURL, options: [.atomic])
        try self.applySecurePermissionsIfNeeded()
    }

    public func deleteIfPresent() throws {
        guard self.fileManager.fileExists(atPath: self.fileURL.path) else { return }
        try self.fileManager.removeItem(at: self.fileURL)
    }

    public static func defaultURL(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        home
            .appendingPathComponent(AppIdentity.configDirectoryName, isDirectory: true)
            .appendingPathComponent("config.json")
    }

    private func applySecurePermissionsIfNeeded() throws {
        try self.fileManager.setAttributes([
            .posixPermissions: NSNumber(value: Int16(0o600)),
        ], ofItemAtPath: self.fileURL.path)
    }

    private func sanitizedConfigData(from data: Data) -> Data? {
        guard var object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return nil
        }

        if let providers = object["providers"] as? [[String: Any]] {
            let validProviderIDs = Set(UsageProvider.allCases.map(\.rawValue))
            object["providers"] = providers.filter { provider in
                guard let rawID = provider["id"] as? String else { return false }
                return validProviderIDs.contains(rawID)
            }
        }

        if var tray = object["tray"] as? [String: Any],
           let preferredProvider = tray["preferredProvider"] as? String,
           UsageProvider(rawValue: preferredProvider) == nil
        {
            tray.removeValue(forKey: "preferredProvider")
            object["tray"] = tray
        }

        return try? JSONSerialization.data(withJSONObject: object, options: [])
    }
}
