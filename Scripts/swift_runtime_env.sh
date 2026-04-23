#!/usr/bin/env bash

agentbar_export_swift_runtime_env() {
  if [[ "$(uname -s)" != "Linux" ]]; then
    return 0
  fi

  local swiftly_root="${HOME}/.local/share/swiftly/toolchains/6.3.1/usr"
  local toolchain_lib="${swiftly_root}/lib"
  if [[ ! -d "$toolchain_lib" ]]; then
    return 0
  fi

  export SOURCEKIT_TOOLCHAIN_PATH="$swiftly_root"
  export LINUX_SOURCEKIT_LIB_PATH="$toolchain_lib"

  local -a runtime_paths=("$toolchain_lib")
  local compat_root="${HOME}/.local/compat"
  if [[ -d "$compat_root" ]]; then
    while IFS= read -r libdir; do
      runtime_paths+=("$libdir")
    done < <(find "$compat_root" -type d -path '*/usr/lib/*' | sort)
  fi

  local joined_paths=""
  local path=""
  for path in "${runtime_paths[@]}"; do
    if [[ -z "$joined_paths" ]]; then
      joined_paths="$path"
    else
      joined_paths="${joined_paths}:$path"
    fi
  done

  export LD_LIBRARY_PATH="${joined_paths}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
}

agentbar_require_tray_dev_packages() {
  if [[ "$(uname -s)" != "Linux" ]]; then
    return 0
  fi

  if command -v pkg-config >/dev/null 2>&1 \
    && pkg-config --exists ayatana-appindicator3-0.1 gtk+-3.0
  then
    return 0
  fi

  cat >&2 <<'EOF'
ERROR: AgentBar tray support requires GTK 3 and Ayatana AppIndicator development packages.
Install them on Ubuntu with:
  sudo apt install libgtk-3-dev libayatana-appindicator3-dev

GNOME tray visibility also requires the AppIndicator shell extension package:
  sudo apt install gnome-shell-extension-appindicator
EOF
  return 1
}
