import AgentBarCore
import CAgentBarTrayShim
import Foundation

private struct UsagePanelViewState {
    let title: String
    let subtitle: String
    let overviewHeader: String
    let nowHeader: String
    let horizonHeader: String
    let spendHeader: String
    let primaryUsage: String
    let secondaryUsage: String
    let tertiaryUsage: String
    let pace: String
    let creditsOrCost: String
    let monthlyCost: String
    let history: String
    let models: String
    let updated: String
    let recommendation: String
    let status: String

    static let loading = UsagePanelViewState(
        title: "AgentBar",
        subtitle: "Loading Claude and Codex usage data...",
        overviewHeader: "Dual Provider Monitor",
        nowHeader: "Live Windows",
        horizonHeader: "Pace and Headroom",
        spendHeader: "Usage and Spend",
        primaryUsage: "Session: loading...",
        secondaryUsage: "Weekly: loading...",
        tertiaryUsage: "",
        pace: "",
        creditsOrCost: "Today: loading...",
        monthlyCost: "Last 30d: loading...",
        history: "7d average: loading...",
        models: "",
        updated: "Updated: loading...",
        recommendation: "Recommendation: loading...",
        status: "")
}

private enum UsagePanelTheme {
    static let css = """
    window#agentbar-panel-window {
        background-color: #091626;
        color: #eff7ff;
    }

    scrolledwindow#agentbar-panel-scroll {
        background: transparent;
    }

    box#panel-content {
        padding: 18px;
    }

    box.card {
        background: rgba(7, 18, 33, 0.78);
        border: 1px solid rgba(118, 168, 224, 0.24);
        border-radius: 18px;
        padding: 16px;
    }

    box.hero-card {
        background: rgba(20, 70, 118, 0.92);
        border: 1px solid rgba(106, 190, 255, 0.35);
    }

    button.provider-tab {
        background: rgba(255, 255, 255, 0.05);
        border: 1px solid rgba(118, 168, 224, 0.18);
        border-radius: 999px;
        color: #c7ddf6;
        padding: 8px 14px;
    }

    button.provider-tab.selected {
        background: #1363b2;
        border-color: rgba(148, 213, 255, 0.7);
        color: #ffffff;
    }

    button.provider-tab:disabled {
        color: rgba(199, 221, 246, 0.45);
    }

    button.footer-action {
        background: rgba(255, 255, 255, 0.06);
        border: 1px solid rgba(118, 168, 224, 0.22);
        border-radius: 12px;
        color: #eff7ff;
        padding: 9px 14px;
    }
    """
}

private final class UsagePanelRenderContext {
    let controller: UsagePanelController
    let refreshID: Int
    let snapshot: SessionMonitorSnapshot

    init(controller: UsagePanelController, refreshID: Int, snapshot: SessionMonitorSnapshot) {
        self.controller = controller
        self.refreshID = refreshID
        self.snapshot = snapshot
    }
}

private struct UsagePanelContainers {
    let window: UnsafeMutablePointer<GtkWidget>
    let scroll: UnsafeMutablePointer<GtkWidget>
    let root: UnsafeMutablePointer<GtkWidget>
    let providerRow: UnsafeMutablePointer<GtkWidget>
    let heroCard: UnsafeMutablePointer<GtkWidget>
    let overviewCard: UnsafeMutablePointer<GtkWidget>
    let spendCard: UnsafeMutablePointer<GtkWidget>
    let buttonRow: UnsafeMutablePointer<GtkWidget>
}

