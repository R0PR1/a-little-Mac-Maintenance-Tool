#!/usr/bin/env bats

load helpers/test_helper

setup() {
    mm_test_setup
}

@test "menubar status is disabled off macOS" {
    run "$MM_BIN" menubar status
    [ "$status" -eq 0 ]
    [[ "$output" == *"macOS only"* || "$output" == *"disabled"* ]]
}

@test "menubar enable is refused off macOS" {
    run "$MM_BIN" menubar enable
    [ "$status" -eq 2 ]
    [[ "$output" == *"macOS only"* ]]
}

@test "menubar disable is refused off macOS" {
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
