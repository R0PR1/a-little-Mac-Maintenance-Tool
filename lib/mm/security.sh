#!/usr/bin/env bash

mm_parse_filevault() {
    local output="$1"
    if printf '%s\n' "$output" | grep -qi 'FileVault is On'; then
        printf 'on\n'
    elif printf '%s\n' "$output" | grep -qi 'FileVault is Off'; then
        printf 'off\n'
    else
        printf 'unknown\n'
    fi
}

mm_parse_sip() {
    local output="$1"
    if printf '%s\n' "$output" | grep -qi 'enabled'; then
        printf 'on\n'
    elif printf '%s\n' "$output" | grep -qi 'disabled'; then
        printf 'off\n'
    else
        printf 'unknown\n'
    fi
}

mm_parse_gatekeeper() {
    local output="$1"
    if printf '%s\n' "$output" | grep -qi 'assessments enabled'; then
        printf 'on\n'
    elif printf '%s\n' "$output" | grep -qi 'assessments disabled'; then
        printf 'off\n'
    else
        printf 'unknown\n'
    fi
}

mm_parse_firewall() {
    local output="$1"
    if printf '%s\n' "$output" | grep -qi 'enabled'; then
        printf 'on\n'
    elif printf '%s\n' "$output" | grep -qi 'disabled'; then
        printf 'off\n'
    else
        printf 'unknown\n'
    fi
}

mm_firewall_bin() {
    if [[ -n "${MM_FIREWALL_BIN:-}" ]]; then
        printf '%s\n' "$MM_FIREWALL_BIN"
        return 0
    fi
    if [[ -x /usr/libexec/ApplicationFirewall/socketfilterfw ]]; then
        printf '%s\n' '/usr/libexec/ApplicationFirewall/socketfilterfw'
        return 0
    fi
    return 1
}

mm_security_report_item() {
    local compact="$1"
    local label="$2"
    local state="$3"
    local raise_unknown="${4:-0}"

    case "$state" in
        on)
            if [[ "$compact" -eq 1 ]]; then
                mm_ok "$label"
            else
                mm_line_ok "$label" 'enabled'
            fi
            ;;
        off)
            if [[ "$compact" -eq 1 ]]; then
                mm_warn "$label"
            else
                mm_line_warn "$label" 'disabled'
            fi
            mm_raise_state 1
            ;;
        *)
            if [[ "$compact" -eq 1 ]]; then
                mm_disabled "$label"
            else
                mm_line_disabled "$label" 'unavailable'
            fi
            if [[ "$raise_unknown" -eq 1 ]]; then
                mm_raise_state 1
            fi
            ;;
    esac
}

mm_security_status_lines() {
    local fv sip gk
    fv='unknown'
    sip='unknown'
    gk='unknown'

    if mm_command_exists fdesetup; then
        fv="$(mm_parse_filevault "$(fdesetup status 2>/dev/null || true)")"
    fi
    if mm_command_exists csrutil; then
        sip="$(mm_parse_sip "$(csrutil status 2>/dev/null || true)")"
    fi
    if mm_command_exists spctl; then
        gk="$(mm_parse_gatekeeper "$(spctl --status 2>/dev/null || true)")"
    fi

    mm_security_report_item 1 'FileVault' "$fv"
    mm_security_report_item 1 'SIP' "$sip"
    mm_security_report_item 1 'Gatekeeper' "$gk"
}

mm_security() {
    local fv sip gk fw auto_state firewall_bin
    fv='unknown'
    sip='unknown'
    gk='unknown'
    fw='unknown'
    auto_state='unknown'

    mm_section 'SECURITY'

    if mm_command_exists fdesetup; then
        fv="$(mm_parse_filevault "$(fdesetup status 2>/dev/null || true)")"
    fi
    if mm_command_exists csrutil; then
        sip="$(mm_parse_sip "$(csrutil status 2>/dev/null || true)")"
    fi
    if mm_command_exists spctl; then
        gk="$(mm_parse_gatekeeper "$(spctl --status 2>/dev/null || true)")"
    fi
    firewall_bin="$(mm_firewall_bin || true)"
    if [[ -n "$firewall_bin" ]]; then
        fw="$(mm_parse_firewall "$("$firewall_bin" --getglobalstate 2>/dev/null || true)")"
    fi
    auto_state="$(mm_macos_auto_update_state)" || true
    if [[ -z "$auto_state" ]]; then
        auto_state='unknown'
    fi

    mm_security_report_item 0 'FileVault' "$fv"
    mm_security_report_item 0 'SIP' "$sip"
    mm_security_report_item 0 'Gatekeeper' "$gk"
    mm_security_report_item 0 'Firewall' "$fw"

    case "$auto_state" in
        disabled)
            mm_line_warn 'Auto updates' 'disabled'
            mm_raise_state 1
            ;;
        unknown|'')
            mm_line_disabled 'Auto updates' 'unavailable'
            ;;
        *)
            mm_line_ok 'Auto updates' "$auto_state"
            ;;
    esac

    return "$MM_EXIT_STATE"
}
