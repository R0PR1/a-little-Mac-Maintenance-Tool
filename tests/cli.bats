#!/usr/bin/env bats

load helpers/test_helper

setup() {
    mm_test_setup
}

@test "version prints semantic version" {
    run "$MM_BIN" version
    [ "$status" -eq 0 ]
    [[ "$output" == "mm 0.1.0" ]]
}

@test "version mentions cached remote update without networking" {
    mkdir -p "$HOME/Library/Caches/mm"
    printf 'version=0.2.0\nchecked_at=1\n' > "$HOME/Library/Caches/mm/remote-version"
    run "$MM_BIN" version
    [ "$status" -eq 0 ]
    [[ "$output" == *"mm 0.1.0"* ]]
    [[ "$output" == *"update available: 0.2.0"* ]]
}

@test "unknown command returns usage error" {
    run "$MM_BIN" does-not-exist
    [ "$status" -eq 64 ]
    [[ "$output" == *"Unknown command"* ]]
}

@test "help exits successfully" {
    run "$MM_BIN" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"status"* ]]
}

@test "default command is status" {
    touch "$MM_MOCK_LOADED_DIR/io.mm.daily"
    run "$MM_BIN"
    [ "$status" -eq 0 ]
    [[ "$output" == *"MM 0.1.0"* ]]
    [[ "$output" == *"STATUS"* ]]
}