final class UsagePanelController: @unchecked Sendable {
    private unowned let host: AgentBarTrayHost
    private let window: UnsafeMutablePointer<GtkWidget>
    private let claudeButton: UnsafeMutablePointer<GtkWidget>
    private let codexButton: UnsafeMutablePointer<GtkWidget>
    private let titleLabel: UnsafeMutablePointer<GtkWidget>
    private let subtitleLabel: UnsafeMutablePointer<GtkWidget>
    private let overviewHeaderLabel: UnsafeMutablePointer<GtkWidget>
    private let nowHeaderLabel: UnsafeMutablePointer<GtkWidget>
    private let horizonHeaderLabel: UnsafeMutablePointer<GtkWidget>
    private let spendHeaderLabel: UnsafeMutablePointer<GtkWidget>
    private let primaryUsageLabel: UnsafeMutablePointer<GtkWidget>
    private let secondaryUsageLabel: UnsafeMutablePointer<GtkWidget>
    private let tertiaryUsageLabel: UnsafeMutablePointer<GtkWidget>
    private let paceLabel: UnsafeMutablePointer<GtkWidget>
    private let creditsOrCostLabel: UnsafeMutablePointer<GtkWidget>
    private let monthlyCostLabel: UnsafeMutablePointer<GtkWidget>
    private let historyLabel: UnsafeMutablePointer<GtkWidget>
    private let modelsLabel: UnsafeMutablePointer<GtkWidget>
    private let updatedLabel: UnsafeMutablePointer<GtkWidget>
    private let recommendationLabel: UnsafeMutablePointer<GtkWidget>
    private let statusLabel: UnsafeMutablePointer<GtkWidget>
    private let refreshButton: UnsafeMutablePointer<GtkWidget>
    private let openConfigButton: UnsafeMutablePointer<GtkWidget>
    private var refreshID = 0
    private var isClosed = false
    private var isRefreshing = false
    private var pendingRefresh = false
    private var latestSnapshot: SessionMonitorSnapshot?
    private var selectedProvider: UsageProvider = .codex

    init(host: AgentBarTrayHost) throws {
        self.host = host

        guard
            let window = agentbar_window_new("AgentBar Usage", 430, 760),
            let scroll = agentbar_scrolled_window_new(),
            let root = agentbar_box_new_vertical(16),
            let providerRow = agentbar_box_new_horizontal(8),
            let heroCard = agentbar_box_new_vertical(8),
            let overviewCard = agentbar_box_new_vertical(8),
            let spendCard = agentbar_box_new_vertical(8),
            let claudeButton = agentbar_button_new("Claude"),
            let codexButton = agentbar_button_new("Codex"),
            let titleLabel = agentbar_label_new(""),
            let subtitleLabel = agentbar_label_new(""),
            let overviewHeaderLabel = agentbar_label_new(""),
            let nowHeaderLabel = agentbar_label_new(""),
            let horizonHeaderLabel = agentbar_label_new(""),
            let spendHeaderLabel = agentbar_label_new(""),
            let primaryUsageLabel = agentbar_label_new(""),
            let secondaryUsageLabel = agentbar_label_new(""),
            let tertiaryUsageLabel = agentbar_label_new(""),
            let paceLabel = agentbar_label_new(""),
            let creditsOrCostLabel = agentbar_label_new(""),
            let monthlyCostLabel = agentbar_label_new(""),
            let historyLabel = agentbar_label_new(""),
            let modelsLabel = agentbar_label_new(""),
            let updatedLabel = agentbar_label_new(""),
            let recommendationLabel = agentbar_label_new(""),
            let statusLabel = agentbar_label_new(""),
            let buttonRow = agentbar_box_new_horizontal(8),
            let refreshButton = agentbar_button_new("Refresh"),
            let openConfigButton = agentbar_button_new("Open Config")
        else {
            throw AgentBarTrayHostError.initializationFailed
        }

        self.window = window
        self.claudeButton = claudeButton
        self.codexButton = codexButton
        self.titleLabel = titleLabel
        self.subtitleLabel = subtitleLabel
        self.overviewHeaderLabel = overviewHeaderLabel
        self.nowHeaderLabel = nowHeaderLabel
        self.horizonHeaderLabel = horizonHeaderLabel
        self.spendHeaderLabel = spendHeaderLabel
        self.primaryUsageLabel = primaryUsageLabel
        self.secondaryUsageLabel = secondaryUsageLabel
        self.tertiaryUsageLabel = tertiaryUsageLabel
        self.paceLabel = paceLabel
        self.creditsOrCostLabel = creditsOrCostLabel
        self.monthlyCostLabel = monthlyCostLabel
        self.historyLabel = historyLabel
        self.modelsLabel = modelsLabel
        self.updatedLabel = updatedLabel
        self.recommendationLabel = recommendationLabel
        self.statusLabel = statusLabel
        self.refreshButton = refreshButton
        self.openConfigButton = openConfigButton

        let containers = UsagePanelContainers(
            window: window,
            scroll: scroll,
            root: root,
            providerRow: providerRow,
            heroCard: heroCard,
            overviewCard: overviewCard,
            spendCard: spendCard,
            buttonRow: buttonRow)

        self.configureWindowStyles(containers: containers)
        for label in [
            titleLabel,
            subtitleLabel,
            overviewHeaderLabel,
            nowHeaderLabel,
            horizonHeaderLabel,
            spendHeaderLabel,
            primaryUsageLabel,
            secondaryUsageLabel,
            tertiaryUsageLabel,
            paceLabel,
            creditsOrCostLabel,
            monthlyCostLabel,
            historyLabel,
            modelsLabel,
            updatedLabel,
            recommendationLabel,
            statusLabel,
        ] {
            agentbar_label_set_xalign(label, 0)
            agentbar_label_set_line_wrap(label, 1)
        }

        self.buildLayout(containers: containers)
        agentbar_button_connect_clicked(
            claudeButton,
            agentBarPanelSelectClaudeCallback,
            Unmanaged.passUnretained(self).toOpaque())
        agentbar_button_connect_clicked(
            codexButton,
            agentBarPanelSelectCodexCallback,
            Unmanaged.passUnretained(self).toOpaque())
        agentbar_button_connect_clicked(
            refreshButton,
            agentBarPanelRefreshCallback,
            Unmanaged.passUnretained(self).toOpaque())
        agentbar_button_connect_clicked(
            openConfigButton,
            agentBarPanelOpenConfigCallback,
            Unmanaged.passUnretained(self).toOpaque())
        agentbar_window_connect_destroy(
            window,
            agentBarPanelDestroyCallback,
            Unmanaged.passUnretained(self).toOpaque())

        self.apply(state: .loading)
        self.updateProviderButtons(snapshot: nil)
        agentbar_widget_show_all(window)
        agentbar_window_present(window)
        self.refresh()
    }

