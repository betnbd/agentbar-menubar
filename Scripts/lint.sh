#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="${ROOT_DIR}/.build/lint-tools/bin"

source "${ROOT_DIR}/Scripts/swift_runtime_env.sh"

ensure_tools() {
  # Always delegate to the installer so pinned versions are enforced.
  # The installer is idempotent and exits early when the expected versions are already present.
  "${ROOT_DIR}/Scripts/install_lint_tools.sh"
}

cmd="${1:-lint}"

case "$cmd" in
  lint)
    ensure_tools
    agentbar_export_swift_runtime_env
    "${BIN_DIR}/swiftformat" Sources Tests --lint
    "${BIN_DIR}/swiftlint" --strict
    ;;
  format)
    ensure_tools
    agentbar_export_swift_runtime_env
    "${BIN_DIR}/swiftformat" Sources Tests
    ;;
  *)
    printf 'Usage: %s [lint|format]\n' "$(basename "$0")" >&2
    exit 2
    ;;
esac
