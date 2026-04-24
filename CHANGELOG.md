# Changelog

## Unreleased

- Added a Linux app launcher installer that creates `~/.local/share/applications/agentbar.desktop`.
- Hardened GNOME login startup by giving autostart launches a longer wait for `org.kde.StatusNotifierWatcher`.
- Added a Linux dual-provider tray/panel monitor for Claude and Codex, including recommendation, history, and notification support.
- Refactored provider-facing tray/panel copy into shared display formatting helpers so plan, reset, and summary text stay consistent.
- Renamed the GTK panel source file to match the current provider-agnostic `UsagePanelController` type.
- Updated the public README and project notes to describe the current Linux app more directly and remove stale transition wording.
