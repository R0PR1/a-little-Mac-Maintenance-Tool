#!/usr/bin/env bats

load helpers/test_helper

setup() {
    mm_test_setup
}

@test "security is healthy when all controls are on" {
    run "$MM_BIN" security
    [ "$status" -eq 0 ]
    [[ "$output" == *"FileVault"* ]]
    [[ "$output" == *"SIP"* ]]
    [[ "$output" == *"Gatekeeper"* ]]
    [[ "$output" == *"Firewall"* ]]
    [[ "$output" == *"Auto updates"* ]]
}

@test "disabled FileVault is attention" {
    export MM_MOCK_FILEVAULT=off
    run "$MM_BIN" security
    [ "$status" -eq 1 ]
    [[ "$output" == *"FileVault"* ]]
    [[ "$output" == *"disabled"* ]]
}

@test "disabled SIP is attention" {
    export MM_MOCK_SIP=off
    run "$MM_BIN" security
    [ "$status" -eq 1 ]
}

@test "disabled Gatekeeper is attention" {
    export MM_MOCK_GATEKEEPER=off
    run "$MM_BIN" security
    [ "$status" -eq 1 ]
}

@test "disabled firewall is attention" {
    export MM_MOCK_FIREWALL=off
    run "$MM_BIN" security
    [ "$status" -eq 1 ]
    [[ "$output" == *"Firewall"* ]]
    [[ "$output" == *"disabled"* ]]
}

@test "automatic update policy can be parsed as disabled" {
    export MM_MOCK_AUTO_CHECK=0
    run "$MM_BIN" security
    [ "$status" -eq 1 ]
    [[ "$output" == *"Auto updates"* ]]
}

@test "parsers understand common system strings" {
    load_mm_libs
    [ "$(mm_parse_filevault 'FileVault is On.')" = 'on' ]
    [ "$(mm_parse_filevault 'FileVault is Off.')" = 'off' ]
    [ "$(mm_parse_sip 'System Integrity Protection status: enabled.')" = 'on' ]
    [ "$(mm_parse_sip 'System Integrity Protection status: disabled.')" = 'off' ]
    [ "$(mm_parse_gatekeeper 'assessments enabled')" = 'on' ]
    [ "$(mm_parse_gatekeeper 'assessments disabled')" = 'off' ]
    [ "$(mm_parse_firewall 'Firewall is enabled. (State = 1)')" = 'on' ]
    [ "$(mm_parse_firewall 'Firewall is disabled. (State = 0)')" = 'off' ]
}