    private func configureWindowStyles(containers: UsagePanelContainers) {
        agentbar_css_load(UsagePanelTheme.css)
        agentbar_widget_set_name(containers.window, "agentbar-panel-window")
        agentbar_window_set_resizable(containers.window, 1)
        agentbar_widget_set_name(containers.scroll, "agentbar-panel-scroll")
        agentbar_widget_set_hexpand(containers.scroll, 1)
        agentbar_widget_set_vexpand(containers.scroll, 1)
        agentbar_widget_set_name(containers.root, "panel-content")
        agentbar_widget_set_margin_all(containers.root, 16)
        agentbar_widget_add_css_class(containers.heroCard, "card")
        agentbar_widget_add_css_class(containers.heroCard, "hero-card")
        agentbar_widget_add_css_class(containers.overviewCard, "card")
        agentbar_widget_add_css_class(containers.spendCard, "card")
        agentbar_widget_add_css_class(self.claudeButton, "provider-tab")
        agentbar_widget_add_css_class(self.codexButton, "provider-tab")
        agentbar_widget_add_css_class(self.refreshButton, "footer-action")
        agentbar_widget_add_css_class(self.openConfigButton, "footer-action")
        agentbar_widget_set_hexpand(self.claudeButton, 1)
        agentbar_widget_set_hexpand(self.codexButton, 1)
        agentbar_widget_set_hexpand(self.refreshButton, 1)
        agentbar_widget_set_hexpand(self.openConfigButton, 1)
        agentbar_widget_set_can_focus(self.claudeButton, 0)
        agentbar_widget_set_can_focus(self.codexButton, 0)
        agentbar_widget_set_can_focus(self.refreshButton, 0)
        agentbar_widget_set_can_focus(self.openConfigButton, 0)
        agentbar_button_set_focus_on_click(self.claudeButton, 0)
        agentbar_button_set_focus_on_click(self.codexButton, 0)
        agentbar_button_set_focus_on_click(self.refreshButton, 0)
        agentbar_button_set_focus_on_click(self.openConfigButton, 0)
    }

