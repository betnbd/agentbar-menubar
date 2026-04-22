import Foundation

public enum AgentBarConfigIssueSeverity: String, Codable, Sendable {
    case warning
    case error
}

public struct AgentBarConfigIssue: Codable, Sendable, Equatable {
    public let severity: AgentBarConfigIssueSeverity
    public let provider: UsageProvider?
    public let field: String?
    public let code: String
    public let message: String

    public init(
        severity: AgentBarConfigIssueSeverity,
        provider: UsageProvider?,
        field: String?,
        code: String,
        message: String)
    {
        self.severity = severity
        self.provider = provider
        self.field = field
        self.code = code
        self.message = message
    }
}

public enum AgentBarConfigValidator {
    public static func validate(_ config: AgentBarConfig) -> [AgentBarConfigIssue] {
        var issues: [AgentBarConfigIssue] = []

        if config.version != AgentBarConfig.currentVersion {
            issues.append(AgentBarConfigIssue(
                severity: .error,
                provider: nil,
                field: "version",
                code: "version_mismatch",
                message: "Unsupported config version \(config.version)."))
        }

        if let preferredProvider = config.tray.preferredProvider,
           !UsageProvider.allCases.contains(preferredProvider)
        {
            issues.append(AgentBarConfigIssue(
                severity: .error,
                provider: preferredProvider,
                field: "tray.preferredProvider",
                code: "invalid_tray_provider",
                message: "tray.preferredProvider is not a valid provider."))
        }

        if config.tray.iconMode == .remainingCircle,
           config.tray.preferredProvider == nil,
           config.tray.displayMode == .selectedProvider
        {
            issues.append(AgentBarConfigIssue(
                severity: .warning,
                provider: nil,
                field: "tray.preferredProvider",
                code: "missing_tray_provider_for_icon",
                message: "tray.preferredProvider is recommended when tray.iconMode uses "
                    + "remainingCircle with selectedProvider mode."))
        }

        if let preferredProvider = config.tray.preferredProvider,
           let providerConfig = config.providerConfig(for: preferredProvider),
           providerConfig.enabled == false
        {
            issues.append(AgentBarConfigIssue(
                severity: .warning,
                provider: preferredProvider,
                field: "tray.preferredProvider",
                code: "disabled_tray_provider",
                message: "tray.preferredProvider points to a disabled provider."))
        }

        if !(1...99).contains(config.notifications.lowHeadroomPercent) {
            issues.append(AgentBarConfigIssue(
                severity: .error,
                provider: nil,
                field: "notifications.lowHeadroomPercent",
                code: "invalid_low_headroom_percent",
                message: "notifications.lowHeadroomPercent must be between 1 and 99."))
        }

        if !(1...48).contains(config.notifications.staleDataHours) {
            issues.append(AgentBarConfigIssue(
                severity: .error,
                provider: nil,
                field: "notifications.staleDataHours",
                code: "invalid_stale_data_hours",
                message: "notifications.staleDataHours must be between 1 and 48."))
        }

        if !(1...50).contains(config.notifications.aheadOfPacePercent) {
            issues.append(AgentBarConfigIssue(
                severity: .error,
                provider: nil,
                field: "notifications.aheadOfPacePercent",
                code: "invalid_ahead_of_pace_percent",
                message: "notifications.aheadOfPacePercent must be between 1 and 50."))
        }

        for entry in config.providers {
            self.validateProvider(entry, issues: &issues)
        }

        return issues
    }

