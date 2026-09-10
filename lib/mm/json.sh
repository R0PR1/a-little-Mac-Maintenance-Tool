#!/usr/bin/env bash

mm_json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

mm_json_str() {
    printf '"%s"' "$(mm_json_escape "$1")"
}

mm_snap_lookup() {
    local want="$1"
    local line state label value
    for line in "${MM_SNAP_LINES[@]+"${MM_SNAP_LINES[@]}"}"; do
        state="${line%%|*}"
        rest="${line#*|}"
        label="${rest%%|*}"
        value="${rest#*|}"
        if [[ "$label" == "$want" ]]; then
            printf '%s\t%s\n' "$state" "$value"
            return 0
        fi
    done
    return 1
}

mm_json_item() {
    local label="$1"
    local found state value
    if ! found="$(mm_snap_lookup "$label")"; then
        printf 'null'
        return 0
    fi
    state="${found%%$'\t'*}"
    value="${found#*$'\t'}"
    printf '{"state":%s,"detail":%s}' "$(mm_json_str "$state")" "$(mm_json_str "$value")"
}

mm_json_disk() {
    local found state value pct free
    if ! found="$(mm_snap_lookup Disk)"; then
        printf 'null'
        return 0
    fi
    state="${found%%$'\t'*}"
    value="${found#*$'\t'}"
    pct="$(printf '%s' "$value" | grep -Eo '^[0-9]+' || true)"
    free="$(printf '%s' "$value" | sed -n 's/^[0-9]*% · \(.*\) free$/\1/p')"
    printf '{"state":%s,"percent":%s,"free":%s}' \
        "$(mm_json_str "$state")" \
        "${pct:-null}" \
        "$(mm_json_str "${free}")"
}

mm_json_battery() {
    local found state value pct
    if ! found="$(mm_snap_lookup Battery)"; then
        printf 'null'
        return 0
    fi
    state="${found%%$'\t'*}"
    value="${found#*$'\t'}"
    pct="$(printf '%s' "$value" | grep -Eo '^[0-9]+' || true)"
    if [[ -n "$pct" ]]; then
        printf '{"state":%s,"percent":%s,"detail":%s}' \
            "$(mm_json_str "$state")" "$pct" "$(mm_json_str "$value")"
    else
        printf '{"state":%s,"percent":null,"detail":%s}' \
            "$(mm_json_str "$state")" "$(mm_json_str "$value")"
    fi
}

mm_json_homebrew() {
    local brew_found brew_state formulae_found formulae_detail formulae_n
    if ! brew_found="$(mm_snap_lookup Homebrew)"; then
        printf 'null'
        return 0
    fi
    brew_state="${brew_found%%$'\t'*}"
    formulae_n=0
    if formulae_found="$(mm_snap_lookup Formulae)"; then
        formulae_detail="${formulae_found#*$'\t'}"
        if [[ "$formulae_detail" =~ ^([0-9]+)\ outdated$ ]]; then
            formulae_n="${BASH_REMATCH[1]}"
        fi
    fi
    printf '{"state":%s,"formulae_outdated":%s}' "$(mm_json_str "$brew_state")" "$formulae_n"
}

mm_json_running() {
    local row job pid started
    if ! row="$(mm_run_lock_read)"; then
        printf 'null'
        return 0
    fi
    job="${row%%$'\t'*}"
    pid="$(printf '%s' "$row" | awk -F'\t' '{ print $2 }')"
    started="$(printf '%s' "$row" | awk -F'\t' '{ print $3 }')"
    printf '{"job":%s,"pid":%s,"started_at":%s}' \
        "$(mm_json_str "$job")" "$pid" "${started:-0}"
}

mm_json_hints() {
    local hint first=1
    printf '['
    for hint in "${MM_SNAP_HINTS[@]+"${MM_SNAP_HINTS[@]}"}"; do
        [[ "$first" -eq 1 ]] || printf ','
        first=0
        mm_json_str "$hint"
    done
    printf ']'
}

mm_json_overall() {
    case "${MM_EXIT_STATE:-0}" in
        0) printf 'healthy' ;;
        1) printf 'attention' ;;
        *) printf 'action' ;;
    esac
}

mm_status_json() {
    local overall payload
    # shellcheck disable=SC2034
    MM_RECORD=1
    # shellcheck disable=SC2034
    MM_COLOR_ENABLED=0
    MM_SNAP_LINES=()
    MM_SNAP_HINTS=()
    MM_SNAP_VERSION=''
    MM_SNAP_MODEL=''
    MM_SNAP_MACOS=''
    MM_SNAP_ARCH=''
    mm_status >/dev/null || true

    overall="$(mm_json_overall)"
    payload="$(cat <<EOF
{"version":$(mm_json_str "${MM_SNAP_VERSION:-$(mm_version_value)}"),"overall":$(mm_json_str "$overall"),"exit":${MM_EXIT_STATE:-0},"checked_at":$(mm_now),"running":$(mm_json_running),"host":{"model":$(mm_json_str "${MM_SNAP_MODEL:-Mac}"),"macos":$(mm_json_str "${MM_SNAP_MACOS:-unknown}"),"arch":$(mm_json_str "${MM_SNAP_ARCH:-$(uname -m)}")},"disk":$(mm_json_disk),"battery":$(mm_json_battery),"time_machine":$(mm_json_item 'Time Machine'),"homebrew":$(mm_json_homebrew),"automation":{"daily":$(mm_json_item 'Daily check'),"weekly":$(mm_json_item 'Weekly upgrade')},"hints":$(mm_json_hints)}
EOF
)"
    mkdir -p "$MM_CACHE_DIR"
    printf '%s\n' "$payload" | tee "$MM_STATUS_CACHE"
    return "$MM_EXIT_STATE"
}
