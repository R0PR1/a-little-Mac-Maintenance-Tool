#!/usr/bin/env bash

mm_menubar_label() {
    printf 'io.mm.menubar\n'
}

mm_menubar_plist_path() {
    printf '%s/%s.plist\n' "$MM_LAUNCH_AGENTS_DIR" "$(mm_menubar_label)"
}

mm_menubar_require_macos() {
    if [[ "$(uname -s)" != 'Darwin' ]]; then
        mm_error 'The menu extra is macOS only.'
        return 2
    fi
}

mm_menubar_bin() {
    printf '%s/macos/build/MmExtra.app/Contents/MacOS/mm-extra\n' "$MM_PROJECT_DIR"
}

mm_menubar_app() {
    printf '%s/macos/build/MmExtra.app\n' "$MM_PROJECT_DIR"
}

mm_menubar_user_path() {
    printf '%s/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin\n' "$HOME"
}

mm_menubar_write_plist() {
    local extra="$1"
    local bin_path plist path
    bin_path="$(mm_bin_path)"
    plist="$(mm_menubar_plist_path)"
    path="$(mm_menubar_user_path)"
    mkdir -p "$MM_LAUNCH_AGENTS_DIR" "$MM_LOG_DIR"
    cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$(mm_menubar_label)</string>
  <key>ProgramArguments</key>
  <array>
    <string>$(mm_xml_escape "$extra")</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>EnvironmentVariables</key>
  <dict>
    <key>MM_BIN</key>
    <string>$(mm_xml_escape "$bin_path")</string>
    <key>PATH</key>
    <string>$(mm_xml_escape "$path")</string>
  </dict>
  <key>StandardOutPath</key>
  <string>$(mm_xml_escape "$MM_LOG_DIR")/menubar.log</string>
  <key>StandardErrorPath</key>
  <string>$(mm_xml_escape "$MM_LOG_DIR")/menubar.error.log</string>
</dict>
</plist>
EOF

    if mm_command_exists plutil; then
        plutil -lint "$plist" >/dev/null
    fi
}

mm_menubar_build() {
    local builder
    builder="$MM_PROJECT_DIR/scripts/build-menubar.sh"
    if [[ ! -x "$builder" ]]; then
        mm_error "Missing $builder"
        return 2
    fi
    "$builder"
}

mm_menubar_enable() {
    local plist extra
    mm_menubar_require_macos || return
    mm_command_exists swiftc || {
        mm_error 'Install Xcode Command Line Tools to build the menu extra (xcode-select --install).'
        return 2
    }
    mm_menubar_build || return

    extra="$(mm_menubar_bin)"
    [[ -x "$extra" ]] || {
        mm_error "Build did not produce $extra"
        return 2
    }

    plist="$(mm_menubar_plist_path)"
    mm_menubar_write_plist "$extra"

    if mm_command_exists launchctl; then
        launchctl bootout "$(mm_launchd_domain)/$(mm_menubar_label)" >/dev/null 2>&1 || true
        launchctl bootstrap "$(mm_launchd_domain)" "$plist"
    fi

    mm_ok "menu extra enabled"
    mm_info "Look for mm next to the clock. Click for status; Run check now is read-only (brew update)."
    mm_info "After upgrading mm, rebuild the extra: mm menubar disable && mm menubar enable"
}

mm_menubar_disable() {
    local plist extra
    mm_menubar_require_macos || return
    plist="$(mm_menubar_plist_path)"
    extra="$(mm_menubar_bin)"
    if mm_command_exists launchctl; then
        launchctl bootout "$(mm_launchd_domain)/$(mm_menubar_label)" >/dev/null 2>&1 || true
    fi
    rm -f "$plist"
    if mm_command_exists pkill; then
        pkill -f "$extra" >/dev/null 2>&1 || true
    fi
    mm_disabled 'menu extra disabled'
}

mm_menubar_status() {
    local plist
    plist="$(mm_menubar_plist_path)"
    if [[ "$(uname -s)" != 'Darwin' ]]; then
        mm_disabled 'menu extra (macOS only)'
        return 0
    fi
    if mm_command_exists launchctl && launchctl print "$(mm_launchd_domain)/$(mm_menubar_label)" >/dev/null 2>&1; then
        mm_ok 'menu extra enabled'
    elif [[ -f "$plist" ]]; then
        mm_warn 'menu extra installed but not loaded'
        mm_raise_state 1
    else
        mm_disabled 'menu extra disabled'
    fi
}

mm_menubar_command() {
    local subcommand="${1:-status}"

    case "$subcommand" in
        status)
            mm_menubar_status
            ;;
        enable)
            mm_menubar_enable
            ;;
        disable)
            mm_menubar_disable
            ;;
        *)
            mm_error 'Usage: mm menubar enable|disable|status'
            return 64
            ;;
    esac
}
