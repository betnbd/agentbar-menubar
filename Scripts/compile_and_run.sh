#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

source "${ROOT_DIR}/Scripts/swift_runtime_env.sh"
agentbar_export_swift_runtime_env

echo "==> build"
swift build

echo "==> test"
swift test

echo "==> run"
swift run AgentBar "$@"
