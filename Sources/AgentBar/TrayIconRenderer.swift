import AgentBarCore
import Foundation

struct TrayRenderedIcon {
    let iconName: String
    let themePath: String
    let description: String
}

final class TrayIconRenderer: @unchecked Sendable {
    private let fileManager: FileManager
    private let directoryURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let baseURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        self.directoryURL = baseURL
            .appendingPathComponent("AgentBar", isDirectory: true)
            .appendingPathComponent("tray-icons", isDirectory: true)
    }

    func render(snapshot: TrayUsageIconSnapshot) -> TrayRenderedIcon? {
        let iconName = "agentbar-remaining-\(snapshot.provider.rawValue)-\(self.clamp(snapshot.remainingPercent))"
        let iconURL = self.directoryURL.appendingPathComponent("\(iconName).svg")

        do {
            try self.fileManager.createDirectory(at: self.directoryURL, withIntermediateDirectories: true)
            self.pruneOldIcons(excluding: iconURL)
            try self.svg(for: snapshot).write(to: iconURL, atomically: true, encoding: .utf8)
            return TrayRenderedIcon(
                iconName: iconName,
                themePath: self.directoryURL.path,
                description: self.description(for: snapshot))
        } catch {
            return nil
        }
    }

    private func svg(for snapshot: TrayUsageIconSnapshot) -> String {
        let percent = self.clamp(snapshot.remainingPercent)
        let branding = ProviderDescriptorRegistry.descriptor(for: snapshot.provider).branding.color
        let progressColor = self.progressColor(branding: branding, remainingPercent: percent)
        let trackColor = "#D0D5DD"
        let centerColor = "#FFFFFF"
        let providerTextColor = "#101828"
        let radius = 24.0
        let circumference = 2 * Double.pi * radius
        let dash = circumference * Double(percent) / 100.0
        let providerCue = self.providerCue(for: snapshot.provider)
        return """
        <svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
          <rect width="64" height="64" rx="16" fill="#FFFFFF"/>
          <circle cx="32" cy="32" r="24" fill="none" stroke="\(trackColor)" stroke-width="8"/>
          <circle
            cx="32"
            cy="32"
            r="24"
            fill="none"
            stroke="\(progressColor)"
            stroke-width="8"
            stroke-linecap="round"
            stroke-dasharray="\(self.decimalString(dash)) \(self.decimalString(circumference))"
            transform="rotate(-90 32 32)"/>
          <circle cx="32" cy="32" r="15" fill="\(centerColor)"/>
          <text
            x="32"
            y="37"
            text-anchor="middle"
            font-family="Sans"
            font-size="11"
            font-weight="700"
            fill="\(providerTextColor)">\(providerCue)</text>
        </svg>
        """
    }

    private func description(for snapshot: TrayUsageIconSnapshot) -> String {
        let providerName = ProviderDefaults.metadata[snapshot.provider]?.displayName
            ?? snapshot.provider.rawValue.capitalized
        return "\(providerName) \(self.clamp(snapshot.remainingPercent))% remaining"
    }

    private func progressColor(branding: ProviderColor, remainingPercent: Int) -> String {
        if remainingPercent <= 15 {
            return "#D92D20"
        }
        if remainingPercent <= 35 {
            return "#F79009"
        }
        return self.hexColor(branding)
    }

    private func hexColor(_ color: ProviderColor) -> String {
        let red = Int((min(max(color.red, 0), 1) * 255).rounded())
        let green = Int((min(max(color.green, 0), 1) * 255).rounded())
        let blue = Int((min(max(color.blue, 0), 1) * 255).rounded())
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    private func decimalString(_ value: Double) -> String {
        String(format: "%.3f", value)
    }

    private func providerCue(for provider: UsageProvider) -> String {
        switch provider {
        case .claude:
            "Cl"
        case .codex:
            "Co"
        default:
            String(provider.rawValue.prefix(2)).capitalized
        }
    }

    private func pruneOldIcons(excluding activeIconURL: URL) {
        guard let iconURLs = try? self.fileManager.contentsOfDirectory(
            at: self.directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles])
        else {
            return
        }

        let svgIcons = iconURLs.filter {
            $0.pathExtension == "svg" && $0.lastPathComponent.hasPrefix("agentbar-remaining-")
        }
        let staleIcons = svgIcons.filter { $0 != activeIconURL }
        let sortedStaleIcons = staleIcons.sorted { lhs, rhs in
            let leftDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
                ?? .distantPast
            let rightDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
                ?? .distantPast
            return leftDate > rightDate
        }

        for iconURL in sortedStaleIcons.dropFirst(11) {
            try? self.fileManager.removeItem(at: iconURL)
        }
    }

    private func clamp(_ value: Int) -> Int {
        min(max(value, 0), 100)
    }
}
