#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

tool_env() {
  if [[ "$(uname -s)" != "Linux" ]]; then
    return 0
  fi

  local swiftly_root="${HOME}/.local/share/swiftly/toolchains/6.3.1/usr"
  local compat_xml="${HOME}/.local/compat/noble-libxml2/usr/lib/x86_64-linux-gnu"
  local compat_icu="${HOME}/.local/compat/noble-icu/usr/lib/x86_64-linux-gnu"

  export SOURCEKIT_TOOLCHAIN_PATH="$swiftly_root"
  export LINUX_SOURCEKIT_LIB_PATH="${swiftly_root}/lib"
  export LD_LIBRARY_PATH="${swiftly_root}/lib:${compat_xml}:${compat_icu}:${LD_LIBRARY_PATH:-}"
}

tool_env

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
