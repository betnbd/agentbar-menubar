#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

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
