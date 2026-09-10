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

mm_section() {
    printf '\n%s\n' "$(mm_color '1' "$1")"
}

mm_pad_label() {
    printf '%-18s' "$1"
}

mm_line_ok() { mm_ok "$(mm_pad_label "$1")$2"; }
mm_line_warn() { mm_warn "$(mm_pad_label "$1")$2"; }
mm_line_error() { mm_error "$(mm_pad_label "$1")$2"; }
mm_line_info() { mm_info "$(mm_pad_label "$1")$2"; }
mm_line_disabled() { mm_disabled "$(mm_pad_label "$1")$2"; }

mm_hint() {
    printf '  %s %s\n' "$(mm_color '36' '→')" "$1"
}
