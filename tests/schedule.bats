#!/usr/bin/env bats

load helpers/test_helper

setup() {
    mm_test_setup
}

@test "schedule status shows disabled jobs" {
    run "$MM_BIN" schedule status
    [ "$status" -eq 0 ]
    [[ "$output" == *"daily disabled"* ]]
    [[ "$output" == *"weekly disabled"* ]]
}

@test "schedule enable daily renders plist and bootstraps" {
    run "$MM_BIN" schedule enable daily
    [ "$status" -eq 0 ]
    [[ -f "$HOME/Library/LaunchAgents/io.mm.daily.plist" ]]
    grep -q 'io.mm.daily' "$HOME/Library/LaunchAgents/io.mm.daily.plist"
    grep -q 'internal' "$HOME/Library/LaunchAgents/io.mm.daily.plist"
    grep -q 'launchctl bootstrap' "$MM_MOCK_LOG"
    [[ -f "$MM_MOCK_LOADED_DIR/io.mm.daily" ]]
    run "$MM_BIN" config get daily_enabled
    [ "$output" = "true" ]
}

@test "schedule enable weekly uses weekday from config" {
    run "$MM_BIN" config set weekly_day 1
    run "$MM_BIN" schedule enable weekly
    [ "$status" -eq 0 ]
    grep -q '<key>Weekday</key>' "$HOME/Library/LaunchAgents/io.mm.weekly.plist"
    grep -q '<integer>1</integer>' "$HOME/Library/LaunchAgents/io.mm.weekly.plist"
}

@test "schedule disable daily bootouts and removes plist" {
    run "$MM_BIN" schedule enable daily
    run "$MM_BIN" schedule disable daily
    [ "$status" -eq 0 ]
    [[ ! -f "$HOME/Library/LaunchAgents/io.mm.daily.plist" ]]
    run "$MM_BIN" config get daily_enabled
    [ "$output" = "false" ]
}

@test "schedule reload re-bootstraps installed jobs" {
    run "$MM_BIN" schedule enable daily
    : > "$MM_MOCK_LOG"
    run "$MM_BIN" schedule reload
    [ "$status" -eq 0 ]
    grep -q 'launchctl bootout' "$MM_MOCK_LOG"
    grep -q 'launchctl bootstrap' "$MM_MOCK_LOG"
    grep -q 'launchctl kickstart' "$MM_MOCK_LOG"
}

@test "schedule enable rejects unknown job" {
    run "$MM_BIN" schedule enable monthly
    [ "$status" -eq 64 ]
}

@test "generated daily plist uses config hour without leading zeros" {
    run "$MM_BIN" config set daily_hour 09
    run "$MM_BIN" config set daily_minute 15
    run "$MM_BIN" schedule enable daily
    grep -A1 '<key>Hour</key>' "$HOME/Library/LaunchAgents/io.mm.daily.plist" | grep -q '<integer>9</integer>'
    grep -A1 '<key>Minute</key>' "$HOME/Library/LaunchAgents/io.mm.daily.plist" | grep -q '<integer>15</integer>'
}
