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

### First run
- Run `swift run AgentBar` to bootstrap a default config if needed.
- Edit `~/.agentbar/config.json` to enable the providers you use.
- Use `swift run AgentBarCLI --help` for detailed CLI-driven usage checks.

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
- The main remaining work is release hardening: broader live-session validation, GTK/theme warning follow-up, and more UI-focused tests.

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
