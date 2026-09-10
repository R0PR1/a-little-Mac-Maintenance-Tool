#!/usr/bin/env bash

mm_macos_updates() {
    if ! mm_command_exists softwareupdate; then
        mm_line_disabled 'softwareupdate' 'unavailable'
        return 0
    fi

    softwareupdate --list 2>&1 || true
}

mm_macos_auto_update_raw() {
    local key="$1"
    if ! mm_command_exists defaults; then
        return 1
    fi
    defaults read /Library/Preferences/com.apple.SoftwareUpdate "$key" 2>/dev/null
}

mm_parse_auto_update_flag() {
    local raw="$1"
    case "$raw" in
        1|true|YES|Yes)
            printf 'on\n'
            ;;
        0|false|NO|No)
            printf 'off\n'
            ;;
        *)
            printf 'unknown\n'
            ;;
    esac
}

mm_macos_auto_update_state() {
    local check download install

    check="$(mm_parse_auto_update_flag "$(mm_macos_auto_update_raw AutomaticCheckEnabled || true)")"
    download="$(mm_parse_auto_update_flag "$(mm_macos_auto_update_raw AutomaticDownload || true)")"
    install="$(mm_parse_auto_update_flag "$(mm_macos_auto_update_raw AutomaticallyInstallMacOSUpdates || true)")"

    if [[ "$check" == 'on' ]]; then
        printf 'check on'
        if [[ "$download" == 'on' ]]; then
            printf ' · download on'
        fi
        if [[ "$install" == 'on' ]]; then
            printf ' · install on'
        fi
        printf '\n'
        return 0
    fi

    if [[ "$check" == 'off' ]]; then
        printf 'disabled\n'
        return 1
    fi

    printf 'unknown\n'
    return 2
}

mm_macos_status_line() {
    local state
    local status=0

    state="$(mm_macos_auto_update_state)" || status=$?
    case "$status" in
        0)
            mm_line_ok 'macOS updates' "$state"
            ;;
        1)
            mm_line_warn 'macOS updates' "$state"
            mm_raise_state 1
            ;;
        *)
            mm_line_disabled 'macOS updates' 'unavailable'
            ;;
    esac
}
