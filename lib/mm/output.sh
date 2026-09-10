#!/usr/bin/env bash

MM_COLOR_ENABLED=0
if [[ -t 1 ]]; then
    MM_COLOR_ENABLED=1
fi

mm_color() {
    local code="$1"
    local text="$2"

    if [[ "$MM_COLOR_ENABLED" -eq 1 ]]; then
        printf '\033[%sm%s\033[0m' "$code" "$text"
    else
        printf '%s' "$text"
    fi
}

mm_ok() { printf '%s %s\n' "$(mm_color '32' '✓')" "$1"; }
mm_warn() { printf '%s %s\n' "$(mm_color '33' '!')" "$1"; }
mm_error() { printf '%s %s\n' "$(mm_color '31' '✗')" "$1"; }
mm_info() { printf '%s %s\n' "$(mm_color '36' '·')" "$1"; }
mm_disabled() { printf '%s %s\n' "$(mm_color '90' '−')" "$1"; }

mm_record_line() {
    local state="$1"
    local label="$2"
    local value="$3"
    if [[ "${MM_RECORD:-0}" == '1' ]]; then
        MM_SNAP_LINES+=("${state}|${label}|${value}")
    fi
}

mm_section() {
    printf '\n%s\n' "$(mm_color '1' "$1")"
}

mm_pad_label() {
    printf '%-18s' "$1"
}

mm_line_ok() { mm_record_line ok "$1" "$2"; mm_ok "$(mm_pad_label "$1")$2"; }
mm_line_warn() { mm_record_line warn "$1" "$2"; mm_warn "$(mm_pad_label "$1")$2"; }
mm_line_error() { mm_record_line error "$1" "$2"; mm_error "$(mm_pad_label "$1")$2"; }
mm_line_info() { mm_record_line info "$1" "$2"; mm_info "$(mm_pad_label "$1")$2"; }
mm_line_disabled() { mm_record_line disabled "$1" "$2"; mm_disabled "$(mm_pad_label "$1")$2"; }

mm_hint() {
    if [[ "${MM_RECORD:-0}" == '1' ]]; then
        MM_SNAP_HINTS+=("$1")
    fi
    printf '  %s %s\n' "$(mm_color '36' '→')" "$1"
}
