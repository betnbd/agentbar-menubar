import Foundation
import Testing
@testable import AgentBarCore

private struct TestClaudeUsageFetcher: ClaudeUsageFetching {
    func loadLatestUsage(model _: String) async throws -> ClaudeUsageSnapshot {
        ClaudeUsageSnapshot(
            primary: RateWindow(usedPercent: 0, windowMinutes: nil, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            opus: nil,
            updatedAt: Date(timeIntervalSince1970: 0),
            accountEmail: nil,
            accountOrganization: nil,
            loginMethod: nil,
            rawText: nil)
    }

    func debugRawProbe(model _: String) async -> String {
        ""
    }

    func detectVersion() -> String? {
        nil
    }
}

private actor AutoRefreshRecorder {
    private var remainingSuccessfulSleeps: Int
    private var sleepCalls: [TimeInterval] = []
    private var refreshCount = 0

    init(remainingSuccessfulSleeps: Int) {
        self.remainingSuccessfulSleeps = remainingSuccessfulSleeps
    }

    func sleep(interval: TimeInterval) async throws {
        self.sleepCalls.append(interval)
        if self.remainingSuccessfulSleeps > 0 {
            self.remainingSuccessfulSleeps -= 1
            return
        }
        throw CancellationError()
    }

    func refresh() {
        self.refreshCount += 1
    }

    func snapshot() -> (sleepCalls: [TimeInterval], refreshCount: Int) {
        (self.sleepCalls, self.refreshCount)
    }
}

struct AgentBarLinuxTests {
    private func makeFetchContext(
        sourceMode: ProviderSourceMode = .auto,
        env: [String: String] = [:],
        settings: ProviderSettingsSnapshot? = nil) -> ProviderFetchContext
    {
        ProviderFetchContext(
            runtime: .cli,
            sourceMode: sourceMode,
            includeCredits: false,
            webTimeout: 5,
            webDebugDumpHTML: false,
            verbose: false,
            env: env,
            settings: settings,
            fetcher: UsageFetcher(environment: env),
            claudeFetcher: TestClaudeUsageFetcher(),
            browserDetection: BrowserDetection())
    }

    @Test
    func defaultConfigIncludesProviders() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let configURL = tempRoot.appendingPathComponent("config.json")
        let store = AgentBarConfigStore(fileURL: configURL)

        let config = try store.loadOrCreateDefault()

        #expect(!config.providers.isEmpty)
        #expect(FileManager.default.fileExists(atPath: configURL.path))
        #expect(config.enabledProviders().contains(.codex))
    }

    @Test
    func saveAndReloadRoundTripsProviderState() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let configURL = tempRoot.appendingPathComponent("config.json")
        let store = AgentBarConfigStore(fileURL: configURL)

        var config = AgentBarConfig.makeDefault()
        config.setProviderConfig(.init(id: .claude, enabled: false))
        config.setProviderConfig(.init(id: .gemini, enabled: true))
        config.tray.displayMode = .timeToReset
        config.tray.iconMode = .remainingCircle
        config.notifications.lowHeadroomPercent = 12
        try store.save(config)

