# AgentBar

AgentBar is a Linux desktop tray app and CLI for monitoring provider usage, reset windows, spend, and status across coding tools and AI services.

The app is local-first: it reads known local config, logs, provider CLIs, and usage endpoints when enabled. It does not ship usage data to an AgentBar backend.

## What It Provides

- GNOME/AppIndicator tray status for supported providers.
- GTK usage panel with provider tabs, reset windows, pace/headroom summaries, and local spend history.
- CLI commands for text or JSON usage output, config validation, and local cost scans.
- Provider-aware local data silos for account, plan, reset, and spend state.
- Optional generated tray icons that show remaining-usage cues.
- Local recommendations and notifications based on freshness, resets, pace, and headroom.

## Supported Providers

AgentBar includes provider adapters for Codex, Claude, OpenCode, OpenCode Go, Gemini, Antigravity, Copilot, z.ai, MiniMax, Kimi, Kimi K2, Kilo Code, Kiro, Vertex AI, Amp, Ollama, JetBrains AI, OpenRouter, Perplexity, Synthetic, and Warp.

Support depth varies by provider. Some adapters expose live plan/rate-limit data, while others currently expose status, configured identity, or local usage where available.

## Requirements

- Ubuntu or another modern Linux distribution
- Swift 6 toolchain
- `libgtk-3-dev` and `libayatana-appindicator3-dev` for tray builds
- GNOME AppIndicator support for tray visibility

On Ubuntu 26.04 / GNOME 50, install or enable the AppIndicator extension:

```bash
sudo apt install gnome-shell-ubuntu-extensions
gnome-extensions enable ubuntu-appindicators@ubuntu.com
```

Log out and back in if `org.kde.StatusNotifierWatcher` is still unavailable after enabling the extension.

## Getting Started

Create the default config:

```bash
swift run AgentBar bootstrap
```

Edit:

```text
~/.agentbar/config.json
```

Then run:

```bash
swift run AgentBar tray
swift run AgentBar summary
swift run AgentBarCLI usage
swift run AgentBarCLI config validate
```

If the tray target was built without GTK/AppIndicator headers, `AgentBar` falls back to a terminal summary until the packages are installed and the app is rebuilt.

The tray refreshes usage automatically every 60 seconds. Set `AGENTBAR_REFRESH_SECONDS=<seconds>` before launch to tune that interval; values below 15 seconds fall back to the default.

## Desktop Install Helpers

Install the CLI wrapper:

```bash
./bin/install-agentbar-cli.sh
```

Install the app launcher:

```bash
./bin/install-agentbar-launcher.sh
```

Start on login:

```bash
./bin/install-agentbar-autostart.sh
```

The autostart entry runs:

```text
env AGENTBAR_AUTOSTART=1 ~/.local/bin/agentbar tray
```

Autostart waits longer for GNOME to publish the AppIndicator watcher because user startup entries can run before the tray host is ready.

## CLI Examples

```bash
swift run AgentBarCLI --help
swift run AgentBarCLI usage --provider all --format json --pretty
swift run AgentBarCLI usage --provider codex --source cli
swift run AgentBarCLI cost --provider claude
swift run AgentBarCLI config dump --pretty
```

## Development

Use the standard Linux development loop:

```bash
./Scripts/compile_and_run.sh
```

Build and test directly:

```bash
swift build
swift test
swift run AgentBar tray
swift run AgentBarCLI --help
```

NPM scripts wrap the same workflows:

```bash
npm run build
npm test
npm run install:launcher
npm run install:autostart
```

## Troubleshooting

- `org.kde.StatusNotifierWatcher` is unavailable: enable the GNOME AppIndicator extension and start a fresh login session.
- Tray support is unavailable at build time: install `libgtk-3-dev` and `libayatana-appindicator3-dev`, then rebuild.
- GTK prints `Theme parsing error: gtk.css:...`: check `~/.config/gtk-3.0/gtk.css`; desktop theme tools can inject invalid GTK CSS outside AgentBar.
- Startup timing is flaky: set `AGENTBAR_STATUS_NOTIFIER_WAIT_SECONDS=<seconds>` while testing.
- Refresh timing needs testing: set `AGENTBAR_REFRESH_SECONDS=<seconds>`; values below 15 seconds fall back to 60 seconds.
- You need to bypass tray preflight for debugging: run `AGENTBAR_FORCE_TRAY=1 swift run AgentBar tray`.

## Privacy

AgentBar does not crawl your filesystem. It reads a small set of known provider locations, local usage logs, and config files only for features you enable.

## License

MIT
