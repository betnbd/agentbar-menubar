#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

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

echo "==> build"
swift build

echo "==> test"
swift test

echo "==> run"
swift run AgentBar "$@"
