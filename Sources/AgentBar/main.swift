import AgentBarCore
import Foundation

enum AgentBar {
    static func main() throws {
        let args = Array(CommandLine.arguments.dropFirst())
        let command = args.first ?? "tray"

        switch command {
        case "tray":
            if try AgentBarTrayHost.runIfAvailable() {
                return
            }
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

        print("AgentBar Linux Prototype")
        if showGUIFallbackMessage {
            print("GUI tray host unavailable in this session; showing terminal summary instead.")
        }
        print("Config: \(store.fileURL.path)")
        print("Enabled providers: \(enabled.isEmpty ? "none" : enabled.joined(separator: ", "))")
        print("")
        print("Next steps:")
        print("- Edit ~/.agentbar/config.json to enable or reorder providers")
        print("- Run `swift run AgentBarCLI --help` for detailed usage commands")
        print("- Run `swift run AgentBar providers` to inspect provider enablement")
        print("- Run `swift run AgentBar tray` from GNOME to launch the task-bar indicator")
    }

    private static func printHelp() {
        print(
            """
            AgentBar Linux Prototype

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
