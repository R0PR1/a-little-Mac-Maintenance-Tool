#!/usr/bin/env bats

load helpers/test_helper

setup() {
    mm_test_setup
    load_mm_libs
}

@test "memory pressure parser variants" {
    [ "$(mm_parse_memory_pressure 'The memory pressure is: nominal')" = 'healthy' ]
    [ "$(mm_parse_memory_pressure 'The system is in the GREEN ZONE')" = 'healthy' ]
    [ "$(mm_parse_memory_pressure 'The system is in the YELLOW ZONE')" = 'warn' ]
    [ "$(mm_parse_memory_pressure 'The memory pressure is: critical')" = 'critical' ]
}

@test "thermal parser variants" {
    [ "$(mm_parse_thermal 'Note: No thermal warning level so far')" = 'normal' ]
    [ "$(mm_parse_thermal $'CPU_Speed_Limit = 50\n')" = 'throttled' ]
    [ "$(mm_parse_thermal $'CPU_Speed_Limit = 100\n')" = 'normal' ]
}

@test "battery percent parser" {
    [ "$(mm_parse_battery_percent $'-InternalBattery-0\t94%; discharging\n')" = '94' ]
}

@test "backup stamp extraction and age" {
    [ "$(mm_extract_backup_stamp '/Volumes/Backup/2026-09-10-051500')" = '2026-09-10-051500' ]
    epoch="$(mm_stamp_to_epoch '2026-09-10-051500')"
    [ -n "$epoch" ]
    [ "$(mm_format_age "$epoch" "$((epoch + 7200))")" = '2h ago' ]
    [ "$(mm_format_age "$epoch" "$((epoch + 120))")" = '2m ago' ]
}

@test "logs show a hint when empty" {
    run "$MM_BIN" logs
    [ "$status" -eq 0 ]
    [[ "$output" == *"No logs yet"* ]]
}

@test "logs daily reads the daily log" {
    printf 'hello-daily\n' > "$HOME/Library/Logs/mm/daily.log"
    run "$MM_BIN" logs daily
    [ "$status" -eq 0 ]
    [[ "$output" == *"hello-daily"* ]]
}

@test "unknown logs target is a usage error" {
    run "$MM_BIN" logs nope
    [ "$status" -eq 64 ]
}
