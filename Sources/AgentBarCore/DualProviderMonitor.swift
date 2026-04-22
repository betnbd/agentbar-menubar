import Foundation

public struct ProviderMonitorSnapshot: Sendable {
    public let provider: UsageProvider
    public let updatedAt: Date
    public let primary: RateWindow?
    public let secondary: RateWindow?
    public let tertiary: RateWindow?
    public let creditsRemaining: Double?
    public let tokenUsage: CostUsageTokenSnapshot?
    public let identity: ProviderIdentitySnapshot?

    public init(
        provider: UsageProvider,
        updatedAt: Date,
        primary: RateWindow?,
        secondary: RateWindow?,
        tertiary: RateWindow?,
        creditsRemaining: Double?,
        tokenUsage: CostUsageTokenSnapshot?,
        identity: ProviderIdentitySnapshot?)
    {
        self.provider = provider
        self.updatedAt = updatedAt
        self.primary = primary
        self.secondary = secondary
        self.tertiary = tertiary
        self.creditsRemaining = creditsRemaining
        self.tokenUsage = tokenUsage
        self.identity = identity
    }

    public var displayName: String {
        ProviderDefaults.metadata[self.provider]?.displayName ?? self.provider.rawValue.capitalized
    }

    public var primaryRemainingPercent: Double? {
        self.primary?.remainingPercent
    }

    public var secondaryRemainingPercent: Double? {
        self.secondary?.remainingPercent
    }

    public var tertiaryRemainingPercent: Double? {
        self.tertiary?.remainingPercent
    }
}

public struct ProviderRecommendation: Sendable, Equatable {
    public let preferredProvider: UsageProvider
    public let runnerUpProvider: UsageProvider?
    public let summary: String
    public let rationale: String

    public init(
        preferredProvider: UsageProvider,
        runnerUpProvider: UsageProvider?,
        summary: String,
        rationale: String)
    {
        self.preferredProvider = preferredProvider
        self.runnerUpProvider = runnerUpProvider
        self.summary = summary
        self.rationale = rationale
    }
}

public struct TrayUsageIconSnapshot: Sendable, Equatable {
    public let provider: UsageProvider
    public let remainingPercent: Int

    public init(provider: UsageProvider, remainingPercent: Int) {
        self.provider = provider
        self.remainingPercent = remainingPercent
    }
}

public enum DualProviderMonitor {
    private static let recommendationFreshHours = 6.0
    private static let recommendationStaleHours = 12.0

    public static func recommend(
        snapshots: [ProviderMonitorSnapshot],
        now: Date = Date()) -> ProviderRecommendation?
    {
        let eligible = snapshots
            .filter { $0.primary != nil }
            .sorted { lhs, rhs in
                self.score(snapshot: lhs, now: now) > self.score(snapshot: rhs, now: now)
            }

        guard let preferred = eligible.first else { return nil }
        let preferredFreshness = self.freshness(for: preferred, now: now)
        guard preferredFreshness != .stale else { return nil }

        let runnerUp = eligible.dropFirst().first
        let preferredName = preferred.displayName
        let summary: String
        let rationale: String

        if let runnerUp {
            let remaining = self.percentString(preferred.primaryRemainingPercent)
            let otherRemaining = self.percentString(runnerUp.primaryRemainingPercent)
            let confidence = self.confidenceText(
                preferred: preferred,
                runnerUp: runnerUp,
                now: now)
            let freshness = self.freshnessSummary(
                preferred: preferred,
                runnerUp: runnerUp,
                now: now)
            summary = "Best tool now: \(preferredName)"
            let headroom = "\(remaining) left vs \(runnerUp.displayName) at \(otherRemaining)"
            rationale = [
                "\(preferredName) has more session headroom (\(headroom)).",
                freshness,
                confidence,
            ].joined(separator: " ")
        } else {
            summary = "Best tool now: \(preferredName)"
            rationale = "\(preferredName) is the only provider with a fresh enough live session snapshot right now."
        }

        return ProviderRecommendation(
            preferredProvider: preferred.provider,
            runnerUpProvider: runnerUp?.provider,
            summary: summary,
            rationale: rationale)
    }

