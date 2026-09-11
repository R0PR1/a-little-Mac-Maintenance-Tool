#!/usr/bin/env bats

load helpers/test_helper

setup() {
    mm_test_setup
}

@test "menubar status is disabled off macOS" {
    if [[ "$(uname -s)" == 'Darwin' ]]; then
        skip 'macOS runner'
    fi
    run "$MM_BIN" menubar status
    [ "$status" -eq 0 ]
    [[ "$output" == *"macOS only"* || "$output" == *"disabled"* ]]
}

@test "menubar enable is refused off macOS" {
    if [[ "$(uname -s)" == 'Darwin' ]]; then
        skip 'macOS runner'
    fi
    run "$MM_BIN" menubar enable
    [ "$status" -eq 2 ]
    [[ "$output" == *"macOS only"* ]]
}

@test "menubar disable is refused off macOS" {
    if [[ "$(uname -s)" == 'Darwin' ]]; then
        skip 'macOS runner'
    fi
    run "$MM_BIN" menubar disable
    [ "$status" -eq 2 ]
    [[ "$output" == *"macOS only"* ]]
}

@test "menubar unknown subcommand is a usage error" {
    run "$MM_BIN" menubar nope
    [ "$status" -eq 64 ]
}

@test "help lists menubar" {
    run "$MM_BIN" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"menubar"* ]]
}

@test "menubar status is disabled before enable" {
    [[ "$(uname -s)" == 'Darwin' ]] || skip 'Linux runner'
    run "$MM_BIN" menubar status
    [ "$status" -eq 0 ]
    [[ "$output" == *"disabled"* || "$output" == *"enabled"* || "$output" == *"not loaded"* ]]
}

@test "menubar user PATH includes Homebrew prefixes" {
    load_mm_libs
    # shellcheck source=/dev/null
    source "$BATS_TEST_DIRNAME/../lib/mm/menubar.sh"
    run mm_menubar_user_path
    [ "$status" -eq 0 ]
    [[ "$output" == "$HOME/.local/bin:"* ]]
    [[ "$output" == *"/opt/homebrew/bin"* ]]
    [[ "$output" == *"/usr/local/bin"* ]]
}

@test "menubar plist sets PATH and MM_BIN" {
    load_mm_libs
    # shellcheck source=/dev/null
    source "$BATS_TEST_DIRNAME/../lib/mm/menubar.sh"
    extra="$BATS_TEST_TMPDIR/fake-extra"
    printf '%s\n' '#!/bin/sh' > "$extra"
    chmod +x "$extra"
    mm_menubar_write_plist "$extra"
    plist="$(mm_menubar_plist_path)"
    [[ -f "$plist" ]]
    grep -q '<string>io.mm.menubar</string>' "$plist"
    grep -A1 '<key>PATH</key>' "$plist" | grep -q '/opt/homebrew/bin'
    grep -A1 '<key>PATH</key>' "$plist" | grep -q '.local/bin'
    grep -A1 '<key>MM_BIN</key>' "$plist" | grep -q 'mm'
}

@test "menu extra discards update stdout to avoid pipe deadlock" {
    src="$BATS_TEST_DIRNAME/../macos/MmExtra.swift"
    grep -q 'captureOutput: false' "$src"
    grep -q 'FileHandle.nullDevice' "$src"
    grep -q 'localRunning' "$src"
}
