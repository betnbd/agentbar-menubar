#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
source "${ROOT}/Scripts/swift_runtime_env.sh"
agentbar_export_swift_runtime_env

HELPER="${ROOT}/.build/debug/AgentBarCLI"
TARGET="${HOME}/.local/bin/agentbar"

if [[ ! -x "$HELPER" ]]; then
  echo "==> build AgentBarCLI"
  swift build --product AgentBarCLI
fi

mkdir -p "$(dirname "$TARGET")"
ln -sf "$HELPER" "$TARGET"

echo "Linked $TARGET -> $HELPER"
echo "Try: ${TARGET} --help"
