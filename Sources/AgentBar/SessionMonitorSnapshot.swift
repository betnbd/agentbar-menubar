import AgentBarCore
import Foundation

enum PanelLoadOutcome<Value: Sendable>: Sendable {
    case success(Value)
    case failure(String)

    var value: Value? {
        if case let .success(value) = self { return value }
        return nil
    }

    var failureMessage: String? {
        if case let .failure(message) = self { return message }
        return nil
    }
}

struct SessionMonitorProviderSnapshot: Sendable {
    let provider: UsageProvider
    let monitor: ProviderMonitorSnapshot
    let credits: PanelLoadOutcome<CreditsSnapshot>?
    let cost: PanelLoadOutcome<CostUsageTokenSnapshot>
    let statusMessages: [String]

    var hasAnyData: Bool {
        self.monitor.primary != nil
            || self.monitor.secondary != nil
            || self.monitor.tertiary != nil
            || self.monitor.creditsRemaining != nil
            || self.monitor.tokenUsage != nil
    }
}

struct SessionMonitorSnapshot: Sendable {
    let configuredProviders: [UsageProvider]
    let providers: [UsageProvider: SessionMonitorProviderSnapshot]
    let availableProviders: [UsageProvider]
    let recommendation: ProviderRecommendation?

    static func load(configuredProviders: [UsageProvider] = [.claude, .codex]) async -> SessionMonitorSnapshot {
        let requestedProviders = configuredProviders.filter { $0 == .claude || $0 == .codex }
        var providerSnapshots: [SessionMonitorProviderSnapshot] = []

        if requestedProviders.contains(.claude) {
            let claudeSnapshot = await Self.loadClaude()
            providerSnapshots.append(claudeSnapshot)
        }
        if requestedProviders.contains(.codex) {
            let codexSnapshot = await Self.loadCodex()
            providerSnapshots.append(codexSnapshot)
        }

        let providers = Dictionary(uniqueKeysWithValues: providerSnapshots.map { ($0.provider, $0) })
        let monitorSnapshots = providerSnapshots.map(\.monitor).filter { snapshot in
            snapshot.primary != nil || snapshot.tokenUsage != nil || snapshot.creditsRemaining != nil
        }

        let availableProviders = providerSnapshots
            .filter(\.hasAnyData)
            .map(\.provider)

        return SessionMonitorSnapshot(
            configuredProviders: requestedProviders,
            providers: providers,
            availableProviders: availableProviders,
            recommendation: DualProviderMonitor.recommend(snapshots: monitorSnapshots))
    }

    private static func loadClaude() async -> SessionMonitorProviderSnapshot {
        let usageFetcher = ClaudeUsageFetcher(browserDetection: BrowserDetection())
        let costFetcher = CostUsageFetcher()

        async let usage = Self.capture {
            try await usageFetcher.loadLatestUsage(model: "sonnet")
        }
        async let cost = Self.capture {
            try await costFetcher.loadTokenSnapshot(provider: .claude)
        }

        let usageResult = await usage
        let costResult = await cost
        let now = Date()
        let updatedAt = [usageResult.value?.updatedAt, costResult.value?.updatedAt].compactMap(\.self).max() ?? now
        let identity = usageResult.value.map {
            ProviderIdentitySnapshot(
                providerID: .claude,
                accountEmail: $0.accountEmail,
                accountOrganization: $0.accountOrganization,
                loginMethod: $0.loginMethod)
        }
        let monitor = ProviderMonitorSnapshot(
            provider: .claude,
            updatedAt: updatedAt,
            primary: usageResult.value?.primary,
            secondary: usageResult.value?.secondary,
            tertiary: usageResult.value?.opus,
            creditsRemaining: nil,
            tokenUsage: costResult.value,
            identity: identity)

        return SessionMonitorProviderSnapshot(
            provider: .claude,
            monitor: monitor,
            credits: nil,
            cost: costResult,
            statusMessages: [
                usageResult.failureMessage.map { "Usage: \($0)" },
                costResult.failureMessage.map { "Cost: \($0)" },
            ].compactMap(\.self))
    }

    private static func loadCodex() async -> SessionMonitorProviderSnapshot {
        let usageFetcher = UsageFetcher()
        let costFetcher = CostUsageFetcher()

        async let usage = Self.capture {
            try await usageFetcher.loadLatestUsage(keepCLISessionsAlive: false)
        }
        async let credits = Self.capture {
            try await usageFetcher.loadLatestCredits(keepCLISessionsAlive: false)
        }
        async let cost = Self.capture {
            try await costFetcher.loadTokenSnapshot(provider: .codex)
        }

        let usageResult = await usage
        let creditsResult = await credits
        let costResult = await cost
        let now = Date()
        let updatedAt = [
            usageResult.value?.updatedAt,
            creditsResult.value?.updatedAt,
            costResult.value?.updatedAt,
        ]
            .compactMap(\.self)
            .max() ?? now

        let monitor = ProviderMonitorSnapshot(
            provider: .codex,
            updatedAt: updatedAt,
            primary: usageResult.value?.primary,
            secondary: usageResult.value?.secondary,
            tertiary: usageResult.value?.tertiary,
            creditsRemaining: creditsResult.value?.remaining,
            tokenUsage: costResult.value,
            identity: usageResult.value?.identity(for: .codex) ?? usageResult.value?.identity)

        return SessionMonitorProviderSnapshot(
            provider: .codex,
            monitor: monitor,
            credits: creditsResult,
            cost: costResult,
            statusMessages: [
                usageResult.failureMessage.map { "Usage: \($0)" },
                creditsResult.failureMessage.map { "Credits: \($0)" },
                costResult.failureMessage.map { "Cost: \($0)" },
            ].compactMap(\.self))
    }

    private static func capture<T: Sendable>(
        _ operation: @escaping @Sendable () async throws -> T)
        async -> PanelLoadOutcome<T>
    {
        do {
            return try await .success(operation())
        } catch {
            let message = (error as NSError).localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            return .failure(message.isEmpty ? "unavailable" : message)
        }
    }
}
