#!/usr/bin/env bash

mm_parse_memory_pressure() {
    local output="$1"

    case "$output" in
        *critical*|*RED*|*red\ zone*)
            printf 'critical\n'
            ;;
        *warn*|*YELLOW*|*yellow\ zone*)
            printf 'warn\n'
            ;;
        *nominal*|*normal*|*GREEN*|*green\ zone*|*healthy*)
            printf 'healthy\n'
            ;;
        *)
            printf 'unknown\n'
            ;;
    esac
}

mm_parse_thermal() {
    local output="$1"
    local limit

    if [[ -z "$output" ]]; then
        printf 'unknown\n'
        return 0
    fi

    if printf '%s\n' "$output" | grep -qi 'no thermal warning'; then
        printf 'normal\n'
        return 0
    fi

    limit="$(printf '%s\n' "$output" | awk -F= '/CPU_Speed_Limit/ { gsub(/[[:space:]]/, "", $2); print $2; exit }')"
    if [[ -n "$limit" && "$limit" =~ ^[0-9]+$ && $((10#$limit)) -lt 100 ]]; then
        printf 'throttled\n'
        return 0
    fi

    printf 'normal\n'
}

mm_parse_battery_percent() {
    local output="$1"
    local percent=""
    percent="$(printf '%s\n' "$output" | grep -Eo '[0-9]+%' | head -n 1 | tr -d '%')" || true
    printf '%s\n' "$percent"
}

mm_extract_backup_stamp() {
    local path="$1"
    if [[ "$path" =~ ([0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}) ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
        return 0
    fi
    return 1
}

mm_disk_status() {
    local disk_pct disk_free warning critical

    disk_pct="$(df -Pk / 2>/dev/null | awk 'NR == 2 { gsub(/%/, "", $5); print $5 }')" || true
    disk_free="$(df -h / 2>/dev/null | awk 'NR == 2 { print $4 }')" || true
    warning="$(mm_config_get disk_warning)"
    critical="$(mm_config_get disk_critical)"

    if [[ -z "$disk_pct" || ! "$disk_pct" =~ ^[0-9]+$ ]]; then
        mm_line_disabled 'Disk' 'unavailable'
        return 0
    fi

    if [[ $((10#$disk_pct)) -ge $((10#$critical)) ]]; then
        mm_line_error 'Disk' "${disk_pct}% · ${disk_free:-?} free"
        mm_raise_state 2
    elif [[ $((10#$disk_pct)) -ge $((10#$warning)) ]]; then
        mm_line_warn 'Disk' "${disk_pct}% · ${disk_free:-?} free"
        mm_raise_state 1
    else
        mm_line_ok 'Disk' "${disk_pct}% · ${disk_free:-?} free"
    fi
}

mm_memory_status() {
    local raw level

    if mm_command_exists memory_pressure; then
        raw="$(memory_pressure 2>/dev/null || true)"
        level="$(mm_parse_memory_pressure "$raw")"
    elif mm_command_exists sysctl; then
        raw="$(sysctl -n kern.memorystatus_vm_pressure_level 2>/dev/null || true)"
        case "$raw" in
            1) level='healthy' ;;
            2) level='warn' ;;
            4|8) level='critical' ;;
            *) level='unknown' ;;
        esac
    else
        mm_line_disabled 'Memory' 'unavailable'
        return 0
    fi

    case "$level" in
        healthy)
            mm_line_ok 'Memory' 'healthy'
            ;;
        warn)
            mm_line_warn 'Memory' 'pressure'
            mm_raise_state 1
            ;;
        critical)
            mm_line_error 'Memory' 'critical pressure'
            mm_raise_state 2
            ;;
        *)
            mm_line_disabled 'Memory' 'unavailable'
            ;;
    esac
}

mm_thermal_status() {
    local enabled raw level

    enabled="$(mm_config_get check_thermal)"
    if [[ "$enabled" != 'true' ]]; then
        return 0
    fi

    if ! mm_command_exists pmset; then
        mm_line_disabled 'Thermal' 'unavailable'
        return 0
    fi

    raw="$(pmset -g therm 2>/dev/null || true)"
    level="$(mm_parse_thermal "$raw")"
    case "$level" in
        normal)
            mm_line_ok 'Thermal' 'normal'
            ;;
        throttled)
            mm_line_warn 'Thermal' 'throttled'
            mm_raise_state 1
            ;;
        *)
            mm_line_disabled 'Thermal' 'unavailable'
            ;;
    esac
}

mm_battery_status() {
    local enabled raw percent

    enabled="$(mm_config_get check_battery)"
    if [[ "$enabled" != 'true' ]]; then
        return 0
    fi

    if ! mm_command_exists pmset; then
        mm_line_disabled 'Battery' 'unavailable'
        return 0
    fi

    raw="$(pmset -g batt 2>/dev/null || true)"
    if ! printf '%s\n' "$raw" | grep -q 'InternalBattery'; then
        mm_line_disabled 'Battery' 'none'
        return 0
    fi

    percent="$(mm_parse_battery_percent "$raw")"
    if [[ -z "$percent" ]]; then
        mm_line_ok 'Battery' 'detected'
        return 0
    fi

    if [[ $((10#$percent)) -le 10 ]]; then
        mm_line_warn 'Battery' "${percent}%"
        mm_raise_state 1
    else
        mm_line_ok 'Battery' "${percent}%"
    fi
}

mm_time_machine_status() {
    local enabled backup stamp epoch age

    enabled="$(mm_config_get check_time_machine)"
    if [[ "$enabled" != 'true' ]]; then
        return 0
    fi

    if ! mm_command_exists tmutil; then
        mm_line_disabled 'Time Machine' 'unavailable'
        return 0
    fi

    backup="$(tmutil latestbackup 2>/dev/null || true)"
    if [[ -z "$backup" ]]; then
        mm_line_warn 'Time Machine' 'no backup'
        mm_raise_state 1
        return 0
    fi

    stamp="$(mm_extract_backup_stamp "$backup" || true)"
    if [[ -z "$stamp" ]]; then
        mm_line_ok 'Time Machine' 'accessible'
        return 0
    fi

    epoch="$(mm_stamp_to_epoch "$stamp" || true)"
    if [[ -z "$epoch" ]]; then
        mm_line_ok 'Time Machine' 'accessible'
        return 0
    fi

    age="$(mm_format_age "$epoch" "$(mm_now)")"
    mm_line_ok 'Time Machine' "$age"
}

mm_host_header() {
    local version model macos arch

    version="$(mm_version_value)"
    model='Mac'
    macos='unknown'
    arch="$(uname -m)"

    if mm_command_exists system_profiler; then
        model="$(system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Model Name/ { print $2; exit }')" || true
    fi
    if [[ -z "$model" ]]; then
        model='Mac'
    fi

    if mm_command_exists sw_vers; then
        macos="$(sw_vers -productVersion 2>/dev/null || true)"
    fi
    if [[ -z "$macos" ]]; then
        macos='unknown'
    fi

    if [[ "${MM_RECORD:-0}" == '1' ]]; then
        # Consumed by lib/mm/json.sh
        # shellcheck disable=SC2034
        MM_SNAP_VERSION="$version"
        # shellcheck disable=SC2034
        MM_SNAP_MODEL="$model"
        # shellcheck disable=SC2034
        MM_SNAP_MACOS="$macos"
        # shellcheck disable=SC2034
        MM_SNAP_ARCH="$arch"
    fi

    printf 'MM %s\n' "$version"
    printf '%s · macOS %s · %s\n' "$model" "$macos" "$arch"
}

mm_automation_status() {
    local daily_enabled weekly_enabled weekly_upgrade
    local daily_hour daily_minute weekly_day weekly_hour weekly_minute
    local daily_time weekly_time

    daily_enabled="$(mm_config_get daily_enabled)"
    weekly_enabled="$(mm_config_get weekly_enabled)"
    weekly_upgrade="$(mm_config_get weekly_upgrade)"
    daily_hour="$(mm_config_get daily_hour)"
    daily_minute="$(mm_config_get daily_minute)"
    weekly_day="$(mm_config_get weekly_day)"
    weekly_hour="$(mm_config_get weekly_hour)"
    weekly_minute="$(mm_config_get weekly_minute)"

    daily_time="$(mm_zero_pad "$daily_hour"):$(mm_zero_pad "$daily_minute")"
    weekly_time="$(mm_weekday_name "$weekly_day") $(mm_zero_pad "$weekly_hour"):$(mm_zero_pad "$weekly_minute")"

    if [[ "$daily_enabled" == 'true' ]]; then
        if mm_launchd_is_loaded daily; then
            mm_line_ok 'Daily check' "$daily_time"
        else
            mm_line_warn 'Daily check' "not loaded · $daily_time"
            mm_raise_state 1
        fi
    else
        mm_line_disabled 'Daily check' 'disabled'
    fi

    if [[ "$weekly_enabled" == 'true' && "$weekly_upgrade" == 'true' ]]; then
        if mm_launchd_is_loaded weekly; then
            mm_line_ok 'Weekly upgrade' "$weekly_time"
        else
            mm_line_warn 'Weekly upgrade' "not loaded · $weekly_time"
            mm_raise_state 1
        fi
    else
        mm_line_disabled 'Weekly upgrade' 'disabled'
    fi
}

mm_status() {
    local formula_count=0

    if [[ "${1:-}" == '--json' ]]; then
        mm_status_json
        return
    fi

    MM_EXIT_STATE=0
    mm_config_ensure
    mm_host_header

    mm_section 'AUTOMATION'
    mm_automation_status

    mm_section 'HOMEBREW'
    mm_brew_status

    mm_section 'SYSTEM'
    mm_disk_status
    mm_memory_status
    mm_thermal_status
    mm_battery_status
    mm_time_machine_status
    if [[ "$(mm_config_get check_macos)" == 'true' ]]; then
        mm_macos_status_line
    fi

    mm_section 'SECURITY'
    mm_security_status_lines

    printf '\n'
    case "$MM_EXIT_STATE" in
        0)
            mm_ok "$(mm_pad_label 'STATUS')OK"
            ;;
        1)
            mm_warn "$(mm_pad_label 'STATUS')ATTENTION"
            if mm_brew_present; then
                formula_count="$(mm_brew_outdated_count formula)"
                if [[ "$formula_count" -gt 0 ]]; then
                    mm_hint 'mm upgrade'
                fi
            fi
            if [[ "$(mm_config_get daily_enabled)" == 'true' ]] && ! mm_launchd_is_loaded daily; then
                mm_hint 'mm schedule enable daily'
            fi
            ;;
        *)
            mm_error "$(mm_pad_label 'STATUS')ACTION REQUIRED"
            mm_hint 'mm doctor'
            ;;
    esac

    return "$MM_EXIT_STATE"
}

mm_doctor() {
    MM_EXIT_STATE=0

    mm_section 'SYSTEM'
    if mm_command_exists sw_vers; then
        sw_vers || true
    fi
    uname -a || true
    df -h / || true
    if mm_command_exists memory_pressure; then
        memory_pressure 2>/dev/null || true
    fi
    if mm_command_exists sysctl; then
        sysctl vm.swapusage 2>/dev/null || true
        sysctl vm.loadavg 2>/dev/null || true
    fi
    if mm_command_exists pmset; then
        pmset -g therm 2>/dev/null || true
        pmset -g batt 2>/dev/null || true
    fi
    if mm_command_exists tmutil; then
        tmutil latestbackup 2>/dev/null || printf 'Time Machine: no latest backup\n'
    fi

    mm_section 'HOMEBREW'
    mm_brew_doctor_summary

    mm_section 'MACOS UPDATES'
    mm_macos_updates

    mm_security
    return "$MM_EXIT_STATE"
}

mm_logs() {
    local target="${1:-all}"
    mkdir -p "$MM_LOG_DIR"

    case "$target" in
        all)
            local found=0
            local file
            for file in "$MM_LOG_DIR"/*.log; do
                if [[ -e "$file" ]]; then
                    found=1
                    printf '\n==> %s <==\n' "$file"
                    tail -n 50 "$file"
                fi
            done
            if [[ "$found" -eq 0 ]]; then
                mm_info 'No logs yet. Enable a schedule with mm schedule enable daily.'
            fi
            ;;
        daily|weekly)
            local log_file="$MM_LOG_DIR/$target.log"
            if [[ -f "$log_file" ]]; then
                tail -n 100 "$log_file"
            else
                mm_info "No $target log yet."
            fi
            ;;
        --follow)
            touch "$MM_LOG_DIR/daily.log" "$MM_LOG_DIR/weekly.log"
            tail -f "$MM_LOG_DIR/daily.log" "$MM_LOG_DIR/weekly.log"
            ;;
        *)
            mm_error 'Usage: mm logs [daily|weekly|--follow]'
            return 64
            ;;
    esac
}

mm_internal() {
    local command="${1:-}"
    mkdir -p "$MM_LOG_DIR"

    case "$command" in
        daily)
            mm_run_locked "daily" mm_internal_daily
            ;;
        weekly)
            mm_run_locked "weekly" mm_internal_weekly
            ;;
        *)
            mm_error 'Unknown internal command.'
            return 64
            ;;
    esac
}

mm_internal_daily() {
    printf '=== %s daily ===\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')"
    if mm_brew_present; then
        mm_brew_update
    else
        printf 'Homebrew not installed; skipped brew update.\n'
    fi
}

mm_internal_weekly() {
    printf '=== %s weekly ===\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')"
    if [[ "$(mm_config_get weekly_upgrade)" == 'true' ]]; then
        mm_brew_upgrade
    elif mm_brew_present; then
        mm_brew_update
    else
        printf 'Homebrew not installed; skipped brew update.\n'
    fi
}
