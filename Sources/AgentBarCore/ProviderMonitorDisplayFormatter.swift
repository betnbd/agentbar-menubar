import Foundation

public enum ProviderMonitorDisplayFormatter {
    public static func planDisplayName(
        for provider: UsageProvider,
        identity: ProviderIdentitySnapshot?)
        -> String?
    {
        guard let identity else { return nil }
        switch provider {
        case .claude:
            return ClaudePlan.cliCompatibilityLoginMethod(identity.loginMethod)
        case .codex:
            return CodexPlanFormatting.displayName(identity.loginMethod)
        default:
            return identity.loginMethod?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    public static func subtitle(
        for provider: UsageProvider,
        identity: ProviderIdentitySnapshot?,
        fallbackDisplayName: String)
        -> String
    {
        let parts = [
            identity?.accountEmail,
            self.planDisplayName(for: provider, identity: identity),
            identity?.accountOrganization,
        ]
            .compactMap(\.self)

        if parts.isEmpty {
            return fallbackDisplayName
        }
        return parts.joined(separator: " | ")
    }

    public static func summaryLine(
        for snapshot: ProviderMonitorSnapshot,
        sessionCostUSD: Double? = nil,
        creditsRemaining: Double? = nil,
        now: Date = Date())
        -> String?
    {
        guard let primary = snapshot.primary else { return nil }

        let name = ProviderDefaults.metadata[snapshot.provider]?.displayName ?? snapshot.provider.rawValue.capitalized
        let remaining = Int(primary.remainingPercent.rounded())
        var parts = ["\(name): \(remaining)% left"]

        if let plan = self.planDisplayName(for: snapshot.provider, identity: snapshot.identity) {
            parts.append("plan \(plan)")
        }
        if let resetLine = UsageFormatter.resetLine(for: primary, style: .countdown, now: now) {
            parts.append(self.trimResetLine(resetLine))
        }
        if let secondary = snapshot.secondary {
            parts.append("weekly \(Int(secondary.remainingPercent.rounded()))%")
        }
        if let sessionCostUSD {
            parts.append(UsageFormatter.usdString(sessionCostUSD))
        }
        if let creditsRemaining, snapshot.provider == .codex {
            parts.append("credits \(UsageFormatter.creditsString(from: creditsRemaining))")
        }
        return parts.joined(separator: " | ")
    }

    private static func trimResetLine(_ line: String) -> String {
        line
            .replacingOccurrences(of: "Resets in ", with: "")
            .replacingOccurrences(of: "Resets ", with: "")
    }
}
