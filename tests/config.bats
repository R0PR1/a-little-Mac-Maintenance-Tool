#!/usr/bin/env bats

load helpers/test_helper

setup() {
    mm_test_setup
}

@test "config set/get roundtrip" {
    run "$MM_BIN" config set weekly_upgrade true
    [ "$status" -eq 0 ]

    run "$MM_BIN" config get weekly_upgrade
    [ "$status" -eq 0 ]
    [ "$output" = "true" ]
}

@test "unknown config key is rejected" {
    run "$MM_BIN" config set arbitrary_key true
    [ "$status" -eq 2 ]
}

@test "boolean validation rejects yes" {
    run "$MM_BIN" config set weekly_upgrade yes
    [ "$status" -eq 2 ]
    [[ "$output" == *"Invalid boolean"* ]]
}

@test "hour validation rejects 24" {
    run "$MM_BIN" config set daily_hour 24
    [ "$status" -eq 2 ]
}

@test "minute validation rejects 60" {
    run "$MM_BIN" config set daily_minute 60
    [ "$status" -eq 2 ]
}

@test "weekday validation rejects 7" {
    run "$MM_BIN" config set weekly_day 7
    [ "$status" -eq 2 ]
}

@test "disk_warning must stay below disk_critical" {
    run "$MM_BIN" config set disk_warning 95
    [ "$status" -eq 2 ]
    [[ "$output" == *"disk_warning must be lower than disk_critical"* ]]
}

@test "config reset restores default" {
    run "$MM_BIN" config set daily_hour 7
    [ "$status" -eq 0 ]
    run "$MM_BIN" config reset daily_hour
    [ "$status" -eq 0 ]
    run "$MM_BIN" config get daily_hour
    [ "$output" = "09" ]
}

@test "config get usage error" {
    run "$MM_BIN" config get
    [ "$status" -eq 64 ]
}

@test "default config is created with safe values" {
    run "$MM_BIN" config
    [ "$status" -eq 0 ]
    [[ "$output" == *"weekly_upgrade=false"* ]]
    [[ "$output" == *"upgrade_casks=false"* ]]
    [[ "$output" == *"daily_enabled=true"* ]]
}
