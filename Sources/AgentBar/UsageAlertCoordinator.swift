import AgentBarCore
import Foundation

private struct UsageAlertKey: Hashable {
    let provider: UsageProvider
    let kind: String
}

final class UsageAlertCoordinator: @unchecked Sendable {
    private let poster: any NotificationPosting
    private var lowHeadroomSent: Set<UsageAlertKey> = []
    private var staleDataSent: Set<UsageAlertKey> = []
    private var aheadOfPaceSent: Set<UsageAlertKey> = []
    private var lastSnapshots: [UsageProvider: ProviderMonitorSnapshot] = [:]

    init(poster: any NotificationPosting) {
        self.poster = poster
    }

    func process(
        snapshot: SessionMonitorSnapshot,
        config: NotificationConfig,
        now: Date = Date())
    {
        guard config.enabled else {
            self.lastSnapshots = snapshot.providers.mapValues(\.monitor)
            return
        }

        Task {
            guard await self.poster.requestAuthorizationIfNeeded() else {
                self.lastSnapshots = snapshot.providers.mapValues(\.monitor)
                return
            }

            for providerSnapshot in snapshot.providers.values {
                await self.process(
                    providerSnapshot: providerSnapshot.monitor,
                    config: config,
                    now: now)
            }

            self.lastSnapshots = snapshot.providers.mapValues(\.monitor)
        }
    }

    private func process(
        providerSnapshot: ProviderMonitorSnapshot,
        config: NotificationConfig,
        now: Date) async
    {
        let providerName = providerSnapshot.displayName
        let lowHeadroomKey = UsageAlertKey(provider: providerSnapshot.provider, kind: "lowHeadroom")
        let staleDataKey = UsageAlertKey(provider: providerSnapshot.provider, kind: "staleData")
        let aheadOfPaceKey = UsageAlertKey(provider: providerSnapshot.provider, kind: "aheadOfPace")

        if let remaining = providerSnapshot.primaryRemainingPercent,
           remaining <= Double(config.lowHeadroomPercent)
        {
            if !self.lowHeadroomSent.contains(lowHeadroomKey) {
                self.lowHeadroomSent.insert(lowHeadroomKey)
                await self.poster.post(
                    idPrefix: "agentbar-low-headroom-\(providerSnapshot.provider.rawValue)",
                    title: "\(providerName) running low",
                    body: "\(Int(remaining.rounded()))% session headroom remains.",
                    badge: nil)
            }
        } else {
            self.lowHeadroomSent.remove(lowHeadroomKey)
        }

        let ageHours = max(0, now.timeIntervalSince(providerSnapshot.updatedAt) / (60 * 60))
        if ageHours >= Double(config.staleDataHours) {
            if !self.staleDataSent.contains(staleDataKey) {
                self.staleDataSent.insert(staleDataKey)
                await self.poster.post(
                    idPrefix: "agentbar-stale-\(providerSnapshot.provider.rawValue)",
                    title: "\(providerName) data is stale",
                    body: "Last update was "
                        + "\(UsageFormatter.updatedString(from: providerSnapshot.updatedAt, now: now)).",
                    badge: nil)
            }
        } else {
            self.staleDataSent.remove(staleDataKey)
        }

        if let pace = DualProviderMonitor.paceForecast(snapshot: providerSnapshot, now: now),
           pace.deltaPercent >= Double(config.aheadOfPacePercent),
           !pace.willLastToReset
        {
            if !self.aheadOfPaceSent.contains(aheadOfPaceKey) {
                self.aheadOfPaceSent.insert(aheadOfPaceKey)
                let runway = pace.etaSeconds.map { " Runway: \(self.durationString(seconds: $0))." } ?? ""
                await self.poster.post(
                    idPrefix: "agentbar-ahead-of-pace-\(providerSnapshot.provider.rawValue)",
                    title: "\(providerName) pace is running hot",
                    body: "Usage is \(Int(pace.deltaPercent.rounded()))% ahead of pace." + runway,
                    badge: nil)
            }
        } else {
            self.aheadOfPaceSent.remove(aheadOfPaceKey)
        }

        guard config.notifyOnResetCompletion,
              let previous = self.lastSnapshots[providerSnapshot.provider],
              let previousReset = previous.primary?.resetsAt,
              previousReset <= now,
              let previousRemaining = previous.primaryRemainingPercent,
              let currentRemaining = providerSnapshot.primaryRemainingPercent,
              currentRemaining > previousRemaining + 10
        else {
            return
        }

        await self.poster.post(
            idPrefix: "agentbar-reset-\(providerSnapshot.provider.rawValue)",
            title: "\(providerName) reset completed",
            body: "Session headroom has recovered to \(Int(currentRemaining.rounded()))%.",
            badge: nil)
    }

    private func durationString(seconds: TimeInterval) -> String {
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
