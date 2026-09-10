#!/usr/bin/env bash

mm_launchd_label() {
    printf 'io.mm.%s\n' "$1"
}

mm_launchd_plist_path() {
    printf '%s/%s.plist\n' "$MM_LAUNCH_AGENTS_DIR" "$(mm_launchd_label "$1")"
}

mm_launchd_domain() {
    printf 'gui/%s\n' "$(id -u)"
}

mm_launchd_is_loaded() {
    local job="$1"
    mm_command_exists launchctl || return 1
    launchctl print "$(mm_launchd_domain)/$(mm_launchd_label "$job")" >/dev/null 2>&1
}

mm_launchd_template() {
    printf '%s/launchd/mm.%s.plist.template\n' "$MM_PROJECT_DIR" "$1"
}

mm_launchd_render() {
    local job="$1"
    local dest="$2"
    local template content
    local hour minute weekday bin_path log_dir
    local hour_int minute_int weekday_int

    template="$(mm_launchd_template "$job")"
    if [[ ! -f "$template" ]]; then
        mm_error "Missing launchd template for $job"
        return 2
    fi

    bin_path="$(mm_xml_escape "$(mm_bin_path)")"
    log_dir="$(mm_xml_escape "$MM_LOG_DIR")"

    if [[ "$job" == 'daily' ]]; then
        hour="$(mm_config_get daily_hour)"
        minute="$(mm_config_get daily_minute)"
        weekday='0'
    else
        hour="$(mm_config_get weekly_hour)"
        minute="$(mm_config_get weekly_minute)"
        weekday="$(mm_config_get weekly_day)"
    fi

    hour_int=$((10#$hour))
    minute_int=$((10#$minute))
    weekday_int=$((10#$weekday))

    content="$(cat "$template")"
    content="${content//\{\{MM_BIN\}\}/$bin_path}"
    content="${content//\{\{LOG_DIR\}\}/$log_dir}"
    content="${content//\{\{HOUR\}\}/$hour_int}"
    content="${content//\{\{MINUTE\}\}/$minute_int}"
    content="${content//\{\{WEEKDAY\}\}/$weekday_int}"

    mkdir -p "$(dirname "$dest")" "$MM_LOG_DIR"
    printf '%s\n' "$content" > "$dest"

    if mm_command_exists plutil; then
        plutil -lint "$dest" >/dev/null
    fi
}

mm_launchd_bootout() {
    local job="$1"
    mm_command_exists launchctl || return 0
    launchctl bootout "$(mm_launchd_domain)/$(mm_launchd_label "$job")" >/dev/null 2>&1 || true
}

mm_launchd_bootstrap() {
    local job="$1"
    local plist
    plist="$(mm_launchd_plist_path "$job")"
    mm_command_exists launchctl || {
        mm_error 'launchctl is unavailable on this system.'
        return 2
    }
    launchctl bootstrap "$(mm_launchd_domain)" "$plist"
}

mm_schedule_enable() {
    local job="$1"
    local plist

    plist="$(mm_launchd_plist_path "$job")"
    mm_launchd_render "$job" "$plist"
    mm_launchd_bootout "$job"
    mm_launchd_bootstrap "$job"

    if [[ "$job" == 'daily' ]]; then
        mm_config_set daily_enabled true
    else
        mm_config_set weekly_enabled true
    fi

    mm_ok "$job enabled"
}

mm_schedule_disable() {
    local job="$1"
    local plist

    plist="$(mm_launchd_plist_path "$job")"
    mm_launchd_bootout "$job"
    rm -f "$plist"

    if [[ "$job" == 'daily' ]]; then
        mm_config_set daily_enabled false
    else
        mm_config_set weekly_enabled false
    fi

    mm_disabled "$job disabled"
}

mm_schedule_reload() {
    local job
    local reloaded=0

    for job in daily weekly; do
        if [[ -f "$(mm_launchd_plist_path "$job")" ]]; then
            mm_launchd_render "$job" "$(mm_launchd_plist_path "$job")"
            mm_launchd_bootout "$job"
            mm_launchd_bootstrap "$job"
            if mm_command_exists launchctl; then
                launchctl kickstart -k "$(mm_launchd_domain)/$(mm_launchd_label "$job")" >/dev/null 2>&1 || true
            fi
            reloaded=1
            mm_ok "$job reloaded"
        fi
    done

    if [[ "$reloaded" -eq 0 ]]; then
        mm_info 'No scheduled jobs to reload. Enable one with mm schedule enable daily.'
        return 0
    fi
}

mm_schedule_status() {
    local job plist
    for job in daily weekly; do
        plist="$(mm_launchd_plist_path "$job")"
        if mm_launchd_is_loaded "$job"; then
            mm_ok "$job enabled"
        elif [[ -f "$plist" ]]; then
            mm_warn "$job installed but not loaded"
        else
            mm_disabled "$job disabled"
        fi
    done
}

mm_schedule_command() {
    local subcommand="${1:-status}"
    local job="${2:-}"

    case "$subcommand" in
        status)
            mm_schedule_status
            ;;
        enable|disable)
            [[ "$job" == 'daily' || "$job" == 'weekly' ]] || {
                mm_error 'Usage: mm schedule enable|disable daily|weekly'
                return 64
            }
            if [[ "$subcommand" == 'enable' ]]; then
                mm_schedule_enable "$job"
            else
                mm_schedule_disable "$job"
            fi
            ;;
        reload)
            mm_schedule_reload
            ;;
        *)
            mm_error "Unknown schedule command: $subcommand"
            return 64
            ;;
    esac
}