    private func buildLayout(containers: UsagePanelContainers) {
        agentbar_box_append(containers.providerRow, self.claudeButton, 0)
        agentbar_box_append(containers.providerRow, self.codexButton, 0)
        agentbar_box_append(containers.heroCard, containers.providerRow, 0)
        agentbar_box_append(containers.heroCard, self.titleLabel, 0)
        agentbar_box_append(containers.heroCard, self.subtitleLabel, 0)
        agentbar_box_append(containers.heroCard, self.overviewHeaderLabel, 0)
        agentbar_box_append(containers.heroCard, self.recommendationLabel, 0)
        agentbar_box_append(containers.heroCard, self.updatedLabel, 0)
        agentbar_box_append(containers.heroCard, self.statusLabel, 0)
        agentbar_box_append(containers.overviewCard, self.nowHeaderLabel, 0)
        agentbar_box_append(containers.overviewCard, self.primaryUsageLabel, 0)
        agentbar_box_append(containers.overviewCard, self.secondaryUsageLabel, 0)
        agentbar_box_append(containers.overviewCard, self.horizonHeaderLabel, 0)
        agentbar_box_append(containers.overviewCard, self.tertiaryUsageLabel, 0)
        agentbar_box_append(containers.overviewCard, self.paceLabel, 0)
        agentbar_box_append(containers.spendCard, self.spendHeaderLabel, 0)
        agentbar_box_append(containers.spendCard, self.creditsOrCostLabel, 0)
        agentbar_box_append(containers.spendCard, self.monthlyCostLabel, 0)
        agentbar_box_append(containers.spendCard, self.historyLabel, 0)
        agentbar_box_append(containers.spendCard, self.modelsLabel, 0)
        agentbar_box_append(containers.root, containers.heroCard, 0)
        agentbar_box_append(containers.root, containers.overviewCard, 0)
        agentbar_box_append(containers.root, containers.spendCard, 0)
        agentbar_box_append(containers.root, containers.buttonRow, 0)
        agentbar_box_append(containers.buttonRow, self.refreshButton, 0)
        agentbar_box_append(containers.buttonRow, self.openConfigButton, 0)
        agentbar_scrolled_window_set_child(containers.scroll, containers.root)
        agentbar_window_set_child(containers.window, containers.scroll)
    }

    func presentAndRefresh() {
        guard !self.isClosed else { return }
        agentbar_window_present(self.window)
        self.refresh()
    }

    func refresh() {
        guard !self.isClosed else { return }
        guard !self.isRefreshing else {
            self.pendingRefresh = true
            self.applyRefreshState()
            return
        }

        self.isRefreshing = true
        self.refreshID += 1
        let refreshID = self.refreshID
        self.applyRefreshState()

        Task {
            let snapshot = await SessionMonitorSnapshot.load(
                configuredProviders: self.configuredMonitorProviders())
            let context = UsagePanelRenderContext(controller: self, refreshID: refreshID, snapshot: snapshot)
            agentbar_invoke_on_main_thread(
                agentBarPanelApplyRenderCallback,
                Unmanaged.passRetained(context).toOpaque())
        }
    }

    func openConfig() {
        self.host.openConfig()
    }

    func close() {
        guard !self.isClosed else { return }
        agentbar_widget_destroy(self.window)
    }

    func handleWindowDestroyed() {
        self.isClosed = true
        self.host.panelDidClose(self)
    }

    func select(provider: UsageProvider) {
        self.selectedProvider = provider
        self.applyLatestSnapshot()
    }

    fileprivate func apply(snapshot: SessionMonitorSnapshot, refreshID: Int) {
        guard !self.isClosed, refreshID == self.refreshID else { return }
        self.isRefreshing = false
        self.latestSnapshot = snapshot
        if !snapshot.availableProviders.contains(self.selectedProvider),
           let preferred = self.preferredProvider(from: snapshot)
        {
            self.selectedProvider = preferred
        }
        self.applyLatestSnapshot()
        if self.pendingRefresh {
            self.pendingRefresh = false
            self.refresh()
        }
    }

    private func applyLatestSnapshot() {
        guard let latestSnapshot else { return }
        self.updateProviderButtons(snapshot: latestSnapshot)
        let state = self.makeViewState(snapshot: latestSnapshot)
        self.apply(state: self.decorate(state: state))
    }

    private func applyRefreshState() {
        guard let latestSnapshot else {
            self.apply(state: .loading)
            return
        }
        self.updateProviderButtons(snapshot: latestSnapshot)
        let state = self.makeViewState(snapshot: latestSnapshot)
        self.apply(state: self.decorate(state: state))
    }

    private func decorate(state: UsagePanelViewState) -> UsagePanelViewState {
        guard self.isRefreshing else { return state }
        let refreshStatus = self.pendingRefresh
            ? "Refresh queued after current load."
            : "Refreshing local usage data..."
        return UsagePanelViewState(
            title: state.title,
            subtitle: state.subtitle,
            overviewHeader: state.overviewHeader,
            nowHeader: state.nowHeader,
            horizonHeader: state.horizonHeader,
            spendHeader: state.spendHeader,
            primaryUsage: state.primaryUsage,
            secondaryUsage: state.secondaryUsage,
            tertiaryUsage: state.tertiaryUsage,
            pace: state.pace,
            creditsOrCost: state.creditsOrCost,
            monthlyCost: state.monthlyCost,
            history: state.history,
            models: state.models,
            updated: state.updated,
            recommendation: state.recommendation,
            status: state.status.isEmpty ? refreshStatus : "\(refreshStatus) \(state.status)")
    }