        let loaded = try #require(try store.load())
        #expect(loaded.providerConfig(for: .claude)?.enabled == false)
        #expect(loaded.providerConfig(for: .gemini)?.enabled == true)
        #expect(loaded.tray.displayMode == .timeToReset)
        #expect(loaded.tray.iconMode == .remainingCircle)
        #expect(loaded.notifications.lowHeadroomPercent == 12)
    }

    @Test
    func trayAutoRefreshPolicyDefaultsToSixtySecondsAndAcceptsSafeOverrides() {
        #expect(TrayAutoRefreshPolicy.interval(environment: [:]) == 60)
        #expect(TrayAutoRefreshPolicy.interval(environment: ["AGENTBAR_REFRESH_SECONDS": "120"]) == 120)
        #expect(TrayAutoRefreshPolicy.interval(environment: ["AGENTBAR_REFRESH_SECONDS": "0"]) == 60)
        #expect(TrayAutoRefreshPolicy.interval(environment: ["AGENTBAR_REFRESH_SECONDS": "5"]) == 60)
        #expect(TrayAutoRefreshPolicy.interval(environment: ["AGENTBAR_REFRESH_SECONDS": "abc"]) == 60)
    }

    @Test
    func trayAutoRefreshSchedulerWaitsForConfiguredIntervalBeforeRefreshing() async {
        let recorder = AutoRefreshRecorder(remainingSuccessfulSleeps: 1)
        let scheduler = TrayAutoRefreshScheduler(
            interval: 42,
            sleep: { interval in try await recorder.sleep(interval: interval) },
            refresh: { await recorder.refresh() })

        await scheduler.run()

        let snapshot = await recorder.snapshot()
        #expect(snapshot.sleepCalls == [42, 42])
        #expect(snapshot.refreshCount == 1)
    }

    @Test
    func configStoreWritesPrivateFilePermissions() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let configURL = tempRoot.appendingPathComponent("config.json")
        let store = AgentBarConfigStore(fileURL: configURL)

        try store.save(.makeDefault())

        let attributes = try FileManager.default.attributesOfItem(atPath: configURL.path)
        let permissions = try #require(attributes[.posixPermissions] as? NSNumber)
        #expect(permissions.intValue == 0o600)
    }

    @Test
    func tokenAccountStoreWritesPrivateFilePermissions() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storeURL = tempRoot.appendingPathComponent("token-accounts.json")
        let store = FileTokenAccountStore(fileURL: storeURL)

        try store.storeAccounts([:])

        let attributes = try FileManager.default.attributesOfItem(atPath: storeURL.path)
        let permissions = try #require(attributes[.posixPermissions] as? NSNumber)
        #expect(permissions.intValue == 0o600)
    }

    @Test
    func managedCodexAccountStoreWritesPrivateFilePermissions() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storeURL = tempRoot.appendingPathComponent("managed-codex-accounts.json")
        let store = FileManagedCodexAccountStore(fileURL: storeURL)

        try store.storeAccounts(ManagedCodexAccountSet(version: 2, accounts: []))

        let attributes = try FileManager.default.attributesOfItem(atPath: storeURL.path)
        let permissions = try #require(attributes[.posixPermissions] as? NSNumber)
        #expect(permissions.intValue == 0o600)
    }

    @Test
    func updatedStringUsesLinuxFriendlyRelativeFormatting() {
        let now = Date(timeIntervalSince1970: 10000)
        let minutesAgo = now.addingTimeInterval(-5 * 60)
        let hoursAgo = now.addingTimeInterval(-2 * 3600)

        #expect(UsageFormatter.updatedString(from: minutesAgo, now: now) == "Updated 5m ago")
        #expect(UsageFormatter.updatedString(from: hoursAgo, now: now) == "Updated 2h ago")
    }

    @Test
    func providerMonitorDisplayFormatterNormalizesPlansByProvider() {
        let claudeIdentity = ProviderIdentitySnapshot(
            providerID: .claude,
            accountEmail: "claude@example.com",
            accountOrganization: nil,
            loginMethod: "Claude Max")
        let codexIdentity = ProviderIdentitySnapshot(
            providerID: .codex,
            accountEmail: "codex@example.com",
            accountOrganization: nil,
            loginMethod: "pro_lite")

        #expect(
            ProviderMonitorDisplayFormatter.planDisplayName(for: .claude, identity: claudeIdentity) == "Max")
        #expect(
            ProviderMonitorDisplayFormatter.planDisplayName(for: .codex, identity: codexIdentity) == "Pro Lite")
    }

    @Test
    func providerMonitorDisplayFormatterBuildsSummaryLineWithPlanAndCredits() {
        let now = Date(timeIntervalSince1970: 0)
        let monitor = ProviderMonitorSnapshot(
            provider: .codex,
            updatedAt: now,
            primary: RateWindow(
                usedPercent: 17,
                windowMinutes: 5 * 60,
                resetsAt: now.addingTimeInterval(81 * 60),
                resetDescription: nil),
            secondary: RateWindow(usedPercent: 3, windowMinutes: 7 * 24 * 60, resetsAt: nil, resetDescription: nil),
            tertiary: nil,
            creditsRemaining: 0,
            tokenUsage: nil,
            identity: ProviderIdentitySnapshot(
                providerID: .codex,
                accountEmail: nil,
                accountOrganization: nil,
                loginMethod: "plus"))

        let line = ProviderMonitorDisplayFormatter.summaryLine(
            for: monitor,
            sessionCostUSD: 20.49,
            creditsRemaining: 0,
            now: now)

        #expect(line == "Codex: 83% left | plan Plus | 1h 21m | weekly 97% | $20.49 | credits 0 left")
    }

    @Test
    func dualProviderMonitorPrefersProviderWithMoreFreshHeadroom() throws {
        let now = Date(timeIntervalSince1970: 0)
        let claude = ProviderMonitorSnapshot(
            provider: .claude,
            updatedAt: now,
            primary: RateWindow(usedPercent: 65, windowMinutes: 5 * 60, resetsAt: nil, resetDescription: nil),
            secondary: RateWindow(usedPercent: 40, windowMinutes: 7 * 24 * 60, resetsAt: nil, resetDescription: nil),
            tertiary: nil,
            creditsRemaining: nil,
            tokenUsage: nil,
            identity: nil)
        let codex = ProviderMonitorSnapshot(
            provider: .codex,
            updatedAt: now,
            primary: RateWindow(usedPercent: 20, windowMinutes: 5 * 60, resetsAt: nil, resetDescription: nil),
            secondary: RateWindow(usedPercent: 10, windowMinutes: 7 * 24 * 60, resetsAt: nil, resetDescription: nil),
            tertiary: nil,
            creditsRemaining: nil,
            tokenUsage: nil,
            identity: nil)

        let recommendation = try #require(DualProviderMonitor.recommend(snapshots: [claude, codex], now: now))
        #expect(recommendation.preferredProvider == .codex)
        #expect(recommendation.runnerUpProvider == .claude)
    }

    @Test
    func dualProviderMonitorPenalizesStaleSnapshots() throws {
        let now = Date(timeIntervalSince1970: 0)
        let staleCodex = ProviderMonitorSnapshot(
            provider: .codex,
            updatedAt: now.addingTimeInterval(-12 * 60 * 60),
            primary: RateWindow(usedPercent: 10, windowMinutes: 5 * 60, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            tertiary: nil,
            creditsRemaining: nil,
            tokenUsage: nil,
            identity: nil)
        let freshClaude = ProviderMonitorSnapshot(
            provider: .claude,
            updatedAt: now,
            primary: RateWindow(usedPercent: 25, windowMinutes: 5 * 60, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            tertiary: nil,
            creditsRemaining: nil,
            tokenUsage: nil,
            identity: nil)

        let recommendation = try #require(DualProviderMonitor.recommend(snapshots: [staleCodex, freshClaude], now: now))
        #expect(recommendation.preferredProvider == .claude)
        #expect(recommendation.rationale.contains("Confidence:"))
    }

    @Test
    func dualProviderMonitorDeclinesFullyStaleRecommendations() {
        let now = Date(timeIntervalSince1970: 24 * 60 * 60)
        let staleClaude = ProviderMonitorSnapshot(
            provider: .claude,
            updatedAt: now.addingTimeInterval(-18 * 60 * 60),
            primary: RateWindow(usedPercent: 20, windowMinutes: 5 * 60, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            tertiary: nil,
            creditsRemaining: nil,
            tokenUsage: nil,
            identity: nil)
        let staleCodex = ProviderMonitorSnapshot(
            provider: .codex,
            updatedAt: now.addingTimeInterval(-14 * 60 * 60),
            primary: RateWindow(usedPercent: 10, windowMinutes: 5 * 60, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            tertiary: nil,
            creditsRemaining: nil,
            tokenUsage: nil,
            identity: nil)

        #expect(DualProviderMonitor.recommend(snapshots: [staleClaude, staleCodex], now: now) == nil)
    }

    @Test
    func dualProviderMonitorBuildsCompactTrayLabel() {
        let now = Date(timeIntervalSince1970: 0)
        let claude = ProviderMonitorSnapshot(
            provider: .claude,
            updatedAt: now,
            primary: RateWindow(usedPercent: 60, windowMinutes: 5 * 60, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            tertiary: nil,
            creditsRemaining: nil,
            tokenUsage: nil,
            identity: nil)
        let codex = ProviderMonitorSnapshot(
            provider: .codex,
            updatedAt: now,
            primary: RateWindow(usedPercent: 30, windowMinutes: 5 * 60, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            tertiary: nil,
            creditsRemaining: nil,
            tokenUsage: nil,
            identity: nil)

        let label = DualProviderMonitor.trayLabel(snapshots: [claude, codex], now: now)
        #expect(label == "Co 70% | Cl 40%")
    }

    @Test
    func dualProviderMonitorSupportsForecastTrayMode() {
        let now = Date(timeIntervalSince1970: 0)
        let reset = now.addingTimeInterval(60 * 60)
        let codex = ProviderMonitorSnapshot(
            provider: .codex,
            updatedAt: now,
            primary: RateWindow(
                usedPercent: 90,
                windowMinutes: 5 * 60,
                resetsAt: reset,
                resetDescription: nil),
            secondary: nil,
            tertiary: nil,
            creditsRemaining: nil,
            tokenUsage: nil,
            identity: nil)

        let label = DualProviderMonitor.trayLabel(
            snapshots: [codex],
            mode: .forecastSummary,
            now: now)
        #expect(label == "Co risk 26m")
    }

    @Test
    func dualProviderMonitorSupportsAlternateTrayModes() {
        let now = Date(timeIntervalSince1970: 0)
        let reset = now.addingTimeInterval(90 * 60)
        let claude = ProviderMonitorSnapshot(
            provider: .claude,
            updatedAt: now,
            primary: RateWindow(
                usedPercent: 40,
                windowMinutes: 5 * 60,
                resetsAt: reset,
                resetDescription: nil),
            secondary: nil,
            tertiary: nil,
            creditsRemaining: nil,
            tokenUsage: nil,
            identity: nil)

        #expect(
            DualProviderMonitor.trayLabel(
                snapshots: [claude],
                mode: .providerName,
                now: now) == "Cl")
        #expect(
            DualProviderMonitor.trayLabel(
                snapshots: [claude],
                mode: .percentRemaining,
                now: now) == "60%")
        #expect(
            DualProviderMonitor.trayLabel(
                snapshots: [claude],
                mode: .timeToReset,
                now: now) == "in 1h 30m")
    }

    @Test
    func dualProviderMonitorBuildsUsageIconSnapshotFromSelectedProvider() throws {
        let now = Date(timeIntervalSince1970: 0)
        let claude = ProviderMonitorSnapshot(
            provider: .claude,
            updatedAt: now,
            primary: RateWindow(usedPercent: 40, windowMinutes: 5 * 60, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            tertiary: nil,
            creditsRemaining: nil,
            tokenUsage: nil,
            identity: nil)
        let codex = ProviderMonitorSnapshot(
            provider: .codex,
            updatedAt: now,
            primary: RateWindow(usedPercent: 10, windowMinutes: 5 * 60, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            tertiary: nil,
            creditsRemaining: nil,
            tokenUsage: nil,
            identity: nil)

        let icon = try #require(DualProviderMonitor.trayUsageIconSnapshot(
            snapshots: [claude, codex],
            selectedProvider: .claude,
            now: now))
        #expect(icon.provider == .claude)
        #expect(icon.remainingPercent == 60)
    }

    @Test
    func dualProviderMonitorSkipsStaleUsageIconSnapshots() {
        let now = Date(timeIntervalSince1970: 24 * 60 * 60)
        let staleClaude = ProviderMonitorSnapshot(
            provider: .claude,
            updatedAt: now.addingTimeInterval(-8 * 60 * 60),
            primary: RateWindow(usedPercent: 40, windowMinutes: 5 * 60, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            tertiary: nil,
            creditsRemaining: nil,
            tokenUsage: nil,
            identity: nil)

        #expect(DualProviderMonitor.trayUsageIconSnapshot(
            snapshots: [staleClaude],
            selectedProvider: .claude,
            now: now) == nil)
    }

    @Test
    func dualProviderMonitorSummarizesPace() {
        let now = Date(timeIntervalSince1970: 0)
        let weeklyReset = now.addingTimeInterval(2 * 24 * 60 * 60)
        let snapshot = ProviderMonitorSnapshot(
            provider: .codex,
            updatedAt: now,
            primary: nil,
            secondary: RateWindow(
                usedPercent: 80,
                windowMinutes: 7 * 24 * 60,
                resetsAt: weeklyReset,
                resetDescription: nil),
            tertiary: nil,
            creditsRemaining: nil,
            tokenUsage: nil,
            identity: nil)

        #expect(DualProviderMonitor.paceSummary(snapshot: snapshot, now: now) == "Pace: ahead")
    }

    @Test
    func notificationConfigIsNormalizedIntoSafeBounds() {
        let config = AgentBarConfig(
            providers: AgentBarConfig.makeDefault().providers,
            tray: .init(displayMode: .selectedProvider, preferredProvider: .claude, iconMode: .remainingCircle),
            notifications: .init(
                enabled: true,
                lowHeadroomPercent: 0,
                staleDataHours: 100,
                aheadOfPacePercent: 99,
                notifyOnResetCompletion: true))
            .normalized()

        #expect(config.notifications.lowHeadroomPercent == 1)
        #expect(config.notifications.staleDataHours == 48)
        #expect(config.notifications.aheadOfPacePercent == 50)
        #expect(config.tray.displayMode == .selectedProvider)
        #expect(config.tray.preferredProvider == .claude)
        #expect(config.tray.iconMode == .remainingCircle)
    }

    @Test
    func configValidatorWarnsWhenCircleIconHasNoSelectedProvider() {
        let config = AgentBarConfig(
            providers: AgentBarConfig.makeDefault().providers,
            tray: .init(displayMode: .selectedProvider, preferredProvider: nil, iconMode: .remainingCircle),
            notifications: .init())

        let issues = AgentBarConfigValidator.validate(config)
        let issue = issues.first(where: { $0.code == "missing_tray_provider_for_icon" })

        #expect(issue?.severity == .warning)
        #expect(issue?.field == "tray.preferredProvider")
    }

    @Test
    func configValidatorWarnsWhenTrayProviderIsDisabled() {
        var config = AgentBarConfig.makeDefault()
        config.setProviderConfig(.init(id: .claude, enabled: false))
        config.tray.preferredProvider = .claude

        let issues = AgentBarConfigValidator.validate(config)
        let issue = issues.first(where: { $0.code == "disabled_tray_provider" })

        #expect(issue?.severity == .warning)
        #expect(issue?.provider == .claude)
        #expect(issue?.field == "tray.preferredProvider")
    }

    @Test
    func configStoreSanitizesInvalidTrayPreferredProvider() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let configURL = tempRoot.appendingPathComponent("config.json")
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        try """
        {
          "version": 1,
          "providers": [
            { "id": "codex", "enabled": true },
            { "id": "not-real", "enabled": true }
          ],
          "tray": {
            "displayMode": "selectedProvider",
            "preferredProvider": "not-real",
            "iconMode": "remainingCircle"
          },
          "notifications": {
            "enabled": true,
            "lowHeadroomPercent": 15,
            "staleDataHours": 6,
            "aheadOfPacePercent": 12,
            "notifyOnResetCompletion": true
          }
        }
        """.write(to: configURL, atomically: true, encoding: .utf8)

        let loaded = try #require(try AgentBarConfigStore(fileURL: configURL).load())
        #expect(loaded.providers.contains(where: { $0.id == .codex }))
        #expect(!loaded.providers.contains(where: { $0.id.rawValue == "not-real" }))
        #expect(loaded.tray.preferredProvider == nil)
    }

    @Test
    func linuxProviderDescriptorsDoNotExposeBrowserImportOrder() {
        #expect(ProviderDefaults.metadata[.opencode]?.browserCookieOrder == nil)
        #expect(ProviderDefaults.metadata[.opencodego]?.browserCookieOrder == nil)
        #expect(ProviderDefaults.metadata[.minimax]?.browserCookieOrder == nil)
        #expect(ProviderDefaults.metadata[.amp]?.browserCookieOrder == nil)
        #expect(ProviderDefaults.metadata[.ollama]?.browserCookieOrder == nil)
    }

    @Test
    func kimiWebStrategyOnlyUsesManualOrEnvironmentSourcesOnLinux() async {
        let strategy = KimiWebFetchStrategy()

        let unavailable = await strategy.isAvailable(self.makeFetchContext(
            settings: .make(kimi: .init(cookieSource: .auto, manualCookieHeader: nil))))
        #expect(unavailable == false)

        let fromEnvironment = await strategy.isAvailable(self.makeFetchContext(
            env: ["KIMI_AUTH_TOKEN": "env-token"],
            settings: .make(kimi: .init(cookieSource: .auto, manualCookieHeader: nil))))
        #expect(fromEnvironment == true)

        let fromManual = await strategy.isAvailable(self.makeFetchContext(
            settings: .make(kimi: .init(cookieSource: .manual, manualCookieHeader: "kimi-auth=manual-token"))))
        #expect(fromManual == true)
    }

    @Test
    func perplexityWebStrategyUsesManualCacheOrEnvironmentOnLinux() async {
        let strategy = PerplexityWebFetchStrategy()

        let unavailable = await strategy.isAvailable(self.makeFetchContext(
            settings: .make(perplexity: .init(cookieSource: .auto, manualCookieHeader: nil))))
        #expect(unavailable == false)

        let fromEnvironment = await strategy.isAvailable(self.makeFetchContext(
            env: ["PERPLEXITY_SESSION_TOKEN": "env-token"],
            settings: .make(perplexity: .init(cookieSource: .auto, manualCookieHeader: nil))))
        #expect(fromEnvironment == true)

        let fromManual = await strategy.isAvailable(self.makeFetchContext(
            settings: .make(perplexity: .init(cookieSource: .manual, manualCookieHeader: "pplx_session=manual-token"))))
        #expect(fromManual == true)
    }

    @Test
    func minimaxWebStrategyRequiresManualCookieOnLinux() async {
        let strategy = MiniMaxCodingPlanFetchStrategy()

        let unavailable = await strategy.isAvailable(self.makeFetchContext(
            settings: .make(minimax: .init(cookieSource: .auto, manualCookieHeader: nil))))
        #expect(unavailable == false)

        let fromManual = await strategy.isAvailable(self.makeFetchContext(
            settings: .make(minimax: .init(cookieSource: .manual, manualCookieHeader: "sessionid=abc"))))
        #expect(fromManual == true)
    }

    @Test
    func opencodeCookieSupportRequiresManualHeaderOnLinux() throws {
        let header = try OpenCodeWebCookieSupport.resolveCookieHeader(
            context: .init(
                settings: .init(cookieSource: .manual, manualCookieHeader: "auth=manual-token", workspaceID: nil),
                provider: .opencode,
                browserDetection: BrowserDetection(),
                allowCached: false),
            invalidCookie: OpenCodeSettingsError.invalidCookie,
            missingCookie: OpenCodeSettingsError.missingCookie)
        #expect(header == "auth=manual-token")

        #expect(throws: OpenCodeSettingsError.self) {
            try OpenCodeWebCookieSupport.resolveCookieHeader(
                context: .init(
                    settings: .init(cookieSource: .auto, manualCookieHeader: nil, workspaceID: nil),
                    provider: .opencode,
                    browserDetection: BrowserDetection(),
                    allowCached: false),
                invalidCookie: OpenCodeSettingsError.invalidCookie,
                missingCookie: OpenCodeSettingsError.missingCookie)
        }
    }

    @Test
    func ollamaManualCookieResolverRequiresRecognizedSessionCookie() throws {
        let manual = try #require(try OllamaUsageFetcher.resolveManualCookieHeader(
            override: "session=manual-token",
            manualCookieMode: true))
        #expect(manual == "session=manual-token")

        #expect(throws: OllamaUsageError.self) {
            try OllamaUsageFetcher.resolveManualCookieHeader(
                override: "foo=bar",
                manualCookieMode: true)
        }
    }

    @Test
    func codexWorkspaceIdentityCacheWritesPrivateFilePermissions() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let cacheURL = tempRoot.appendingPathComponent("codex-openai-workspaces.json")
        let cache = CodexOpenAIWorkspaceIdentityCache(fileURL: cacheURL)

        try cache.store(.init(workspaceAccountID: "ws_123", workspaceLabel: "Example Workspace"))

        let attributes = try FileManager.default.attributesOfItem(atPath: cacheURL.path)
        let permissions = try #require(attributes[.posixPermissions] as? NSNumber)
        #expect(permissions.intValue == 0o600)
    }
}
