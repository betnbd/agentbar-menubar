#if canImport(CAgentBarTrayShim)
import AgentBarCore
import CAgentBarTrayShim
import Foundation

private struct AgentBarTrayState {
    let configPath: String
    let config: AgentBarConfig
    let enabledProviders: [UsageProvider]

    var indicatorLabel: String {
        let monitorProviders = self.monitorProviders
        guard let first = monitorProviders.first ?? self.enabledProviders.first else { return "none" }
        if monitorProviders.count == 2 {
            return "Cl -- | Co --"
        }
        if self.enabledProviders.count == 1 {
            return first.rawValue
        }
        return "\(first.rawValue)+\(self.enabledProviders.count - 1)"
    }

    var enabledProvidersLine: String {
        let providers = self.enabledProviders.map(\.rawValue).joined(separator: ", ")
        return "Enabled providers: \(providers.isEmpty ? "none" : providers)"
    }

    var configLine: String {
        "Config: \(self.configPath)"
    }

    static func load() throws -> AgentBarTrayState {
        let store = AgentBarConfigStore()
        let config = try store.loadOrCreateDefault()
        return AgentBarTrayState(
            configPath: store.fileURL.path,
            config: config,
            enabledProviders: config.enabledProviders())
    }

    var monitorProviders: [UsageProvider] {
        self.enabledProviders.filter { $0 == .claude || $0 == .codex }
    }

    var preferredMonitorProvider: UsageProvider? {
        guard let preferredProvider = self.config.tray.preferredProvider else { return nil }
        return self.monitorProviders.contains(preferredProvider) ? preferredProvider : nil
    }
}

private final class AgentBarTrayRenderContext {
    let host: AgentBarTrayHost
    let refreshID: Int
    let indicatorLabel: String
    let recommendationLine: String
    let claudeLine: String
    let codexLine: String
    let statusLine: String
    let renderedIcon: TrayRenderedIcon?

    init(
        host: AgentBarTrayHost,
        refreshID: Int,
        indicatorLabel: String,
        recommendationLine: String,
        claudeLine: String,
        codexLine: String,
        statusLine: String,
        renderedIcon: TrayRenderedIcon?)
    {
        self.host = host
        self.refreshID = refreshID
        self.indicatorLabel = indicatorLabel
        self.recommendationLine = recommendationLine
        self.claudeLine = claudeLine
        self.codexLine = codexLine
        self.statusLine = statusLine
        self.renderedIcon = renderedIcon
    }
}

enum AgentBarTrayHostError: LocalizedError {
    case unavailable
    case initializationFailed
    case unavailableWithReason(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "GNOME tray host is unavailable in the current session."
        case .initializationFailed:
            "Failed to initialize the GNOME tray host."
        case let .unavailableWithReason(reason):
            reason
        }
    }
}

final class AgentBarTrayHost: @unchecked Sendable {
    private static let defaultIndicatorIcon = "utilities-terminal-symbolic"
    private static let statusNotifierWatcherInteractiveGracePeriod: TimeInterval = 8
    private static let statusNotifierWatcherAutostartGracePeriod: TimeInterval = 60
    private static let statusNotifierWatcherPollInterval: TimeInterval = 0.25
    private let indicator: UnsafeMutablePointer<AppIndicator>
    private let menu: UnsafeMutablePointer<GtkWidget>
    private let recommendationItem: UnsafeMutablePointer<GtkWidget>
    private let claudeItem: UnsafeMutablePointer<GtkWidget>
    private let codexItem: UnsafeMutablePointer<GtkWidget>
    private let statusItem: UnsafeMutablePointer<GtkWidget>
    private let openPanelItem: UnsafeMutablePointer<GtkWidget>
    private let refreshItem: UnsafeMutablePointer<GtkWidget>
    private let openConfigItem: UnsafeMutablePointer<GtkWidget>
    private let quitItem: UnsafeMutablePointer<GtkWidget>
    private let alerts = UsageAlertCoordinator(poster: LinuxDesktopNotificationPoster())
    private let trayIconRenderer = TrayIconRenderer()
    private var usagePanel: UsagePanelController?
    private var refreshID = 0