    fileprivate func apply(state: UsagePanelViewState) {
        self.setMarkupLabel(self.titleLabel, markup: self.titleMarkup(state.title))
        self.setMarkupLabel(self.subtitleLabel, markup: self.bodyMarkup(state.subtitle, alpha: "78%"))
        self.setHeader(self.overviewHeaderLabel, text: state.overviewHeader)
        self.setHeader(self.nowHeaderLabel, text: state.nowHeader)
        self.setHeader(self.horizonHeaderLabel, text: state.horizonHeader)
        self.setHeader(self.spendHeaderLabel, text: state.spendHeader)
        self.setMarkupLabel(self.primaryUsageLabel, markup: self.metricMarkup(state.primaryUsage))
        self.setMarkupLabel(self.secondaryUsageLabel, markup: self.metricMarkup(state.secondaryUsage))
        self.setMarkupLabel(self.tertiaryUsageLabel, markup: self.metricMarkup(state.tertiaryUsage))
        self.setMarkupLabel(self.paceLabel, markup: self.metricMarkup(state.pace))
        self.setMarkupLabel(self.creditsOrCostLabel, markup: self.metricMarkup(state.creditsOrCost))
        self.setMarkupLabel(self.monthlyCostLabel, markup: self.metricMarkup(state.monthlyCost))
        self.setMarkupLabel(self.historyLabel, markup: self.metricMarkup(state.history))
        self.setMarkupLabel(self.modelsLabel, markup: self.metricMarkup(state.models))
        self.setMarkupLabel(self.updatedLabel, markup: self.bodyMarkup(state.updated, alpha: "76%"))
        self.setMarkupLabel(self.recommendationLabel, markup: self.calloutMarkup(state.recommendation))
        self.setMarkupLabel(self.statusLabel, markup: self.bodyMarkup(state.status, alpha: "72%"))
        agentbar_widget_set_sensitive(self.refreshButton, self.isRefreshing ? 0 : 1)
        agentbar_widget_set_sensitive(self.openConfigButton, 1)
    }

    private func makeViewState(snapshot: SessionMonitorSnapshot, now: Date = Date()) -> UsagePanelViewState {
        let providerSnapshot = snapshot.providers[self.selectedProvider]
        let providerName = ProviderDefaults.metadata[self.selectedProvider]?.displayName
            ?? self.selectedProvider.rawValue.capitalized
        let recommendation = self.recommendationLine(from: snapshot.recommendation)
        guard let providerSnapshot else {
            return UsagePanelViewState(
                title: providerName,
                subtitle: "No live provider snapshot available yet.",
                overviewHeader: "Dual Provider Monitor",
                nowHeader: "Live Windows",
                horizonHeader: "Pace and Headroom",
                spendHeader: "Usage and Spend",
                primaryUsage: "Session: unavailable",
                secondaryUsage: "Weekly: unavailable",
                tertiaryUsage: "",
                pace: "",
                creditsOrCost: "Today: unavailable",
                monthlyCost: "Last 30d: unavailable",
                history: "7d average: unavailable",
                models: "",
                updated: "Updated: unavailable",
                recommendation: recommendation,
                status: "No live \(providerName) snapshot yet.")
        }

        return UsagePanelViewState(
            title: providerName,
            subtitle: self.subtitleLine(for: providerSnapshot),
            overviewHeader: "Dual Provider Monitor",
            nowHeader: "Live Windows",
            horizonHeader: "Pace and Headroom",
            spendHeader: "Usage and Spend",
            primaryUsage: self.windowLine(
                providerSnapshot.monitor.primary,
                fallbackTitle: ProviderDefaults.metadata[self.selectedProvider]?.sessionLabel ?? "Session"),
            secondaryUsage: self.windowLine(
                providerSnapshot.monitor.secondary,
                fallbackTitle: ProviderDefaults.metadata[self.selectedProvider]?.weeklyLabel ?? "Weekly"),
            tertiaryUsage: self.tertiaryLine(for: providerSnapshot),
            pace: self.paceLine(for: providerSnapshot.monitor, now: now),
            creditsOrCost: self.creditsOrCostLine(for: providerSnapshot),
            monthlyCost: self.monthlyCostLine(for: providerSnapshot),
            history: self.historyLine(for: providerSnapshot),
            models: self.modelsLine(for: providerSnapshot),
            updated: self.freshnessLine(for: providerSnapshot.monitor, now: now),
            recommendation: recommendation,
            status: self.statusLine(for: providerSnapshot, in: snapshot, now: now))
    }

