import Foundation

public struct AgentBarConfig: Codable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var providers: [ProviderConfig]
    public var tray: TrayConfig
    public var notifications: NotificationConfig

    public init(
        version: Int = Self.currentVersion,
        providers: [ProviderConfig],
        tray: TrayConfig = .init(),
        notifications: NotificationConfig = .init())
    {
        self.version = version
        self.providers = providers
        self.tray = tray
        self.notifications = notifications
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case providers
        case tray
        case notifications
    }

    public static func makeDefault(
        metadata: [UsageProvider: ProviderMetadata] = ProviderDescriptorRegistry.metadata) -> AgentBarConfig
    {
        let providers = UsageProvider.allCases.map { provider in
            ProviderConfig(
                id: provider,
                enabled: metadata[provider]?.defaultEnabled)
        }
        return AgentBarConfig(
            version: Self.currentVersion,
            providers: providers,
            tray: .init(),
            notifications: .init())
    }

    public func normalized(
        metadata: [UsageProvider: ProviderMetadata] = ProviderDescriptorRegistry.metadata) -> AgentBarConfig
    {
        var seen: Set<UsageProvider> = []
        var normalized: [ProviderConfig] = []
        normalized.reserveCapacity(max(self.providers.count, UsageProvider.allCases.count))

        for provider in self.providers {
            guard !seen.contains(provider.id) else { continue }
            seen.insert(provider.id)
            normalized.append(provider)
        }

        for provider in UsageProvider.allCases where !seen.contains(provider) {
            normalized.append(ProviderConfig(
                id: provider,
                enabled: metadata[provider]?.defaultEnabled))
        }

        return AgentBarConfig(
            version: Self.currentVersion,
            providers: normalized,
            tray: self.tray.normalized(),
            notifications: self.notifications.normalized())
    }

    public func orderedProviders() -> [UsageProvider] {
        self.providers.map(\.id)
    }

    public func enabledProviders(
        metadata: [UsageProvider: ProviderMetadata] = ProviderDescriptorRegistry.metadata) -> [UsageProvider]
    {
        self.providers.compactMap { config in
            let enabled = config.enabled ?? metadata[config.id]?.defaultEnabled ?? false
            return enabled ? config.id : nil
        }
    }

    public func providerConfig(for id: UsageProvider) -> ProviderConfig? {
        self.providers.first(where: { $0.id == id })
    }

    public mutating func setProviderConfig(_ config: ProviderConfig) {
        if let index = self.providers.firstIndex(where: { $0.id == config.id }) {
            self.providers[index] = config
        } else {
            self.providers.append(config)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try container.decodeIfPresent(Int.self, forKey: .version) ?? Self.currentVersion
        self.providers = try container.decode([ProviderConfig].self, forKey: .providers)
        self.tray = try container.decodeIfPresent(TrayConfig.self, forKey: .tray) ?? .init()
        self.notifications = try container.decodeIfPresent(NotificationConfig.self, forKey: .notifications) ?? .init()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.version, forKey: .version)
        try container.encode(self.providers, forKey: .providers)
        try container.encode(self.tray, forKey: .tray)
        try container.encode(self.notifications, forKey: .notifications)
    }
}

public struct TrayConfig: Codable, Sendable, Equatable {
    public var displayMode: TrayDisplayMode
    public var preferredProvider: UsageProvider?
    public var iconMode: TrayIconMode

    public init(
        displayMode: TrayDisplayMode = .dualSummary,
        preferredProvider: UsageProvider? = nil,
        iconMode: TrayIconMode = .providerSymbol)
    {
        self.displayMode = displayMode
        self.preferredProvider = preferredProvider
        self.iconMode = iconMode
    }

    public func normalized() -> TrayConfig {
        TrayConfig(
            displayMode: self.displayMode,
            preferredProvider: self.preferredProvider,
            iconMode: self.iconMode)
    }
}

public enum TrayDisplayMode: String, Codable, Sendable, CaseIterable {
    case dualSummary
    case forecastSummary
    case bestAvailable
    case selectedProvider
    case providerName
    case percentRemaining
    case timeToReset
}

public enum TrayIconMode: String, Codable, Sendable, CaseIterable {
    case providerSymbol
    case remainingCircle
}

public struct NotificationConfig: Codable, Sendable, Equatable {
    public var enabled: Bool
    public var lowHeadroomPercent: Int
    public var staleDataHours: Int
    public var aheadOfPacePercent: Int
    public var notifyOnResetCompletion: Bool

    public init(
        enabled: Bool = true,
        lowHeadroomPercent: Int = 15,
        staleDataHours: Int = 6,
        aheadOfPacePercent: Int = 12,
        notifyOnResetCompletion: Bool = true)
    {
        self.enabled = enabled
        self.lowHeadroomPercent = lowHeadroomPercent
        self.staleDataHours = staleDataHours
        self.aheadOfPacePercent = aheadOfPacePercent
        self.notifyOnResetCompletion = notifyOnResetCompletion
    }

    public func normalized() -> NotificationConfig {
        NotificationConfig(
            enabled: self.enabled,
            lowHeadroomPercent: min(max(self.lowHeadroomPercent, 1), 99),
            staleDataHours: min(max(self.staleDataHours, 1), 48),
            aheadOfPacePercent: min(max(self.aheadOfPacePercent, 1), 50),
            notifyOnResetCompletion: self.notifyOnResetCompletion)
    }
}

public struct ProviderConfig: Codable, Sendable, Identifiable {
    public let id: UsageProvider
    public var enabled: Bool?
    public var source: ProviderSourceMode?
    public var extrasEnabled: Bool?
    public var apiKey: String?
    public var cookieHeader: String?
    public var cookieSource: ProviderCookieSource?
    public var region: String?
    public var workspaceID: String?
    public var tokenAccounts: ProviderTokenAccountData?
    public var codexActiveSource: CodexActiveSource?

    public init(
        id: UsageProvider,
        enabled: Bool? = nil,
        source: ProviderSourceMode? = nil,
        extrasEnabled: Bool? = nil,
        apiKey: String? = nil,
        cookieHeader: String? = nil,
        cookieSource: ProviderCookieSource? = nil,
        region: String? = nil,
        workspaceID: String? = nil,
        tokenAccounts: ProviderTokenAccountData? = nil,
        codexActiveSource: CodexActiveSource? = nil)
    {
        self.id = id
        self.enabled = enabled
        self.source = source
        self.extrasEnabled = extrasEnabled
        self.apiKey = apiKey
        self.cookieHeader = cookieHeader
        self.cookieSource = cookieSource
        self.region = region
        self.workspaceID = workspaceID
        self.tokenAccounts = tokenAccounts
        self.codexActiveSource = codexActiveSource
    }

    public var sanitizedAPIKey: String? {
        Self.clean(self.apiKey)
    }

    public var sanitizedCookieHeader: String? {
        Self.clean(self.cookieHeader)
    }

    private static func clean(_ raw: String?) -> String? {
        guard var value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
            (value.hasPrefix("'") && value.hasSuffix("'"))
        {
            value.removeFirst()
            value.removeLast()
        }
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