    public static func trayLabel(
        snapshots: [ProviderMonitorSnapshot],
        mode: TrayDisplayMode = .dualSummary,
        selectedProvider: UsageProvider? = nil,
        now: Date = Date()) -> String?
    {
        let usable = snapshots.filter { $0.primary != nil }
        guard !usable.isEmpty else { return nil }

        switch mode {
        case .dualSummary:
            if let recommendation = self.recommend(snapshots: usable, now: now),
               let preferred = usable.first(where: { $0.provider == recommendation.preferredProvider }),
               let runnerUpProvider = recommendation.runnerUpProvider,
               let runnerUp = usable.first(where: { $0.provider == runnerUpProvider })
            {
                let preferredText = "\(self.shortName(for: preferred.provider))"
                    + " \(self.percentString(preferred.primaryRemainingPercent))"
                let runnerUpText = "\(self.shortName(for: runnerUp.provider))"
                    + " \(self.percentString(runnerUp.primaryRemainingPercent))"
                return "\(preferredText) | \(runnerUpText)"
            }
        case .forecastSummary:
            break
        case .bestAvailable, .selectedProvider, .providerName, .percentRemaining, .timeToReset:
            break
        }

        let primarySnapshot = self.selectSnapshot(
            usable,
            mode: mode,
            selectedProvider: selectedProvider,
            now: now)

        guard let primarySnapshot else { return nil }

        switch mode {
        case .providerName:
            return self.shortName(for: primarySnapshot.provider)
        case .percentRemaining:
            return self.percentString(primarySnapshot.primaryRemainingPercent)
        case .timeToReset:
            guard let window = primarySnapshot.primary,
                  let resetLine = UsageFormatter.resetLine(for: window, style: .countdown, now: now)
            else {
                return self.percentString(primarySnapshot.primaryRemainingPercent)
            }
            return resetLine.replacingOccurrences(of: "Resets ", with: "")
        case .bestAvailable, .selectedProvider:
            let providerText = self.shortName(for: primarySnapshot.provider)
            let percentText = self.percentString(primarySnapshot.primaryRemainingPercent)
            return "\(providerText) \(percentText)"
        case .forecastSummary:
            let providerText = self.shortName(for: primarySnapshot.provider)
            let forecastText = self.trayForecastSummary(snapshot: primarySnapshot, now: now)
            return "\(providerText) \(forecastText)"
        case .dualSummary:
            let providerText = self.shortName(for: primarySnapshot.provider)
            let percentText = self.percentString(primarySnapshot.primaryRemainingPercent)
            return "\(providerText) \(percentText)"
        }
    }

    public static func paceSummary(
        snapshot: ProviderMonitorSnapshot,
        now: Date = Date()) -> String?
    {
        guard let pace = self.paceForecast(snapshot: snapshot, now: now)
        else {
            return nil
        }

        switch pace.stage {
        case .onTrack:
            return "Pace: on track"
        case .slightlyAhead:
            return "Pace: slightly ahead"
        case .ahead:
            return "Pace: ahead"
        case .farAhead:
            return "Pace: far ahead"
        case .slightlyBehind:
            return "Pace: slightly behind"
        case .behind:
            return "Pace: behind"
        case .farBehind:
            return "Pace: far behind"
        }
    }

    public static func paceForecast(
        snapshot: ProviderMonitorSnapshot,
        now: Date = Date()) -> UsagePace?
    {
        let candidate = snapshot.secondary ?? snapshot.primary
        guard let window = candidate else { return nil }
        return UsagePace.weekly(
            window: window,
            now: now,
            defaultWindowMinutes: window.windowMinutes ?? (7 * 24 * 60))
    }

    public static func paceForecastSummary(
        snapshot: ProviderMonitorSnapshot,
        now: Date = Date()) -> String?
    {
        guard let pace = self.paceForecast(snapshot: snapshot, now: now) else { return nil }
        if pace.willLastToReset {
            return "Forecast: likely lasts to reset"
        }
        if let etaSeconds = pace.etaSeconds {
            return "Forecast: runway \(self.relativeDurationString(seconds: etaSeconds))"
        }
        return "Forecast: \(self.stageText(pace.stage))"
    }

    public static func trayUsageIconSnapshot(
        snapshots: [ProviderMonitorSnapshot],
        selectedProvider: UsageProvider? = nil,
        now: Date = Date(),
        freshnessThresholdHours: Double = 6) -> TrayUsageIconSnapshot?
    {
        let trustworthy = snapshots.filter {
            self.isTrustworthyForTrayIcon(
                snapshot: $0,
                now: now,
                freshnessThresholdHours: freshnessThresholdHours)
        }
        guard !trustworthy.isEmpty else { return nil }

        let selectedSnapshot = selectedProvider.flatMap { provider in
            trustworthy.first(where: { $0.provider == provider })
        }
        let chosen = selectedSnapshot ?? self.selectSnapshot(
            trustworthy,
            mode: .bestAvailable,
            selectedProvider: nil,
            now: now)

        guard let chosen,
              let remainingPercent = chosen.primaryRemainingPercent
        else {
            return nil
        }

        return TrayUsageIconSnapshot(
            provider: chosen.provider,
            remainingPercent: Int(remainingPercent.rounded()))
    }

    private static func selectSnapshot(
        _ usable: [ProviderMonitorSnapshot],
        mode: TrayDisplayMode,
        selectedProvider: UsageProvider?,
        now: Date) -> ProviderMonitorSnapshot?
    {
        let preferredProvider: UsageProvider? = switch mode {
        case .selectedProvider:
            selectedProvider
        default:
            nil
        }

        return preferredProvider.flatMap { provider in
            usable.first(where: { $0.provider == provider })
        } ?? usable.max(by: {
            self.score(snapshot: $0, now: now) < self.score(snapshot: $1, now: now)
        })
    }

