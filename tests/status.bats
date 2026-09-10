#!/usr/bin/env bats

load helpers/test_helper

setup() {
    mm_test_setup
    touch "$MM_MOCK_LOADED_DIR/io.mm.daily"
}

@test "healthy status exits 0" {
    run "$MM_BIN" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"MacBook Pro · macOS 15.6"* ]]
    [[ "$output" == *"Homebrew"* ]]
    [[ "$output" == *"healthy"* ]]
    [[ "$output" == *"Formulae"* ]]
    [[ "$output" == *"up to date"* ]]
    [[ "$output" == *"Disk"* ]]
    [[ "$output" == *"54%"* ]]
    [[ "$output" == *"STATUS"* ]]
    [[ "$output" == *"OK"* ]]
}

@test "outdated formulae return attention" {
    export MM_MOCK_OUTDATED_FORMULAE=3
    run "$MM_BIN" status
    [ "$status" -eq 1 ]
    [[ "$output" == *"3 outdated"* ]]
    [[ "$output" == *"ATTENTION"* ]]
    [[ "$output" == *"mm upgrade"* ]]
}

@test "critical disk returns action required" {
    export MM_MOCK_DISK_PCT=95
    run "$MM_BIN" status
    [ "$status" -eq 2 ]
    [[ "$output" == *"ACTION REQUIRED"* ]]
}

@test "warning disk uses config threshold" {
    export MM_MOCK_DISK_PCT=81
    run "$MM_BIN" status
    [ "$status" -eq 1 ]
    [[ "$output" == *"81%"* ]]
}

@test "unloaded daily schedule is attention" {
    rm -f "$MM_MOCK_LOADED_DIR/io.mm.daily"
    run "$MM_BIN" status
    [ "$status" -eq 1 ]
    [[ "$output" == *"not loaded"* ]]
    [[ "$output" == *"mm schedule enable daily"* ]]
}

@test "Time Machine age is formatted" {
    run "$MM_BIN" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Time Machine"* ]]
    [[ "$output" == *"ago"* || "$output" == *"just now"* ]]
}

@test "battery percent is shown" {
    run "$MM_BIN" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Battery"* ]]
    [[ "$output" == *"94%"* ]]
}