    private func subtitleLine(for snapshot: SessionMonitorProviderSnapshot) -> String {
        ProviderMonitorDisplayFormatter.subtitle(
            for: snapshot.provider,
            identity: snapshot.monitor.identity,
            fallbackDisplayName: snapshot.monitor.displayName)
    }

    private func windowLine(_ window: RateWindow?, fallbackTitle: String) -> String {
        guard let window else { return "\(fallbackTitle): unavailable" }
        let remaining = Int(window.remainingPercent.rounded())
        var line = "\(fallbackTitle): \(remaining)% left"
        if let resetLine = UsageFormatter.resetLine(for: window, style: .countdown) {
            line += " | \(resetLine.replacingOccurrences(of: "Resets ", with: ""))"
        }
        return line
    }

    private func tertiaryLine(for snapshot: SessionMonitorProviderSnapshot) -> String {
        if self.selectedProvider == .claude {
            let title = ProviderDefaults.metadata[.claude]?.opusLabel ?? "Opus"
            return self.windowLine(snapshot.monitor.tertiary, fallbackTitle: title)
        }

        if let creditsRemaining = snapshot.monitor.creditsRemaining {
            return "Credits: \(UsageFormatter.creditsString(from: creditsRemaining))"
        }

        if let creditsFailure = snapshot.credits?.failureMessage {
            return "Credits: \(creditsFailure)"
        }

        return ""
    }

    private func creditsOrCostLine(for snapshot: SessionMonitorProviderSnapshot) -> String {
        if let cost = snapshot.monitor.tokenUsage {
            let parts = [
                cost.sessionCostUSD.map(UsageFormatter.usdString),
                cost.sessionTokens.map { "\(UsageFormatter.tokenCountString($0)) tokens" },
            ]
                .compactMap(\.self)

            if !parts.isEmpty {
                return "Today: \(parts.joined(separator: " | "))"
            }
        }

        if let failure = snapshot.cost.failureMessage {
            return "Today: \(failure)"
        }
        return "Today: no cost data"
    }

    private func monthlyCostLine(for snapshot: SessionMonitorProviderSnapshot) -> String {
        if let cost = snapshot.monitor.tokenUsage {
            let parts = [
                cost.last30DaysCostUSD.map(UsageFormatter.usdString),
                cost.last30DaysTokens.map { "\(UsageFormatter.tokenCountString($0)) tokens" },
            ]
                .compactMap(\.self)
            if !parts.isEmpty {
                return "Last 30d: \(parts.joined(separator: " | "))"
            }
        }

        if let failure = snapshot.cost.failureMessage {
            return "Last 30d: \(failure)"
        }
        return "Last 30d: no cost data yet"
    }

    private func historyLine(for snapshot: SessionMonitorProviderSnapshot) -> String {
        guard let cost = snapshot.monitor.tokenUsage else {
            return "7d average: unavailable"
        }

        let recent = cost.daily.sorted { $0.date < $1.date }.suffix(7)
        guard !recent.isEmpty else { return "7d average: unavailable" }
        let totalTokens = recent.compactMap(\.totalTokens).reduce(0, +)
        let averageTokens = totalTokens / max(recent.count, 1)
        let peakDayTokens = recent.compactMap(\.totalTokens).max() ?? 0
        return "7d average: \(UsageFormatter.tokenCountString(averageTokens)) / day | peak "
            + "\(UsageFormatter.tokenCountString(peakDayTokens))"
    }

