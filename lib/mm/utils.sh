#!/usr/bin/env bash

MM_PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MM_VERSION_FILE="$MM_PROJECT_DIR/VERSION"
MM_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/mm"
MM_CONFIG_FILE="$MM_CONFIG_DIR/config"
MM_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/Library/Caches}/mm"
MM_VERSION_CACHE="$MM_CACHE_DIR/remote-version"
MM_LOG_DIR="${MM_LOG_DIR:-$HOME/Library/Logs/mm}"
MM_LAUNCH_AGENTS_DIR="${MM_LAUNCH_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
MM_EXIT_STATE=0
MM_RUN_LOCK="$MM_CACHE_DIR/run.lock"
MM_STATUS_CACHE="$MM_CACHE_DIR/last-status.json"
MM_RECORD=0
# Snapshot fields are filled during `mm status --json` and read in json.sh.
# shellcheck disable=SC2034
MM_SNAP_LINES=()
# shellcheck disable=SC2034
MM_SNAP_HINTS=()
# shellcheck disable=SC2034
MM_SNAP_VERSION=''
# shellcheck disable=SC2034
MM_SNAP_MODEL=''
# shellcheck disable=SC2034
MM_SNAP_MACOS=''
# shellcheck disable=SC2034
MM_SNAP_ARCH=''
export MM_PROJECT_DIR MM_VERSION_FILE MM_CONFIG_DIR MM_CONFIG_FILE
export MM_CACHE_DIR MM_VERSION_CACHE MM_LOG_DIR MM_LAUNCH_AGENTS_DIR MM_EXIT_STATE
export MM_RUN_LOCK MM_STATUS_CACHE MM_RECORD
export MM_SNAP_LINES MM_SNAP_HINTS MM_SNAP_VERSION MM_SNAP_MODEL MM_SNAP_MACOS MM_SNAP_ARCH

mm_command_exists() {
    command -v "$1" >/dev/null 2>&1
}

mm_pid_alive() {
    local pid="$1"
    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    kill -0 "$pid" 2>/dev/null
}

mm_run_lock_acquire() {
    local job="$1"
    mkdir -p "$MM_CACHE_DIR"
    printf 'job=%s\npid=%s\nstarted_at=%s\n' "$job" "$$" "$(mm_now)" > "$MM_RUN_LOCK"
}

mm_run_lock_release() {
    local pid
    if [[ -f "$MM_RUN_LOCK" ]]; then
        pid="$(awk -F= '$1=="pid" { print $2; exit }' "$MM_RUN_LOCK")"
        if [[ "$pid" == "$$" ]]; then
            rm -f "$MM_RUN_LOCK"
        fi
    fi
}

mm_run_lock_read() {
    local job pid started
    [[ -f "$MM_RUN_LOCK" ]] || return 1
    job="$(awk -F= '$1=="job" { print $2; exit }' "$MM_RUN_LOCK")"
    pid="$(awk -F= '$1=="pid" { print $2; exit }' "$MM_RUN_LOCK")"
    started="$(awk -F= '$1=="started_at" { print $2; exit }' "$MM_RUN_LOCK")"
    if ! mm_pid_alive "$pid"; then
        rm -f "$MM_RUN_LOCK"
        return 1
    fi
    printf '%s\t%s\t%s\n' "$job" "$pid" "$started"
}

mm_run_locked() {
    local job="$1"
    local rc=0
    shift
    mm_run_lock_acquire "$job"
    "$@" || rc=$?
    mm_run_lock_release
    return "$rc"
}

mm_now() {
    printf '%s\n' "${MM_MOCK_NOW:-$(date +%s)}"
}

mm_raise_state() {
    local new_state="$1"
    if [[ "$new_state" -gt "$MM_EXIT_STATE" ]]; then
        MM_EXIT_STATE="$new_state"
    fi
}

mm_version_value() {
    if [[ -f "$MM_VERSION_FILE" ]]; then
        tr -d '[:space:]' < "$MM_VERSION_FILE"
    else
        printf '%s\n' 'dev'
    fi
}

mm_version_compare() {
    local left="$1"
    local right="$2"
    local first
    first="$(printf '%s\n%s\n' "$left" "$right" | sort -V | head -n 1)"
    if [[ "$left" == "$right" ]]; then
        printf '%s\n' '0'
    elif [[ "$first" == "$left" ]]; then
        printf '%s\n' '-1'
    else
        printf '%s\n' '1'
    fi
}

mm_version() {
    local local_version remote_version
    local_version="$(mm_version_value)"
    printf 'mm %s\n' "$local_version"

    if [[ -f "$MM_VERSION_CACHE" ]]; then
        remote_version="$(awk -F= '$1=="version" {print $2; exit}' "$MM_VERSION_CACHE")"
        if [[ -n "$remote_version" && "$(mm_version_compare "$local_version" "$remote_version")" == '-1' ]]; then
            mm_info "update available: $remote_version (cached)"
        fi
    fi
}