    private static func score(snapshot: ProviderMonitorSnapshot, now: Date) -> Double {
        let primaryRemaining = snapshot.primaryRemainingPercent ?? -1e3
        let secondaryRemaining = snapshot.secondaryRemainingPercent ?? 0
        let tertiaryRemaining = snapshot.tertiaryRemainingPercent ?? 0
        let ageHours = max(0, now.timeIntervalSince(snapshot.updatedAt) / (60 * 60))
        let freshnessPenalty = min(ageHours, 24) * 6
        return primaryRemaining + (secondaryRemaining * 0.35) + (tertiaryRemaining * 0.15) - freshnessPenalty
    }

    private static func freshness(for snapshot: ProviderMonitorSnapshot, now: Date) -> SnapshotFreshness {
        let ageHours = max(0, now.timeIntervalSince(snapshot.updatedAt) / (60 * 60))
        if ageHours <= self.recommendationFreshHours {
            return .fresh
        }
        if ageHours <= self.recommendationStaleHours {
            return .aging
        }
        return .stale
    }

    private static func freshnessSummary(
        preferred: ProviderMonitorSnapshot,
        runnerUp: ProviderMonitorSnapshot,
        now: Date) -> String
    {
        let preferredFreshness = self.freshness(for: preferred, now: now)
        let runnerUpFreshness = self.freshness(for: runnerUp, now: now)

        switch (preferredFreshness, runnerUpFreshness) {
        case (.fresh, .fresh):
            return "Both providers have fresh enough usage snapshots."
        case (.fresh, .aging):
            return "\(preferred.displayName) is fresh; \(runnerUp.displayName) is starting to age."
        case (.aging, .fresh):
            return "\(runnerUp.displayName) is fresher, but \(preferred.displayName) still has materially "
                + "more headroom."
        case (.aging, .aging):
            return "Both providers are aging, so treat this recommendation as lower confidence."
        case (.fresh, .stale), (.aging, .stale):
            return "\(runnerUp.displayName) is stale, so the comparison leans on "
                + "\(preferred.displayName)'s fresher data."
        case (.stale, _), (_, .stale):
            return "Freshness is limiting confidence in this comparison."
        }
    }

    private static func confidenceText(
        preferred: ProviderMonitorSnapshot,
        runnerUp: ProviderMonitorSnapshot,
        now: Date) -> String
    {
        let preferredRemaining = preferred.primaryRemainingPercent ?? 0
        let runnerUpRemaining = runnerUp.primaryRemainingPercent ?? 0
        let gap = preferredRemaining - runnerUpRemaining
        let preferredFreshness = self.freshness(for: preferred, now: now)
        let runnerUpFreshness = self.freshness(for: runnerUp, now: now)

        if preferredFreshness == .fresh, runnerUpFreshness == .fresh, gap >= 20 {
            return "Confidence: high."
        }
        if preferredFreshness == .stale || runnerUpFreshness == .stale || gap < 10 {
            return "Confidence: cautious."
        }
        return "Confidence: moderate."
    }

    private static func isTrustworthyForTrayIcon(
        snapshot: ProviderMonitorSnapshot,
        now: Date,
        freshnessThresholdHours: Double) -> Bool
    {
        guard snapshot.primaryRemainingPercent != nil else { return false }
        let ageHours = max(0, now.timeIntervalSince(snapshot.updatedAt) / (60 * 60))
        return ageHours <= freshnessThresholdHours
    }

    private static func shortName(for provider: UsageProvider) -> String {
        switch provider {
        case .claude:
            "Cl"
        case .codex:
            "Co"
        default:
            String(provider.rawValue.prefix(2)).capitalized
        }
    }

    private static func percentString(_ value: Double?) -> String {
        guard let value else { return "--" }
        return "\(Int(value.rounded()))%"
    }

    private static func trayForecastSummary(snapshot: ProviderMonitorSnapshot, now: Date) -> String {
        guard let pace = self.paceForecast(snapshot: snapshot, now: now) else {
            return self.percentString(snapshot.primaryRemainingPercent)
        }
        if pace.willLastToReset, let remaining = snapshot.primaryRemainingPercent {
            return "\(Int(remaining.rounded()))% ok"
        }
        if let etaSeconds = pace.etaSeconds {
            return "risk \(self.relativeDurationString(seconds: etaSeconds))"
        }
        return self.stageText(pace.stage)
    }

    private static func stageText(_ stage: UsagePace.Stage) -> String {
        switch stage {
        case .onTrack:
            "on track"
        case .slightlyAhead:
            "slightly ahead"
        case .ahead:
            "ahead"
        case .farAhead:
            "far ahead"
        case .slightlyBehind:
            "slightly behind"
        case .behind:
            "behind"
        case .farBehind:
            "far behind"
        }
    }

    private static func relativeDurationString(seconds: TimeInterval) -> String {
        let totalMinutes = max(1, Int(seconds / 60.0))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0, minutes > 0 {
            return "\(hours)h \(minutes)m"
        }
        if hours > 0 {
            return "\(hours)h"
        }
        return "\(minutes)m"
    }
}

private enum SnapshotFreshness {
    case fresh
    case aging
    case stale
}
