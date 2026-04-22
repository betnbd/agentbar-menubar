import AgentBarCore
import Foundation

extension AgentBarCLI {
    static func usageHelp(version: String) -> String {
        """
        \(AppIdentity.productName) \(version)

        Usage:
          agentbar usage [--format text|json]
                       [--json]
                       [--json-only]
                       [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>] [-v|--verbose]
                       [--provider \(ProviderHelp.list)]
                       [--account <label>] [--account-index <index>] [--all-accounts]
                       [--no-credits] [--no-color] [--pretty] [--status] [--source <auto|web|cli|oauth|api>]
                       [--web-timeout <seconds>] [--web-debug-dump-html] [--antigravity-plan-debug]

        Description:
          Print usage from enabled providers as text (default) or JSON. Honors the current config file.
          Output format: use --json (or --format json) for JSON on stdout; use --json-output for JSON logs on stderr.
          Source behavior is provider-specific:
          - Codex: Linux CLI and local account state.
            Web dashboard scraping is not part of this Linux prototype path.
          - Claude: claude.ai API.
            Auto falls back to Claude CLI only when cookies are missing.
          - Kilo: app.kilo.ai API.
            Auto falls back to Kilo CLI when API credentials are missing or unauthorized.
          Token accounts are loaded from ~/\(AppIdentity.configDirectoryName)/config.json.
          Use --account or --account-index to select a specific token account, or --all-accounts to fetch all.
          Account selection requires a single provider.

        Global flags:
          -h, --help      Show help
          -V, --version   Show version
          -v, --verbose   Enable verbose logging
          --no-color      Disable ANSI colors in text output
          --log-level <trace|verbose|debug|info|warning|error|critical>
          --json-output   Emit machine-readable logs (JSONL) to stderr

        Examples:
          agentbar usage
          agentbar usage --provider claude
          agentbar usage --provider gemini
          agentbar usage --format json --provider all --pretty
          agentbar usage --provider all --json
          agentbar usage --status
          agentbar usage --provider codex --source cli --format json --pretty
        """
    }

    static func costHelp(version: String) -> String {
        """
        \(AppIdentity.productName) \(version)

        Usage:
          agentbar cost [--format text|json]
                       [--json]
                       [--json-only]
                       [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>] [-v|--verbose]
                       [--provider \(ProviderHelp.list)]
                       [--no-color] [--pretty] [--refresh]

        Description:
          Print local token cost usage from Claude/Codex native logs plus supported pi sessions.
          This does not require web or CLI access and uses cached scan results unless --refresh is provided.

        Examples:
          agentbar cost
          agentbar cost --provider claude --format json --pretty
        """
    }

    static func configHelp(version: String) -> String {
        """
        \(AppIdentity.productName) \(version)

        Usage:
          agentbar config validate [--format text|json]
                                 [--json]
                                 [--json-only]
                                 [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>]
                                 [-v|--verbose]
                                 [--pretty]
          agentbar config dump [--format text|json]
                             [--json]
                             [--json-only]
                             [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>]
                             [-v|--verbose]
                             [--pretty]

        Description:
          Validate or print the \(AppIdentity.productName) config file (default: validate).

        Examples:
          agentbar config validate --format json --pretty
          agentbar config dump --pretty
        """
    }

    static func rootHelp(version: String) -> String {
        """
        \(AppIdentity.productName) \(version)

        Usage:
          agentbar [--format text|json]
                  [--json]
                  [--json-only]
                  [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>] [-v|--verbose]
                  [--provider \(ProviderHelp.list)]
                  [--account <label>] [--account-index <index>] [--all-accounts]
                  [--no-credits] [--no-color] [--pretty] [--status] [--source <auto|web|cli|oauth|api>]
                  [--web-timeout <seconds>] [--web-debug-dump-html] [--antigravity-plan-debug]
          agentbar cost [--format text|json]
                       [--json]
                       [--json-only]
                       [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>] [-v|--verbose]
                       [--provider \(ProviderHelp.list)] [--no-color] [--pretty] [--refresh]
          agentbar config <validate|dump> [--format text|json]
                                        [--json]
                                        [--json-only]
                                        [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>]
                                        [-v|--verbose]
                                        [--pretty]

        Global flags:
          -h, --help      Show help
          -V, --version   Show version
          -v, --verbose   Enable verbose logging
          --no-color      Disable ANSI colors in text output
          --log-level <trace|verbose|debug|info|warning|error|critical>
          --json-output   Emit machine-readable logs (JSONL) to stderr

        Examples:
          agentbar
          agentbar --format json --provider all --pretty
          agentbar --provider all --json
          agentbar --provider gemini
          agentbar cost --provider claude --format json --pretty
          agentbar config validate --format json --pretty
        """
    }
}
