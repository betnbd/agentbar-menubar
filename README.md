# AgentBar

Ubuntu/GNOME/Linux-only usage tracker for provider limits, reset windows, and status across multiple services.
The current runnable surface is a Linux executable plus a bundled CLI.

## Highlights
- GNOME tray app with compact live status for supported providers.
- Unified usage panel with reset windows, plan visibility, spend summaries, and recommendations.
- Local-first data model: reads provider-specific local state, logs, and config instead of shipping data to a backend.
- Bundled CLI for scripting, debugging, and non-GUI environments.

## Install

### Requirements
- Ubuntu or another modern Linux distribution with Swift 6 toolchain support
- For tray builds: `libgtk-3-dev` and `libayatana-appindicator3-dev`
- For GNOME tray visibility on Ubuntu 26.04 / GNOME 50: `gnome-shell-extension-appindicator` (provided on Ubuntu by `gnome-shell-ubuntu-extensions`)

### First run
- Run `swift run AgentBar` to bootstrap a default config if needed.
- Edit `~/.agentbar/config.json` to enable the providers you use.
- Use `swift run AgentBarCLI --help` for detailed CLI-driven usage checks.
- If the tray target was built without GTK/AppIndicator headers, `AgentBar` will fall back to the terminal summary until those packages are installed and you rebuild.
- If `swift run AgentBar tray` says `org.kde.StatusNotifierWatcher` is unavailable, GNOME is running but the AppIndicator shell extension is not active yet.

### Start on login
- Run `./bin/install-agentbar-autostart.sh` to build the release binary, link `~/.local/bin/agentbar`, and install `~/.config/autostart/agentbar.desktop`.
- The login command used is `env AGENTBAR_AUTOSTART=1 ~/.local/bin/agentbar tray`, which gives GNOME's AppIndicator watcher extra time to appear during session startup.
- Validated on Ubuntu 26.04 / GNOME 50: the installer creates a working `agentbar.desktop` autostart entry and a symlinked release binary at `~/.local/bin/agentbar`.

### App launcher
- Run `./bin/install-agentbar-launcher.sh` to build the release binary, link `~/.local/bin/agentbar`, and install `~/.local/share/applications/agentbar.desktop`.
- The launcher command used is `~/.local/bin/agentbar tray`.
- The same flow is available through `pnpm install:launcher`.

### GNOME 50 notes
- Ubuntu 26.04 ships GNOME 50 and still needs the AppIndicator extension for tray icons.
- Install `gnome-shell-ubuntu-extensions` (or another provider for `gnome-shell-extension-appindicator`) if the extension files are missing.
- Then enable `ubuntu-appindicators@ubuntu.com` in Extension Manager or with `gnome-extensions`, and log out/back in if the session bus still lacks `org.kde.StatusNotifierWatcher`.
- AgentBar checks for `org.kde.StatusNotifierWatcher` before starting the tray host so it can fall back cleanly when the extension is unavailable. Manual launches wait briefly; autostart launches wait longer because GNOME may publish the watcher after user autostart entries begin.
- For troubleshooting only, `AGENTBAR_FORCE_TRAY=1 swift run AgentBar tray` bypasses that preflight check.
- For troubleshooting startup timing, `AGENTBAR_STATUS_NOTIFIER_WAIT_SECONDS=<seconds>` overrides the watcher wait.
- If GTK prints `Theme parsing error: gtk.css:...` on startup, check `~/.config/gtk-3.0/gtk.css` before debugging AgentBar. User theme tools can inject invalid GTK CSS there.

## Providers

- Codex
- Claude
- OpenCode
- OpenCode Go
- Gemini
- Antigravity
- Copilot
- z.ai
- MiniMax
- Kimi
- Kimi K2
- Kilo Code
- Kiro
- Vertex AI
- Amp
- Ollama
- JetBrains AI
- OpenRouter
- Perplexity
- Synthetic
- Warp

## Scope
- Linux-first executable target: `AgentBar`
- CLI target for scripts and debugging: `AgentBarCLI`
- Shared fetch/parsing/config logic in `AgentBarCore`

## Current Status
- The Linux GNOME tray indicator is working in a live GUI session.
- The GTK panel supports dual-provider Claude + Codex monitoring with provider switching.
- The tray surfaces compact dual-provider status, plan-aware summaries, and a recommendation line.
- The main remaining work is release hardening and more UI-focused tests.
- Ubuntu 26.04 notes: the app still targets GTK 3 + Ayatana AppIndicator, and GNOME 50 sessions need the AppIndicator shell extension enabled so the tray icon is actually hosted.

## Features
- Multi-provider config and usage fetching.
- Dual-provider Claude + Codex tray monitor with provider-aware data silos.
- GTK usage panel with per-provider tabs, reset visibility, pace/headroom summaries, and local spend history.
- Configurable tray display modes and optional generated remaining-usage circle icon.
- Local-only recommendation and notification paths based on headroom, pace, resets, and freshness.
- Session + weekly meters with reset countdowns in CLI output.
- Local cost-usage scan for Codex + Claude (last 30 days).
- Provider status polling in CLI output.
- Bundled CLI for scripts and CI.
- Privacy-first: on-device parsing and local config files by default.

## Privacy note
The app does not crawl your filesystem; it reads a small set of known locations such as config files, local usage logs, and provider-specific local data when the related features are enabled.

## Best Fit
- Ubuntu or another modern Linux desktop with GNOME/AppIndicator support.
- Users who want a local tray monitor for reset windows, spend, and headroom across coding tools.
- Developers who want both a tray UI and a CLI path from the same codebase.

## Docs

## Getting started (dev)
- Clone the repo and run the scripts directly.
- Use `./Scripts/compile_and_run.sh` for the standard Linux dev loop.
- Use `swift run AgentBarCLI --help` to inspect provider and config options.

## Build from source
```bash
swift build
swift test
swift run AgentBar
swift run AgentBarCLI --help
```

Dev loop:
```bash
./Scripts/compile_and_run.sh
```

## License
MIT