    private init() throws {
        guard agentbar_gtk_init_check() == 1 else {
            throw AgentBarTrayHostError.initializationFailed
        }

        guard let indicator = agentbar_indicator_new(
            AppIdentity.bundleIdentifier,
            Self.defaultIndicatorIcon),
            let menu = agentbar_menu_new(),
            let recommendationItem = agentbar_menu_item_new("Loading usage summary..."),
            let claudeItem = agentbar_menu_item_new("Claude: waiting for data"),
            let codexItem = agentbar_menu_item_new("Codex: waiting for data"),
            let statusItem = agentbar_menu_item_new("Refreshing local provider snapshots..."),
            let openPanelItem = agentbar_menu_item_new("Show Usage"),
            let refreshItem = agentbar_menu_item_new("Refresh"),
            let openConfigItem = agentbar_menu_item_new("Open Config"),
            let quitItem = agentbar_menu_item_new("Quit")
        else {
            throw AgentBarTrayHostError.initializationFailed
        }

        self.indicator = indicator
        self.menu = menu
        self.recommendationItem = recommendationItem
        self.claudeItem = claudeItem
        self.codexItem = codexItem
        self.statusItem = statusItem
        self.openPanelItem = openPanelItem
        self.refreshItem = refreshItem
        self.openConfigItem = openConfigItem
        self.quitItem = quitItem

        agentbar_widget_set_sensitive(self.recommendationItem, 0)
        agentbar_widget_set_sensitive(self.claudeItem, 0)
        agentbar_widget_set_sensitive(self.codexItem, 0)
        agentbar_widget_set_sensitive(self.statusItem, 0)

        let separator = agentbar_separator_menu_item_new()

        agentbar_menu_append(self.menu, self.recommendationItem)
        agentbar_menu_append(self.menu, self.claudeItem)
        agentbar_menu_append(self.menu, self.codexItem)
        agentbar_menu_append(self.menu, self.statusItem)
        if let separator {
            agentbar_menu_append(self.menu, separator)
        }
        agentbar_menu_append(self.menu, self.openPanelItem)
        agentbar_menu_append(self.menu, self.refreshItem)
        agentbar_menu_append(self.menu, self.openConfigItem)
        agentbar_menu_append(self.menu, self.quitItem)

        agentbar_menu_item_connect_activate(
            self.openPanelItem,
            agentBarTrayOpenPanelCallback,
            Unmanaged.passUnretained(self).toOpaque())
        agentbar_menu_item_connect_activate(
            self.refreshItem,
            agentBarTrayRefreshCallback,
            Unmanaged.passUnretained(self).toOpaque())
        agentbar_menu_item_connect_activate(
            self.openConfigItem,
            agentBarTrayOpenConfigCallback,
            Unmanaged.passUnretained(self).toOpaque())
        agentbar_menu_item_connect_activate(
            self.quitItem,
            agentBarTrayQuitCallback,
            Unmanaged.passUnretained(self).toOpaque())

        agentbar_indicator_set_title(self.indicator, AppIdentity.productName)
        agentbar_indicator_set_menu(self.indicator, self.menu)
        agentbar_indicator_set_secondary_activate_target(self.indicator, self.openPanelItem)
        agentbar_indicator_set_status_active(self.indicator)
        agentbar_widget_show_all(self.menu)
        try self.refresh()
    }

    static func runIfAvailable() throws -> Bool {
        let environment = ProcessInfo.processInfo.environment
        guard let availability = self.trayAvailability(environment: environment) else {
            return false
        }
        guard availability.available else {
            throw AgentBarTrayHostError.unavailableWithReason(availability.reason)
        }

        let host = try AgentBarTrayHost()
        host.run()
        return true
    }

    private static func trayAvailability(environment: [String: String]) -> (available: Bool, reason: String)? {
        if environment["AGENTBAR_FORCE_TRAY"] == "1" {
            return (true, "Tray startup forced by AGENTBAR_FORCE_TRAY=1.")
        }

        guard self.hasGraphicalSession(environment: environment) else {
            return nil
        }
        guard !(environment["DBUS_SESSION_BUS_ADDRESS"]?.isEmpty ?? true) else {
            return (
                false,
                "Tray host unavailable: no D-Bus session bus was detected in this graphical session.")
        }
        guard self.statusNotifierWatcherAvailable(environment: environment) else {
            return (
                false,
                """
                Tray host unavailable: org.kde.StatusNotifierWatcher is not present on the session bus. \
                On Ubuntu 26.04 GNOME 50 this usually means the AppIndicator extension is not \
                enabled in the current session. Enable `ubuntu-appindicators@ubuntu.com` in \
                Extension Manager or with `gnome-extensions`, then log out/in.
                """)
        }
        return (true, "Tray host prerequisites are available.")
    }

