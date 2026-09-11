#!/usr/bin/env bats

load helpers/test_helper

setup() {
    mm_test_setup
    touch "$MM_MOCK_LOADED_DIR/io.mm.daily"
}

@test "status --json is valid JSON and healthy" {
    run "$MM_BIN" status --json
    [ "$status" -eq 0 ]
    python3 -c 'import json,sys; json.load(sys.stdin)' <<<"$output"
    [[ "$output" == *'"overall":"healthy"'* ]]
    [[ "$output" == *'"formulae_outdated":0'* ]]
    [[ "$output" == *'"casks_outdated":0'* ]]
    [[ "$output" == *'"percent":54'* ]]
    [[ "$output" == *'"detail":"54% · 421Gi free"'* ]]
    [[ "$output" == *'"issues":[]'* ]]
}

@test "mm --json is an alias for status --json" {
    run "$MM_BIN" --json
    [ "$status" -eq 0 ]
    [[ "$output" == *'"overall":"healthy"'* ]]
}

@test "status --json attention includes outdated formulae and hints" {
    export MM_MOCK_OUTDATED_FORMULAE=3
    run "$MM_BIN" status --json
    [ "$status" -eq 1 ]
    [[ "$output" == *'"overall":"attention"'* ]]
    [[ "$output" == *'"formulae_outdated":3'* ]]
    [[ "$output" == *'"mm upgrade"'* ]]
    [[ "$output" == *'"label":"Formulae"'* ]]
    [[ "$output" == *'"detail":"3 outdated"'* ]]
}

@test "status --json issues list Time Machine FileVault and Casks" {
    export MM_MOCK_TM_BACKUP=none
    export MM_MOCK_FILEVAULT=off
    export MM_MOCK_OUTDATED_CASKS=1
    run "$MM_BIN" status --json
    [ "$status" -eq 1 ]
    python3 -c '
import json,sys
d=json.load(sys.stdin)
labels={i["label"]:i["detail"] for i in d["issues"]}
assert labels.get("Time Machine")=="no backup", labels
assert labels.get("FileVault")=="disabled", labels
assert labels.get("Casks")=="1 outdated", labels
assert d["filevault"]["detail"]=="disabled"
assert d["homebrew"]["casks_outdated"]==1
' <<<"$output"
}

@test "status --json critical disk is action" {
    export MM_MOCK_DISK_PCT=95
    run "$MM_BIN" status --json
    [ "$status" -eq 2 ]
    [[ "$output" == *'"overall":"action"'* ]]
}

@test "status --json writes last-status cache" {
    run "$MM_BIN" status --json
    [ "$status" -eq 0 ]
    [[ -f "$HOME/Library/Caches/mm/last-status.json" ]]
    grep -q '"overall":"healthy"' "$HOME/Library/Caches/mm/last-status.json"
}

@test "status --json reports a live run lock" {
    sleep 30 &
    local pid=$!
    printf 'job=daily\npid=%s\nstarted_at=100\n' "$pid" > "$HOME/Library/Caches/mm/run.lock"
    run "$MM_BIN" status --json
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    [ "$status" -eq 0 ]
    [[ "$output" == *'"job":"daily"'* ]]
}

@test "status --json ignores a stale run lock" {
    printf 'job=daily\npid=999999\nstarted_at=100\n' > "$HOME/Library/Caches/mm/run.lock"
    run "$MM_BIN" status --json
    [ "$status" -eq 0 ]
    [[ "$output" == *'"running":null'* ]]
    [[ ! -f "$HOME/Library/Caches/mm/run.lock" ]]
}

@test "update acquires and releases the run lock" {
    run "$MM_BIN" update
    [ "$status" -eq 0 ]
    [[ ! -f "$HOME/Library/Caches/mm/run.lock" ]]
}

@test "human status is unchanged without --json" {
    run "$MM_BIN" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"MM 0.1.0"* ]]
    [[ "$output" != *'"overall"'* ]]
}
