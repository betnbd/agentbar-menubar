#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="${ROOT_DIR}/.build/lint-tools/bin"

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

ensure_tools() {
  # Always delegate to the installer so pinned versions are enforced.
  # The installer is idempotent and exits early when the expected versions are already present.
  "${ROOT_DIR}/Scripts/install_lint_tools.sh"
}

cmd="${1:-lint}"

case "$cmd" in
  lint)
    ensure_tools
    tool_env
    "${BIN_DIR}/swiftformat" Sources Tests --lint
    "${BIN_DIR}/swiftlint" --strict
    ;;
  format)
    ensure_tools
    tool_env
    "${BIN_DIR}/swiftformat" Sources Tests
    ;;
  *)
    printf 'Usage: %s [lint|format]\n' "$(basename "$0")" >&2
    exit 2
    ;;
esac