    private static func hasGraphicalSession(environment: [String: String]) -> Bool {
        !(environment["DISPLAY"]?.isEmpty ?? true) || !(environment["WAYLAND_DISPLAY"]?.isEmpty ?? true)
    }

    private static func statusNotifierWatcherAvailable(environment: [String: String]) -> Bool {
        let deadline = Date().addingTimeInterval(Self.statusNotifierWatcherGracePeriod(environment: environment))
        repeat {
            if self.statusNotifierWatcherAvailableNow(environment: environment) {
                return true
            }

            guard Date() < deadline else {
                break
            }

            Thread.sleep(forTimeInterval: Self.statusNotifierWatcherPollInterval)
        } while true

        return false
    }

    private static func statusNotifierWatcherGracePeriod(environment: [String: String]) -> TimeInterval {
        if let override = environment["AGENTBAR_STATUS_NOTIFIER_WAIT_SECONDS"].flatMap(TimeInterval.init),
           override >= 0
        {
            return override
        }

        if environment["AGENTBAR_AUTOSTART"] == "1" {
            return Self.statusNotifierWatcherAutostartGracePeriod
        }

        return Self.statusNotifierWatcherInteractiveGracePeriod
    }

    private static func statusNotifierWatcherAvailableNow(environment: [String: String]) -> Bool {
        if self.commandSucceeds(
            "gdbus",
            arguments: [
                "introspect",
                "--session",
                "--dest",
                "org.kde.StatusNotifierWatcher",
                "--object-path",
                "/StatusNotifierWatcher",
            ],
            environment: environment)
        {
            return true
        }

        return self.commandSucceeds(
            "busctl",
            arguments: [
                "--user",
                "status",
                "org.kde.StatusNotifierWatcher",
            ],
            environment: environment)
    }

