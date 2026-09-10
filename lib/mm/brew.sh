#!/usr/bin/env bash

mm_brew() {
    local brew_bin
    brew_bin="$(mm_brew_bin)" || return 1
    "$brew_bin" "$@"
}

mm_brew_present() {
    mm_brew_bin >/dev/null 2>&1
}

mm_brew_outdated_count() {
    local kind="$1"
    mm_brew outdated "--$kind" 2>/dev/null | awk 'NF { n++ } END { print n + 0 }'
}

mm_brew_status() {
    local prefix formula_count cask_count

    if ! mm_brew_present; then
        mm_line_disabled 'Homebrew' 'not installed'
        return 0
    fi

    prefix="$(mm_homebrew_prefix 2>/dev/null || true)"
    if [[ -n "$prefix" ]]; then
        mm_line_ok 'Homebrew' 'healthy'
    else
        mm_line_warn 'Homebrew' 'prefix unknown'
        mm_raise_state 1
    fi

    formula_count="$(mm_brew_outdated_count formula)"
    cask_count="$(mm_brew_outdated_count cask)"

    if [[ "$formula_count" -gt 0 ]]; then
        mm_line_warn 'Formulae' "$formula_count outdated"
        mm_raise_state 1
    else
        mm_line_ok 'Formulae' 'up to date'
    fi

    if [[ "$cask_count" -gt 0 ]]; then
        mm_line_warn 'Casks' "$cask_count outdated"
        mm_raise_state 1
    else
        mm_line_ok 'Casks' 'up to date'
    fi
}

mm_brew_update() {
    if ! mm_brew_present; then
        mm_error 'Homebrew is not installed.'
        return 2
    fi

    mm_section 'HOMEBREW UPDATE'
    mm_brew update

    mm_section 'Formulae'
    mm_brew outdated --formula || true

    mm_section 'Casks'
    mm_brew outdated --cask || true
}

mm_brew_upgrade() {
    local upgrade_casks=0
    local cleanup
    local configured_casks

    if ! mm_brew_present; then
        mm_error 'Homebrew is not installed.'
        return 2
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --casks|--cask)
                upgrade_casks=1
                ;;
            --formulae-only|--no-casks)
                upgrade_casks=0
                ;;
            -h|--help)
                mm_error 'Usage: mm upgrade [--casks]'
                return 64
                ;;
            *)
                mm_error "Unknown upgrade option: $1"
                return 64
                ;;
        esac
        shift
    done

    configured_casks="$(mm_config_get upgrade_casks)"
    cleanup="$(mm_config_get cleanup)"

    if [[ "$configured_casks" == 'true' ]]; then
        upgrade_casks=1
    fi

    mm_section 'HOMEBREW UPGRADE'
    mm_brew update
    mm_brew upgrade --formula

    if [[ "$upgrade_casks" -eq 1 ]]; then
        mm_brew upgrade --cask
    else
        mm_info 'Casks skipped (enable with mm config set upgrade_casks true or mm upgrade --casks)'
    fi

    if [[ "$cleanup" == 'true' ]]; then
        mm_brew cleanup
    fi
}

mm_brew_doctor_summary() {
    local prefix doctor_out doctor_status=0

    if ! mm_brew_present; then
        mm_line_disabled 'Homebrew' 'not installed'
        return 0
    fi

    prefix="$(mm_homebrew_prefix)"
    mm_line_ok 'Prefix' "$prefix"
    mm_line_ok 'Binary' "$(mm_brew_bin)"

    doctor_out="$(mm_brew doctor 2>&1)" || doctor_status=$?
    if [[ "$doctor_status" -eq 0 ]]; then
        mm_line_ok 'brew doctor' 'ready to brew'
    else
        mm_line_warn 'brew doctor' 'reported warnings'
        mm_raise_state 1
        printf '%s\n' "$doctor_out"
    fi
}
