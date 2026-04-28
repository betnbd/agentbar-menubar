import AgentBarCore
import Foundation

enum AgentBar {
    static func main() throws {
        let args = Array(CommandLine.arguments.dropFirst())
        let command = args.first ?? "tray"

        switch command {
        case "tray":
            #if canImport(CAgentBarTrayShim)
            do {
                if try AgentBarTrayHost.runIfAvailable() {
                    return
                }
            } catch {
                let message = "Tray host unavailable: \(error.localizedDescription)\n"
                FileHandle.standardError.write(Data(message.utf8))
            }
            #endif
            try self.printSummary(showGUIFallbackMessage: true)
        case "bootstrap":
            try self.bootstrap()
        case "providers":
            try self.printProviders()
        case "config-path":
            print(AgentBarConfigStore.defaultURL().path)
        case "summary":
            try self.printSummary(showGUIFallbackMessage: false)
        case "help", "--help", "-h":
            self.printHelp()
        default:
            FileHandle.standardError.write(Data("Unknown command: \(command)\n\n".utf8))
            self.printHelp()
            Foundation.exit(1)
        }
    }

    private static var trayBuildLine: String {
        #if canImport(CAgentBarTrayShim)
        "- Run `swift run AgentBar tray` from GNOME to launch the task-bar indicator"
        #else
        "- Install `libgtk-3-dev` and `libayatana-appindicator3-dev`, then rebuild to enable the GNOME tray indicator"
        #endif
    }

    private static func bootstrap() throws {
        let store = AgentBarConfigStore()
        let config = try store.loadOrCreateDefault()
        print("Config ready at \(store.fileURL.path)")
        print("Enabled providers: \(config.enabledProviders().map(\.rawValue).joined(separator: ", "))")
    }

    private static func printProviders() throws {
        let store = AgentBarConfigStore()
        let config = try store.loadOrCreateDefault()
        let enabled = Set(config.enabledProviders())

        for provider in UsageProvider.allCases {
            let state = enabled.contains(provider) ? "enabled" : "disabled"
            print("\(provider.rawValue)\t\(state)")
        }
    }

    private static func printSummary(showGUIFallbackMessage: Bool) throws {
        let store = AgentBarConfigStore()
        let config = try store.loadOrCreateDefault()
        let enabled = config.enabledProviders().map(\.rawValue)

        var lines = ["AgentBar"]
        if showGUIFallbackMessage {
            lines.append("GUI tray host unavailable in this session; showing terminal summary instead.")
        }
        #if !canImport(CAgentBarTrayShim)
        lines
            .append(
                "Tray support was not built because GTK 3 / Ayatana AppIndicator development files were unavailable.")
        #endif
        lines += [
            "Config: \(store.fileURL.path)",
            "Enabled providers: \(enabled.isEmpty ? "none" : enabled.joined(separator: ", "))",
            "",
            "Next steps:",
            "- Edit ~/.agentbar/config.json to enable or reorder providers",
            "- Run `swift run AgentBarCLI --help` for detailed usage commands",
            "- Run `swift run AgentBar providers` to inspect provider enablement",
            self.trayBuildLine,
        ]
        #if canImport(CAgentBarTrayShim)
        lines += [
            "- If GNOME 50 still hides the tray, enable `ubuntu-appindicators@ubuntu.com`",
            "  in Extension Manager and retry",
            "- Set `AGENTBAR_FORCE_TRAY=1` to bypass the watcher preflight while troubleshooting",
        ]
        #endif
        print(lines.joined(separator: "\n"))
    }

    private static func printHelp() {
        print(
            """
            AgentBar

            Commands:
              tray         Launch the GNOME tray indicator when GUI is available
              summary      Show config path and enabled providers
              bootstrap    Create a default config if missing
              providers    List all providers and whether they are enabled
              config-path  Print the config path
              help         Show this help
            """)
    }
}

try AgentBar.main()