    private static func commandSucceeds(
        _ command: String,
        arguments: [String],
        environment: [String: String])
        -> Bool
    {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + arguments
        process.environment = environment
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func run() {
        agentbar_run_main_loop()
    }

    fileprivate func refresh() throws {
        let state = try AgentBarTrayState.load()
        self.setMenuItem(self.recommendationItem, label: "Refreshing usage summary...")
        self.setMenuItem(
            self.claudeItem,
            label: state.monitorProviders.contains(.claude) ? "Claude: loading..." : "Claude: off")
        self.setMenuItem(
            self.codexItem,
            label: state.monitorProviders.contains(.codex) ? "Codex: loading..." : "Codex: off")
        self.setMenuItem(self.statusItem, label: state.enabledProvidersLine)
        self.setIndicatorLabel(state.indicatorLabel)
        self.usagePanel?.refresh()
        self.refreshUsageSummary(fallbackState: state)
    }

    fileprivate func openCodexPanel() {
        if let usagePanel = self.usagePanel {
            usagePanel.presentAndRefresh()
            return
        }

        self.usagePanel = try? UsagePanelController(host: self)
    }

    func openConfig() {
        let configPath = AgentBarConfigStore.defaultURL().path
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["xdg-open", configPath]
        try? process.run()
    }

    fileprivate func quit() {
        self.usagePanel?.close()
        agentbar_indicator_set_status_passive(self.indicator)
        agentbar_quit_main_loop()
    }

    func panelDidClose(_ panel: UsagePanelController) {
        if self.usagePanel === panel {
            self.usagePanel = nil
        }
    }

    private func setIndicatorLabel(_ label: String) {
        label.withCString { cString in
            agentbar_indicator_set_label(self.indicator, cString)
        }
    }

    private func setIndicatorIcon(_ renderedIcon: TrayRenderedIcon?) {
        guard let renderedIcon else {
            agentbar_indicator_set_icon_theme_path(self.indicator, nil)
            Self.defaultIndicatorIcon.withCString { cString in
                agentbar_indicator_set_icon_full(self.indicator, cString, "AgentBar")
            }
            return
        }

        renderedIcon.themePath.withCString { themePath in
            agentbar_indicator_set_icon_theme_path(self.indicator, themePath)
        }
        renderedIcon.iconName.withCString { iconName in
            renderedIcon.description.withCString { description in
                agentbar_indicator_set_icon_full(self.indicator, iconName, description)
            }
        }
    }

    private func setMenuItem(_ menuItem: UnsafeMutablePointer<GtkWidget>, label: String) {
        label.withCString { cString in
            agentbar_menu_item_set_label(menuItem, cString)
        }
    }

    private func refreshUsageSummary(fallbackState: AgentBarTrayState) {
        self.refreshID += 1
        let refreshID = self.refreshID

        Task {
            let snapshot = await SessionMonitorSnapshot.load(configuredProviders: fallbackState.monitorProviders)
            let indicatorLabel = self.indicatorLabel(snapshot: snapshot, fallbackState: fallbackState)
            let renderedIcon: TrayRenderedIcon? = if fallbackState.config.tray.iconMode == .remainingCircle,
                                                     let iconSnapshot = DualProviderMonitor.trayUsageIconSnapshot(
                                                         snapshots: snapshot.providers.values.map(\.monitor),
                                                         selectedProvider: fallbackState.preferredMonitorProvider)
            {
                self.trayIconRenderer.render(snapshot: iconSnapshot)
            } else {
                nil
            }
            let recommendationLine = snapshot.recommendation?.summary
                .replacingOccurrences(of: "Best tool now:", with: "Recommendation:")
                ?? "Recommendation: waiting for live data"
            let claudeLine = self.providerMenuLine(
                provider: .claude,
                snapshot: snapshot.providers[.claude],
                configured: fallbackState.monitorProviders.contains(.claude))
            let codexLine = self.providerMenuLine(
                provider: .codex,
                snapshot: snapshot.providers[.codex],
                configured: fallbackState.monitorProviders.contains(.codex))
            let statusLine = self.statusMenuLine(snapshot: snapshot, fallbackState: fallbackState)

            let context = AgentBarTrayRenderContext(
                host: self,
                refreshID: refreshID,
                indicatorLabel: indicatorLabel,
                recommendationLine: recommendationLine,
                claudeLine: claudeLine,
                codexLine: codexLine,
                statusLine: statusLine,
                renderedIcon: renderedIcon)
            self.alerts.process(
                snapshot: snapshot,
                config: fallbackState.config.notifications)
            agentbar_invoke_on_main_thread(
                agentBarTrayApplyRenderCallback,
                Unmanaged.passRetained(context).toOpaque())
        }
    }

    fileprivate func apply(renderContext: AgentBarTrayRenderContext) {
        guard renderContext.refreshID == self.refreshID else { return }
        self.setIndicatorLabel(renderContext.indicatorLabel)
        self.setIndicatorIcon(renderContext.renderedIcon)
        self.setMenuItem(self.recommendationItem, label: renderContext.recommendationLine)
        self.setMenuItem(self.claudeItem, label: renderContext.claudeLine)
        self.setMenuItem(self.codexItem, label: renderContext.codexLine)
        self.setMenuItem(self.statusItem, label: renderContext.statusLine)
    }

    private func indicatorLabel(
        snapshot: SessionMonitorSnapshot,
        fallbackState: AgentBarTrayState,
        now: Date = Date())
        -> String
    {
        let snapshots = snapshot.providers.values.map(\.monitor)
        if fallbackState.monitorProviders.count == 2 {
            let claudeText = self.compactIndicatorSegment(
                provider: .claude,
                snapshot: snapshot.providers[.claude]?.monitor,
                configured: true,
                now: now)
            let codexText = self.compactIndicatorSegment(
                provider: .codex,
                snapshot: snapshot.providers[.codex]?.monitor,
                configured: true,
                now: now)
            return "\(claudeText) | \(codexText)"
        }

        return DualProviderMonitor.trayLabel(
            snapshots: snapshots,
            mode: fallbackState.config.tray.displayMode,
            selectedProvider: fallbackState.preferredMonitorProvider,
            now: now)
            ?? fallbackState.indicatorLabel
    }

    private func compactIndicatorSegment(
        provider: UsageProvider,
        snapshot: ProviderMonitorSnapshot?,
        configured: Bool,
        now _: Date)
        -> String
    {
        let short = provider == .claude ? "Cl" : "Co"
        guard configured else { return "\(short) off" }
        guard let snapshot, let window = snapshot.primary else { return "\(short) --" }
        let percent = Int(window.remainingPercent.rounded())
        if percent <= 15,
           let resetLine = UsageFormatter.resetLine(for: window, style: .countdown)
        {
            let trimmed = resetLine
                .replacingOccurrences(of: "Resets in ", with: "")
                .replacingOccurrences(of: "Resets ", with: "")
            return "\(short) \(percent)%/\(trimmed)"
        }
        return "\(short) \(percent)%"
    }

    private func providerMenuLine(
        provider: UsageProvider,
        snapshot: SessionMonitorProviderSnapshot?,
        configured: Bool,
        now: Date = Date())
        -> String
    {
        let name = ProviderDefaults.metadata[provider]?.displayName ?? provider.rawValue.capitalized
        guard configured else { return "\(name): off" }
        guard let snapshot else { return "\(name): loading local data..." }
        guard let primary = snapshot.monitor.primary else {
            if !snapshot.statusMessages.isEmpty {
                return "\(name): \(snapshot.statusMessages.joined(separator: " | "))"
            }
            return "\(name): enabled, waiting for local data"
        }
        let line = ProviderMonitorDisplayFormatter.summaryLine(
            for: snapshot.monitor,
            sessionCostUSD: snapshot.monitor.tokenUsage?.sessionCostUSD,
            creditsRemaining: snapshot.monitor.creditsRemaining,
            now: now)
        return line ?? "\(name): \(Int(primary.remainingPercent.rounded()))% left"
    }

    private func statusMenuLine(
        snapshot: SessionMonitorSnapshot,
        fallbackState: AgentBarTrayState,
        now: Date = Date())
        -> String
    {
        let available = snapshot.availableProviders
        if available.isEmpty {
            return "No live Claude or Codex data yet"
        }

        let freshness = available.compactMap { provider -> String? in
            guard let providerSnapshot = snapshot.providers[provider] else { return nil }
            let updated = UsageFormatter.updatedString(from: providerSnapshot.monitor.updatedAt, now: now)
            let name = ProviderDefaults.metadata[provider]?.displayName ?? provider.rawValue.capitalized
            return "\(name) \(updated.replacingOccurrences(of: "Updated ", with: ""))"
        }
        if freshness.count == 2,
           freshness.allSatisfy({ $0.hasSuffix("just now") })
        {
            return "Both providers are fresh now"
        }
        if !freshness.isEmpty {
            return freshness.joined(separator: " | ")
        }
        return fallbackState.enabledProvidersLine
    }
}

private func agentBarTrayRefreshCallback(_ context: UnsafeMutableRawPointer?) {
    guard let context else { return }
    let host = Unmanaged<AgentBarTrayHost>.fromOpaque(context).takeUnretainedValue()
    try? host.refresh()
}

private func agentBarTrayOpenPanelCallback(_ context: UnsafeMutableRawPointer?) {
    guard let context else { return }
    let host = Unmanaged<AgentBarTrayHost>.fromOpaque(context).takeUnretainedValue()
    host.openCodexPanel()
}

private func agentBarTrayOpenConfigCallback(_ context: UnsafeMutableRawPointer?) {
    guard let context else { return }
    let host = Unmanaged<AgentBarTrayHost>.fromOpaque(context).takeUnretainedValue()
    host.openConfig()
}

private func agentBarTrayQuitCallback(_ context: UnsafeMutableRawPointer?) {
    guard let context else { return }
    let host = Unmanaged<AgentBarTrayHost>.fromOpaque(context).takeUnretainedValue()
    host.quit()
}

private func agentBarTrayApplyRenderCallback(_ context: UnsafeMutableRawPointer?) {
    guard let context else { return }
    let renderContext = Unmanaged<AgentBarTrayRenderContext>.fromOpaque(context).takeRetainedValue()
    renderContext.host.apply(renderContext: renderContext)
}
#endif