mm_write_version_cache() {
    local remote_version="$1"
    mkdir -p "$MM_CACHE_DIR"
    printf 'version=%s\nchecked_at=%s\n' "$remote_version" "$(mm_now)" > "$MM_VERSION_CACHE"
}

mm_bin_path() {
    local resolved
    if [[ -n "${MM_BIN_PATH:-}" ]]; then
        printf '%s\n' "$MM_BIN_PATH"
        return 0
    fi
    resolved="$(command -v mm 2>/dev/null || true)"
    if [[ -n "$resolved" ]]; then
        printf '%s\n' "$resolved"
        return 0
    fi
    printf '%s\n' "$MM_PROJECT_DIR/bin/mm"
}

mm_xml_escape() {
    local s="$1"
    s="${s//&/&amp;}"
    s="${s//</&lt;}"
    s="${s//>/&gt;}"
    s="${s//\"/&quot;}"
    printf '%s' "$s"
}

mm_is_bool() {
    [[ "$1" == 'true' || "$1" == 'false' ]]
}

mm_is_int_range() {
    local val="$1"
    local min="$2"
    local max="$3"
    local n

    [[ "$val" =~ ^[0-9]+$ ]] || return 1
    n=$((10#$val))
    [[ "$n" -ge "$min" && "$n" -le "$max" ]]
}

mm_zero_pad() {
    printf '%02d' "$((10#$1))"
}

mm_weekday_name() {
    case "$((10#$1))" in
        0) printf 'Sun' ;;
        1) printf 'Mon' ;;
        2) printf 'Tue' ;;
        3) printf 'Wed' ;;
        4) printf 'Thu' ;;
        5) printf 'Fri' ;;
        6) printf 'Sat' ;;
        *) printf '%s' "$1" ;;
    esac
}

mm_stamp_to_epoch() {
    local stamp="$1"
    local epoch y mo d h mi s

    if epoch="$(date -j -f '%Y-%m-%d-%H%M%S' "$stamp" '+%s' 2>/dev/null)"; then
        printf '%s\n' "$epoch"
        return 0
    fi

    y="${stamp:0:4}"
    mo="${stamp:5:2}"
    d="${stamp:8:2}"
    h="${stamp:11:2}"
    mi="${stamp:13:2}"
    s="${stamp:15:2}"
    date -d "${y}-${mo}-${d} ${h}:${mi}:${s}" '+%s' 2>/dev/null
}

mm_format_age() {
    local then_epoch="$1"
    local now_epoch="$2"
    local delta

    delta=$((now_epoch - then_epoch))
    if [[ "$delta" -lt 0 ]]; then
        delta=0
    fi

    if [[ "$delta" -lt 60 ]]; then
        printf 'just now'
    elif [[ "$delta" -lt 3600 ]]; then
        printf '%sm ago' "$((delta / 60))"
    elif [[ "$delta" -lt 86400 ]]; then
        printf '%sh ago' "$((delta / 3600))"
    else
        printf '%sd ago' "$((delta / 86400))"
    fi
}

mm_homebrew_prefix() {
    local brew_bin prefix

    brew_bin="$(mm_brew_bin 2>/dev/null)" || return 1
    prefix="$("$brew_bin" --prefix 2>/dev/null)" || true
    if [[ -n "$prefix" ]]; then
        printf '%s\n' "$prefix"
        return 0
    fi

    if [[ -x /opt/homebrew/bin/brew ]]; then
        printf '%s\n' '/opt/homebrew'
        return 0
    fi

    if [[ -x /usr/local/bin/brew ]]; then
        printf '%s\n' '/usr/local'
        return 0
    fi

    return 1
}

mm_brew_bin() {
    if mm_command_exists brew; then
        command -v brew
        return 0
    fi

    if [[ -x /opt/homebrew/bin/brew ]]; then
        printf '%s\n' '/opt/homebrew/bin/brew'
        return 0
    fi

    if [[ -x /usr/local/bin/brew ]]; then
        printf '%s\n' '/usr/local/bin/brew'
        return 0
    fi

    return 1
}

mm_help() {
    cat <<'HELP'
Usage: mm [command]

A tiny, safe health and maintenance CLI for macOS.

Commands:
  status        Show concise Mac health dashboard (default)
  update        Update Homebrew metadata and list outdated packages
  upgrade       Upgrade Homebrew formulae explicitly
  doctor        Show detailed diagnostics
  security      Show macOS security status
  logs          Show maintenance logs
  config        Show or edit configuration
  schedule      Manage launchd automation
  menubar       Enable the macOS menu extra
  self-update   Update mm according to installation method
  version       Show mm version
  help          Show this help

`mm` is an alias for `mm status`. It never upgrades packages or
changes system settings unless you run an explicit mutating command.
HELP
}
