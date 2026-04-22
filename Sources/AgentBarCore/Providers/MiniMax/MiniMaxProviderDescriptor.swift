import AgentBarMacroSupport
import Foundation

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum MiniMaxProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .minimax,
            metadata: ProviderMetadata(
                id: .minimax,
                displayName: "MiniMax",
                sessionLabel: "Prompts",
                weeklyLabel: "Window",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show MiniMax usage",
                cliName: "minimax",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                browserCookieOrder: nil,
                dashboardURL: "https://platform.minimax.io/user-center/payment/coding-plan?cycle_type=3",
                statusPageURL: nil),
            branding: ProviderBranding(
                iconStyle: .minimax,
                iconResourceName: "ProviderIcon-minimax",
                color: ProviderColor(red: 254 / 255, green: 96 / 255, blue: 60 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "MiniMax cost summary is not supported." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .web, .api],
                pipeline: ProviderFetchPipeline(resolveStrategies: self.resolveStrategies)),
            cli: ProviderCLIConfig(
                name: "minimax",
                aliases: ["mini-max"],
                versionDetector: nil))
    }

    private static func resolveStrategies(context: ProviderFetchContext) async -> [any ProviderFetchStrategy] {
        switch context.sourceMode {
        case .web:
            return [MiniMaxCodingPlanFetchStrategy()]
        case .api:
            return [MiniMaxAPIFetchStrategy()]
        case .cli, .oauth:
            return []
        case .auto:
            break
        }
        let apiToken = ProviderTokenResolver.minimaxToken(environment: context.env)
        let apiKeyKind = MiniMaxAPISettingsReader.apiKeyKind(token: apiToken)
        let authMode = MiniMaxAuthMode.resolve(
            apiToken: apiToken,
            cookieHeader: ProviderTokenResolver.minimaxCookie(environment: context.env))
        if authMode.usesAPIToken {
            if apiKeyKind == .standard {
                return [MiniMaxCodingPlanFetchStrategy()]
            }
            return [MiniMaxAPIFetchStrategy(), MiniMaxCodingPlanFetchStrategy()]
        }
        return [MiniMaxCodingPlanFetchStrategy()]
    }
}

struct MiniMaxAPIFetchStrategy: ProviderFetchStrategy {
    let id: String = "minimax.api"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        let authMode = MiniMaxAuthMode.resolve(
            apiToken: ProviderTokenResolver.minimaxToken(environment: context.env),
            cookieHeader: ProviderTokenResolver.minimaxCookie(environment: context.env))
        if let kind = MiniMaxAPISettingsReader.apiKeyKind(environment: context.env),
           kind == .standard
        {
            return false
        }
        return authMode.usesAPIToken
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let apiToken = ProviderTokenResolver.minimaxToken(environment: context.env) else {
            throw MiniMaxAPISettingsError.missingToken
        }
        let region = context.settings?.minimax?.apiRegion ?? .global
        let usage = try await MiniMaxUsageFetcher.fetchUsage(apiToken: apiToken, region: region)
        return self.makeResult(
            usage: usage.toUsageSnapshot(),
            sourceLabel: "api")
    }

    func shouldFallback(on error: Error, context _: ProviderFetchContext) -> Bool {
        guard let minimaxError = error as? MiniMaxUsageError else { return false }
        switch minimaxError {
        case .invalidCredentials:
            return true
        case let .apiError(message):
            return message.contains("HTTP 404")
        case .networkError, .parseFailed:
            return false
        }
    }
}

struct MiniMaxCodingPlanFetchStrategy: ProviderFetchStrategy {
    let id: String = "minimax.web"
    let kind: ProviderFetchKind = .web
    private static let log = AgentBarLog.logger(LogCategories.minimaxWeb)

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        Self.resolveCookieOverride(context: context) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        let fetchContext = FetchContext(
            region: context.settings?.minimax?.apiRegion ?? .global,
            environment: context.env)
        if let override = Self.resolveCookieOverride(context: context) {
            Self.log.debug("Using MiniMax cookie header from settings/env")
            let snapshot = try await MiniMaxUsageFetcher.fetchUsage(
                cookieHeader: override.cookieHeader,
                authorizationToken: override.authorizationToken,
                groupID: override.groupID,
                region: fetchContext.region,
                environment: fetchContext.environment)
            return self.makeResult(
                usage: snapshot.toUsageSnapshot(),
                sourceLabel: "web")
        }

        throw MiniMaxSettingsError.missingCookie
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }

    private struct FetchContext {
        let region: MiniMaxAPIRegion
        let environment: [String: String]
    }

    private static func resolveCookieOverride(context: ProviderFetchContext) -> MiniMaxCookieOverride? {
        if let settings = context.settings?.minimax {
            guard settings.cookieSource == .manual else { return nil }
            return MiniMaxCookieHeader.override(from: settings.manualCookieHeader)
        }
        guard let raw = ProviderTokenResolver.minimaxCookie(environment: context.env) else {
            return nil
        }
        return MiniMaxCookieHeader.override(from: raw)
    }
}
