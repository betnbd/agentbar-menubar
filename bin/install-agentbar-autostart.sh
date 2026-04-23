#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

source "${ROOT}/Scripts/swift_runtime_env.sh"
agentbar_export_swift_runtime_env
agentbar_require_tray_dev_packages

BIN_SOURCE="${ROOT}/.build/release/AgentBar"
BIN_TARGET="${HOME}/.local/bin/agentbar"
DESKTOP_DIR="${HOME}/.config/autostart"
DESKTOP_FILE="${DESKTOP_DIR}/agentbar.desktop"

echo "==> build release AgentBar"
swift build -c release --product AgentBar

mkdir -p "$(dirname "$BIN_TARGET")" "$DESKTOP_DIR"
ln -sf "$BIN_SOURCE" "$BIN_TARGET"

cat >"$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=AgentBar
Comment=Launch AgentBar tray at login
Exec=${BIN_TARGET} tray
X-GNOME-Autostart-enabled=true
Terminal=false
Categories=Utility;
EOF

echo "Linked ${BIN_TARGET} -> ${BIN_SOURCE}"
echo "Installed autostart entry at ${DESKTOP_FILE}"
echo "AgentBar will launch with: ${BIN_TARGET} tray"
