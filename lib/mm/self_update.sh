#!/usr/bin/env bash

mm_git() {
    git -C "$MM_PROJECT_DIR" "$@"
}

mm_install_method() {
    local executable prefix

    executable="$(command -v mm 2>/dev/null || true)"

    if mm_brew_present; then
        if mm_brew list --formula mm >/dev/null 2>&1; then
            printf '%s\n' 'homebrew'
            return 0
        fi
        prefix="$(mm_homebrew_prefix 2>/dev/null || true)"
        if [[ -n "$executable" && -n "$prefix" ]]; then
            case "$executable" in
                "$prefix"/Cellar/mm/*|"$prefix"/opt/mm/*)
                    printf '%s\n' 'homebrew'
                    return 0
                    ;;
            esac
        fi
    fi

    if mm_git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        printf '%s\n' 'git'
        return 0
    fi

    if [[ -n "$executable" ]]; then
        printf '%s\n' 'standalone'
        return 0
    fi

    printf '%s\n' 'unknown'
}

mm_self_update() {
    local method remote
    method="$(mm_install_method)"

    case "$method" in
        homebrew)
            mm_info 'Homebrew installation detected. Updating through Homebrew only.'
            mm_brew update
            mm_brew upgrade mm
            remote="$(mm_brew list --versions mm 2>/dev/null | awk '{ print $2; exit }')"
            if [[ -n "$remote" ]]; then
                mm_write_version_cache "$remote"
            fi
            ;;
        git)
            if [[ -n "$(mm_git status --porcelain)" ]]; then
                mm_error 'Working tree is not clean. Refusing self-update.'
                return 2
            fi
            mm_git fetch --tags --prune
            mm_git pull --ff-only
            remote="$(mm_git describe --tags --abbrev=0 2>/dev/null || mm_version_value)"
            remote="${remote#v}"
            mm_write_version_cache "$remote"
            ;;
        standalone)
            mm_error 'Standalone install detected. Automated self-update is unavailable.'
            mm_hint 'From a clone, run: make install'
            return 2
            ;;
        *)
            mm_error 'Unable to detect installation method.'
            return 2
            ;;
    esac
}
