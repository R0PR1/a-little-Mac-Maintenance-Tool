#!/usr/bin/env bash

mm_config_defaults() {
    cat <<'EOF_DEFAULTS'
daily_enabled=true
daily_hour=09
daily_minute=15
weekly_enabled=false
weekly_day=0
weekly_hour=10
weekly_minute=00
weekly_upgrade=false
upgrade_casks=false
cleanup=true
check_macos=true
check_battery=true
check_time_machine=true
check_thermal=true
disk_warning=80
disk_critical=90
EOF_DEFAULTS
}

mm_config_allowed_key() {
    case "$1" in
        daily_enabled|daily_hour|daily_minute|weekly_enabled|weekly_day|weekly_hour|weekly_minute|weekly_upgrade|upgrade_casks|cleanup|check_macos|check_battery|check_time_machine|check_thermal|disk_warning|disk_critical)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

mm_config_default_value() {
    local key="$1"
    mm_config_defaults | awk -F= -v key="$key" '$1 == key { print substr($0, index($0, "=") + 1); exit }'
}

mm_config_kind() {
    case "$1" in
        daily_enabled|weekly_enabled|weekly_upgrade|upgrade_casks|cleanup|check_macos|check_battery|check_time_machine|check_thermal)
            printf 'bool\n'
            ;;
        daily_hour|weekly_hour)
            printf 'hour\n'
            ;;
        daily_minute|weekly_minute)
            printf 'minute\n'
            ;;
        weekly_day)
            printf 'weekday\n'
            ;;
        disk_warning|disk_critical)
            printf 'percent\n'
            ;;
        *)
            return 1
            ;;
    esac
}

mm_config_validate() {
    local key="$1"
    local value="$2"
    local kind warning critical

    mm_config_allowed_key "$key" || {
        mm_error "Unknown config key: $key"
        return 2
    }

    kind="$(mm_config_kind "$key")"
    case "$kind" in
        bool)
            mm_is_bool "$value" || {
                mm_error "Invalid boolean for $key: $value (use true or false)"
                return 2
            }
            ;;
        hour)
            mm_is_int_range "$value" 0 23 || {
                mm_error "Invalid hour for $key: $value (0-23)"
                return 2
            }
            ;;
        minute)
            mm_is_int_range "$value" 0 59 || {
                mm_error "Invalid minute for $key: $value (0-59)"
                return 2
            }
            ;;
        weekday)
            mm_is_int_range "$value" 0 6 || {
                mm_error "Invalid weekday for $key: $value (0=Sun .. 6=Sat)"
                return 2
            }
            ;;
        percent)
            mm_is_int_range "$value" 0 100 || {
                mm_error "Invalid percent for $key: $value (0-100)"
                return 2
            }
            ;;
    esac

    if [[ "$key" == 'disk_warning' || "$key" == 'disk_critical' ]]; then
        warning="$(mm_config_lookup disk_warning)"
        critical="$(mm_config_lookup disk_critical)"
        if [[ "$key" == 'disk_warning' ]]; then
            warning="$value"
        else
            critical="$value"
        fi
        if [[ $((10#$warning)) -ge $((10#$critical)) ]]; then
            mm_error 'disk_warning must be lower than disk_critical'
            return 2
        fi
    fi
}

mm_config_ensure() {
    mkdir -p "$MM_CONFIG_DIR"
    if [[ ! -f "$MM_CONFIG_FILE" ]]; then
        mm_config_defaults > "$MM_CONFIG_FILE"
        chmod 600 "$MM_CONFIG_FILE"
    fi
}

mm_config_read_file() {
    local key="$1"
    awk -F= -v key="$key" '
        $1 == key {
            print substr($0, index($0, "=") + 1)
            found = 1
            exit
        }
        END { if (!found) exit 1 }
    ' "$MM_CONFIG_FILE"
}

mm_config_lookup() {
    local key="$1"
    local value=""

    mm_config_allowed_key "$key" || return 2
    mm_config_ensure
    value="$(mm_config_read_file "$key" 2>/dev/null || true)"
    if [[ -z "$value" ]]; then
        value="$(mm_config_default_value "$key")"
    fi
    printf '%s\n' "$value"
}

mm_config_get() {
    mm_config_lookup "$1"
}

mm_config_write() {
    local key="$1"
    local value="$2"
    local tmp

    mm_config_ensure
    tmp="$(mktemp)"
    awk -F= -v key="$key" -v value="$value" '
        BEGIN { OFS = "=" }
        $1 == key { $2 = value; found = 1 }
        { print }
        END { if (!found) print key, value }
    ' "$MM_CONFIG_FILE" > "$tmp"
    mv "$tmp" "$MM_CONFIG_FILE"
    chmod 600 "$MM_CONFIG_FILE"
}

mm_config_set() {
    local key="$1"
    local value="$2"

    mm_config_validate "$key" "$value" || return $?
    mm_config_write "$key" "$value"
}

mm_config_command() {
    local subcommand="${1:-show}"
    local key value default_value

    case "$subcommand" in
        show)
            mm_config_ensure
            cat "$MM_CONFIG_FILE"
            ;;
        get)
            [[ $# -eq 2 ]] || {
                mm_error 'Usage: mm config get <key>'
                return 64
            }
            key="$2"
            mm_config_allowed_key "$key" || {
                mm_error "Unknown config key: $key"
                return 2
            }
            mm_config_get "$key"
            ;;
        set)
            [[ $# -eq 3 ]] || {
                mm_error 'Usage: mm config set <key> <value>'
                return 64
            }
            mm_config_set "$2" "$3"
            ;;
        reset)
            [[ $# -eq 2 ]] || {
                mm_error 'Usage: mm config reset <key>'
                return 64
            }
            key="$2"
            default_value="$(mm_config_default_value "$key")"
            [[ -n "$default_value" ]] || {
                mm_error "Unknown config key: $key"
                return 2
            }
            mm_config_set "$key" "$default_value"
            ;;
        *)
            mm_error "Unknown config command: $subcommand"
            return 64
            ;;
    esac
}