    private func modelsLine(for snapshot: SessionMonitorProviderSnapshot) -> String {
        guard let latestDay = snapshot.monitor.tokenUsage?.daily.max(by: { $0.date < $1.date }) else {
            return "Models: unavailable"
        }

        let breakdowns = (latestDay.modelBreakdowns ?? [])
            .sorted { lhs, rhs in
                let left = lhs.totalTokens ?? 0
                let right = rhs.totalTokens ?? 0
                if left != right { return left > right }
                return lhs.modelName < rhs.modelName
            }
            .prefix(2)

        if !breakdowns.isEmpty {
            let entries = breakdowns.compactMap { breakdown -> String? in
                let name = UsageFormatter.modelDisplayName(breakdown.modelName)
                let detail = UsageFormatter.modelCostDetail(
                    breakdown.modelName,
                    costUSD: breakdown.costUSD,
                    totalTokens: breakdown.totalTokens)
                if let detail {
                    return "\(name) (\(detail))"
                }
                return name
            }
            return "Top model: \(entries.joined(separator: " | "))"
        }

        if let modelsUsed = latestDay.modelsUsed, !modelsUsed.isEmpty {
            let names = modelsUsed.prefix(2).map(UsageFormatter.modelDisplayName)
            return "Top model: \(names.joined(separator: " | "))"
        }

        return ""
    }

    private func statusLine(
        for snapshot: SessionMonitorProviderSnapshot,
        in sessionSnapshot: SessionMonitorSnapshot,
        now: Date)
        -> String
    {
        let otherProvider: UsageProvider = snapshot.provider == .codex ? .claude : .codex
        if let otherSnapshot = sessionSnapshot.providers[otherProvider], otherSnapshot.hasAnyData {
            return self.comparisonLine(for: otherSnapshot.monitor, now: now)
        }

        guard !snapshot.statusMessages.isEmpty else { return "" }
        return snapshot.statusMessages.joined(separator: " | ")
    }

    private func comparisonLine(for snapshot: ProviderMonitorSnapshot, now: Date) -> String {
        let name = ProviderDefaults.metadata[snapshot.provider]?.displayName ?? snapshot.provider.rawValue.capitalized
        guard let primary = snapshot.primary else {
            return "\(name): enabled"
        }
        let line = ProviderMonitorDisplayFormatter.summaryLine(for: snapshot, now: now)
        return line ?? "\(name): \(Int(primary.remainingPercent.rounded()))% left"
    }

    private func paceLine(for snapshot: ProviderMonitorSnapshot, now: Date) -> String {
        let summary = DualProviderMonitor.paceSummary(snapshot: snapshot, now: now) ?? "Pace: unavailable"
        if let forecast = DualProviderMonitor.paceForecastSummary(snapshot: snapshot, now: now) {
            return "\(summary) | \(forecast.replacingOccurrences(of: "Forecast: ", with: ""))"
        }
        return summary
    }

    private func freshnessLine(for snapshot: ProviderMonitorSnapshot, now: Date) -> String {
        let updated = UsageFormatter.updatedString(from: snapshot.updatedAt, now: now)
        let ageHours = max(0, now.timeIntervalSince(snapshot.updatedAt) / (60 * 60))
        let qualifier = if ageHours <= 1 {
            "fresh"
        } else if ageHours <= 6 {
            "usable"
        } else if ageHours <= 12 {
            "aging"
        } else {
            "stale"
        }
        return "\(updated) | \(qualifier)"
    }

    private func recommendationLine(from recommendation: ProviderRecommendation?) -> String {
        guard let recommendation else { return "Recommendation: waiting for live data" }
        return recommendation.summary.replacingOccurrences(of: "Best tool now:", with: "Recommended now:")
    }

    private func updateProviderButtons(snapshot: SessionMonitorSnapshot?) {
        let claudeEnabled = snapshot?.configuredProviders.contains(.claude) ?? true
        let codexEnabled = snapshot?.configuredProviders.contains(.codex) ?? true
        let claudeLoaded = snapshot?.providers[.claude]?.hasAnyData ?? false
        let codexLoaded = snapshot?.providers[.codex]?.hasAnyData ?? false

        self.setButton(
            self.claudeButton,
            provider: .claude,
            enabled: claudeEnabled,
            loaded: claudeLoaded)
        self.setButton(
            self.codexButton,
            provider: .codex,
            enabled: codexEnabled,
            loaded: codexLoaded)
    }