    private static func validateProvider(_ entry: ProviderConfig, issues: inout [AgentBarConfigIssue]) {
        let provider = entry.id
        let descriptor = ProviderDescriptorRegistry.descriptor(for: provider)
        let supportedSources = descriptor.fetchPlan.sourceModes
        let supportsWeb = supportedSources.contains(.auto) || supportedSources.contains(.web)
        let supportsAPI = supportedSources.contains(.api)

        if let source = entry.source, !supportedSources.contains(source) {
            issues.append(AgentBarConfigIssue(
                severity: .error,
                provider: provider,
                field: "source",
                code: "unsupported_source",
                message: "Source \(source.rawValue) is not supported for \(provider.rawValue)."))
        }

        if let apiKey = entry.apiKey, !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !supportsAPI {
            issues.append(AgentBarConfigIssue(
                severity: .warning,
                provider: provider,
                field: "apiKey",
                code: "api_key_unused",
                message: "apiKey is set but \(provider.rawValue) does not support api source."))
        }

        if let source = entry.source, source == .api, !supportsAPI {
            issues.append(AgentBarConfigIssue(
                severity: .error,
                provider: provider,
                field: "source",
                code: "api_source_unsupported",
                message: "Source api is not supported for \(provider.rawValue)."))
        }

        if let source = entry.source, source == .api,
           entry.apiKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
        {
            issues.append(AgentBarConfigIssue(
                severity: .warning,
                provider: provider,
                field: "apiKey",
                code: "api_key_missing",
                message: "Source api is selected but apiKey is missing for \(provider.rawValue)."))
        }

        if entry.cookieSource != nil, !supportsWeb {
            issues.append(AgentBarConfigIssue(
                severity: .warning,
                provider: provider,
                field: "cookieSource",
                code: "cookie_source_unused",
                message: "cookieSource is set but \(provider.rawValue) does not use web cookies."))
        }

        if let cookieHeader = entry.cookieHeader,
           !cookieHeader.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !supportsWeb
        {
            issues.append(AgentBarConfigIssue(
                severity: .warning,
                provider: provider,
                field: "cookieHeader",
                code: "cookie_header_unused",
                message: "cookieHeader is set but \(provider.rawValue) does not use web cookies."))
        }

        if let cookieSource = entry.cookieSource,
           cookieSource == .manual,
           entry.cookieHeader?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
        {
            issues.append(AgentBarConfigIssue(
                severity: .warning,
                provider: provider,
                field: "cookieHeader",
                code: "cookie_header_missing",
                message: "cookieSource manual is set but cookieHeader is missing for \(provider.rawValue)."))
        }

        if let region = entry.region, !region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            switch provider {
            case .minimax:
                if MiniMaxAPIRegion(rawValue: region) == nil {
                    issues.append(AgentBarConfigIssue(
                        severity: .error,
                        provider: provider,
                        field: "region",
                        code: "invalid_region",
                        message: "Region \(region) is not a valid MiniMax region."))
                }
            case .zai:
                if ZaiAPIRegion(rawValue: region) == nil {
                    issues.append(AgentBarConfigIssue(
                        severity: .error,
                        provider: provider,
                        field: "region",
                        code: "invalid_region",
                        message: "Region \(region) is not a valid z.ai region."))
                }
            default:
                issues.append(AgentBarConfigIssue(
                    severity: .warning,
                    provider: provider,
                    field: "region",
                    code: "region_unused",
                    message: "region is set but \(provider.rawValue) does not use regions."))
            }
        }

        if let workspaceID = entry.workspaceID,
           !workspaceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           provider != .opencode,
           provider != .opencodego
        {
            issues.append(AgentBarConfigIssue(
                severity: .warning,
                provider: provider,
                field: "workspaceID",
                code: "workspace_unused",
                message: "workspaceID is set but only opencode and opencodego support workspaceID."))
        }

        if let tokenAccounts = entry.tokenAccounts, !tokenAccounts.accounts.isEmpty,
           TokenAccountSupportCatalog.support(for: provider) == nil
        {
            issues.append(AgentBarConfigIssue(
                severity: .warning,
                provider: provider,
                field: "tokenAccounts",
                code: "token_accounts_unused",
                message: "tokenAccounts are set but \(provider.rawValue) does not support token accounts."))
        }
    }
}
