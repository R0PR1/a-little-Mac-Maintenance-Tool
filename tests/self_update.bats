#!/usr/bin/env bats

load helpers/test_helper

setup() {
    mm_test_setup
    export PATH="$BATS_TEST_TMPDIR/gitbin:$PATH"
    mkdir -p "$BATS_TEST_TMPDIR/gitbin"
    cat > "$BATS_TEST_TMPDIR/gitbin/git" << 'EOF'
#!/usr/bin/env bash
if [[ -n "${MM_MOCK_LOG:-}" ]]; then
    printf 'git %s\n' "$*" >> "$MM_MOCK_LOG"
fi
if [[ "${1:-}" == '-C' ]]; then
    shift 2
fi
cmd="${1:-}"
shift || true
case "$cmd" in
    rev-parse)
        if [[ "${MM_MOCK_GIT_REPO:-1}" == '1' ]]; then
            printf 'true\n'
            exit 0
        fi
        exit 1
        ;;
    status)
        if [[ "${MM_MOCK_GIT_DIRTY:-0}" == '1' ]]; then
            printf ' M lib/mm/utils.sh\n'
        fi
        exit 0
        ;;
    fetch)
        exit 0
        ;;
    pull)
        printf '%s\n' "$*" >> "${MM_MOCK_LOG:-/dev/null}"
        if [[ " $* " != *" --ff-only "* && "$*" != *"--ff-only"* ]]; then
            printf 'refusing pull without --ff-only\n' >&2
            exit 1
        fi
        printf 'Already up to date.\n'
        ;;
    describe)
        printf 'v0.1.0\n'
        ;;
    *)
        exit 0
        ;;
esac
EOF
    chmod +x "$BATS_TEST_TMPDIR/gitbin/git"
}

@test "self-update uses Homebrew when mm is a brew formula" {
    export MM_MOCK_BREW_HAS_MM=1
    run "$MM_BIN" self-update
    [ "$status" -eq 0 ]
    grep -q 'brew upgrade mm' "$MM_MOCK_LOG"
}

@test "git self-update refuses a dirty working tree" {
    export MM_MOCK_BREW_HAS_MM=0
    export MM_MOCK_GIT_DIRTY=1
    run "$MM_BIN" self-update
    [ "$status" -eq 2 ]
    [[ "$output" == *"not clean"* ]]
}

@test "git self-update fast-forwards only" {
    export MM_MOCK_BREW_HAS_MM=0
    export MM_MOCK_GIT_DIRTY=0
    run "$MM_BIN" self-update
    [ "$status" -eq 0 ]
    grep -q -- '--ff-only' "$MM_MOCK_LOG"
}

@test "standalone install reports that self-update is unavailable" {
    export MM_MOCK_BREW_HAS_MM=0
    export MM_MOCK_GIT_REPO=0
    mkdir -p "$BATS_TEST_TMPDIR/path"
    ln -s "$MM_BIN" "$BATS_TEST_TMPDIR/path/mm"
    export PATH="$BATS_TEST_TMPDIR/path:$PATH"
    run "$MM_BIN" self-update
    [ "$status" -eq 2 ]
    [[ "$output" == *"Standalone"* ]]
}