    private func setButton(
        _ button: UnsafeMutablePointer<GtkWidget>,
        provider: UsageProvider,
        enabled: Bool,
        loaded: Bool)
    {
        let name = ProviderDefaults.metadata[provider]?.displayName ?? provider.rawValue.capitalized
        let label = if !enabled {
            "\(name) Off"
        } else if loaded {
            name
        } else {
            "\(name) Loading"
        }
        label.withCString { cString in
            agentbar_button_set_label(button, cString)
        }
        if self.selectedProvider == provider, enabled {
            agentbar_widget_add_css_class(button, "selected")
        } else {
            agentbar_widget_remove_css_class(button, "selected")
        }
        agentbar_widget_set_sensitive(button, enabled ? 1 : 0)
    }

    private func configuredMonitorProviders() -> [UsageProvider] {
        let config = try? AgentBarConfigStore().loadOrCreateDefault()
        let enabledProviders = config?.enabledProviders() ?? [.claude, .codex]
        return enabledProviders.filter { $0 == .claude || $0 == .codex }
    }

    private func preferredProvider(from snapshot: SessionMonitorSnapshot) -> UsageProvider? {
        let config = try? AgentBarConfigStore().loadOrCreateDefault()
        if let preferredProvider = config?.tray.preferredProvider,
           snapshot.availableProviders.contains(preferredProvider)
        {
            return preferredProvider
        }
        return snapshot.recommendation?.preferredProvider ?? snapshot.availableProviders.first
    }

    private func setLabel(_ label: UnsafeMutablePointer<GtkWidget>, text: String) {
        text.withCString { cString in
            agentbar_label_set_text(label, cString)
        }
    }

    private func setMarkupLabel(_ label: UnsafeMutablePointer<GtkWidget>, markup: String) {
        markup.withCString { cString in
            agentbar_label_set_markup(label, cString)
        }
    }

    private func setHeader(_ label: UnsafeMutablePointer<GtkWidget>, text: String) {
        guard !text.isEmpty else {
            self.setLabel(label, text: "")
            return
        }
        let markup = "<span size=\"small\" weight=\"bold\" alpha=\"75%\" letter_spacing=\"900\">"
            + "\(self.escapeMarkup(text.uppercased()))</span>"
        markup.withCString { cString in
            agentbar_label_set_markup(label, cString)
        }
    }

    private func titleMarkup(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        return "<span size=\"xx-large\" weight=\"bold\">\(self.escapeMarkup(text))</span>"
    }

    private func bodyMarkup(_ text: String, alpha: String = "90%") -> String {
        guard !text.isEmpty else { return "" }
        return "<span alpha=\"\(alpha)\">\(self.escapeMarkup(text))</span>"
    }

    private func calloutMarkup(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        return "<span weight=\"bold\" size=\"large\">\(self.escapeMarkup(text))</span>"
    }

    private func metricMarkup(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        return "<span size=\"large\" weight=\"bold\">\(self.escapeMarkup(text))</span>"
    }

    private func escapeMarkup(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

private func agentBarPanelSelectClaudeCallback(_ context: UnsafeMutableRawPointer?) {
    guard let context else { return }
    let controller = Unmanaged<UsagePanelController>.fromOpaque(context).takeUnretainedValue()
    controller.select(provider: .claude)
}

private func agentBarPanelSelectCodexCallback(_ context: UnsafeMutableRawPointer?) {
    guard let context else { return }
    let controller = Unmanaged<UsagePanelController>.fromOpaque(context).takeUnretainedValue()
    controller.select(provider: .codex)
}

private func agentBarPanelRefreshCallback(_ context: UnsafeMutableRawPointer?) {
    guard let context else { return }
    let controller = Unmanaged<UsagePanelController>.fromOpaque(context).takeUnretainedValue()
    controller.refresh()
}

private func agentBarPanelOpenConfigCallback(_ context: UnsafeMutableRawPointer?) {
    guard let context else { return }
    let controller = Unmanaged<UsagePanelController>.fromOpaque(context).takeUnretainedValue()
    controller.openConfig()
}

private func agentBarPanelDestroyCallback(_ context: UnsafeMutableRawPointer?) {
    guard let context else { return }
    let controller = Unmanaged<UsagePanelController>.fromOpaque(context).takeUnretainedValue()
    controller.handleWindowDestroyed()
}

private func agentBarPanelApplyRenderCallback(_ context: UnsafeMutableRawPointer?) {
    guard let context else { return }
    let renderContext = Unmanaged<UsagePanelRenderContext>.fromOpaque(context).takeRetainedValue()
    renderContext.controller.apply(snapshot: renderContext.snapshot, refreshID: renderContext.refreshID)
}
