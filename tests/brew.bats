#!/usr/bin/env bats

load helpers/test_helper

setup() {
    mm_test_setup
}

@test "Apple Silicon prefix comes from brew --prefix" {
    export MM_MOCK_BREW_PREFIX=/opt/homebrew
    run "$MM_BIN" doctor
    [[ "$output" == *"/opt/homebrew"* ]]
}

@test "Intel prefix comes from brew --prefix" {
    export MM_MOCK_BREW_PREFIX=/usr/local
    run "$MM_BIN" doctor
    [[ "$output" == *"/usr/local"* ]]
}

@test "update lists outdated packages and never upgrades" {
    export MM_MOCK_OUTDATED_FORMULAE=2
    export MM_MOCK_OUTDATED_CASKS=1
    export MM_MOCK_FORBID_UPGRADE=1
    run "$MM_BIN" update
    [ "$status" -eq 0 ]
    [[ "$output" == *"formula-1"* ]]
    [[ "$output" == *"cask-1"* ]]
    if grep -q 'brew upgrade' "$MM_MOCK_LOG"; then
        echo "upgrade was invoked" >&2
        return 1
    fi
}

@test "upgrade upgrades formulae only by default" {
    run "$MM_BIN" upgrade
    [ "$status" -eq 0 ]
    grep -q 'brew upgrade --formula' "$MM_MOCK_LOG"
    if grep -q 'brew upgrade --cask' "$MM_MOCK_LOG"; then
        echo "cask upgrade was invoked by default" >&2
        return 1
    fi
    grep -q 'brew cleanup' "$MM_MOCK_LOG"
}

@test "upgrade --casks upgrades casks" {
    run "$MM_BIN" upgrade --casks
    [ "$status" -eq 0 ]
    grep -q 'brew upgrade --cask' "$MM_MOCK_LOG"
}

@test "upgrade respects upgrade_casks config" {
    run "$MM_BIN" config set upgrade_casks true
    run "$MM_BIN" upgrade
    [ "$status" -eq 0 ]
    grep -q 'brew upgrade --cask' "$MM_MOCK_LOG"
}

@test "weekly internal job does not upgrade unless opted in" {
    export MM_MOCK_FORBID_UPGRADE=1
    run "$MM_BIN" config set weekly_upgrade false
    run "$MM_BIN" internal weekly
    [ "$status" -eq 0 ]
    if grep -q 'brew upgrade' "$MM_MOCK_LOG"; then
        echo "weekly upgrade ran without opt-in" >&2
        return 1
    fi
    grep -q 'brew update' "$MM_MOCK_LOG"
}

@test "weekly internal job upgrades only when opted in" {
    run "$MM_BIN" config set weekly_upgrade true
    run "$MM_BIN" internal weekly
    [ "$status" -eq 0 ]
    grep -q 'brew upgrade --formula' "$MM_MOCK_LOG"
}
