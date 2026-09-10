#!/usr/bin/env bash

mm_test_setup() {
    export HOME="$BATS_TEST_TMPDIR/home"
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_CACHE_HOME="$HOME/Library/Caches"
    mkdir -p "$HOME" "$HOME/Library/Logs/mm" "$HOME/Library/LaunchAgents" "$HOME/Library/Caches/mm"

    export MM_BIN="$BATS_TEST_DIRNAME/../bin/mm"
    export MM_BIN_PATH="$MM_BIN"
    export MM_FIREWALL_BIN="$BATS_TEST_DIRNAME/fixtures/bin/socketfilterfw"
    export MM_MOCK_LOG="$BATS_TEST_TMPDIR/mock.log"
    export MM_MOCK_LOADED_DIR="$BATS_TEST_TMPDIR/launchctl-loaded"
    mkdir -p "$MM_MOCK_LOADED_DIR"
    : > "$MM_MOCK_LOG"

    export PATH="$BATS_TEST_DIRNAME/fixtures/bin:$PATH"

    export MM_MOCK_DISK_PCT="${MM_MOCK_DISK_PCT:-54}"
    export MM_MOCK_DISK_FREE="${MM_MOCK_DISK_FREE:-421Gi}"
    export MM_MOCK_MODEL="${MM_MOCK_MODEL:-MacBook Pro}"
    export MM_MOCK_MACOS="${MM_MOCK_MACOS:-15.6}"
    export MM_MOCK_OUTDATED_FORMULAE="${MM_MOCK_OUTDATED_FORMULAE:-0}"
    export MM_MOCK_OUTDATED_CASKS="${MM_MOCK_OUTDATED_CASKS:-0}"
    export MM_MOCK_BREW_PREFIX="${MM_MOCK_BREW_PREFIX:-/opt/homebrew}"
    export MM_MOCK_BREW_HAS_MM="${MM_MOCK_BREW_HAS_MM:-0}"
    export MM_MOCK_MEMORY="${MM_MOCK_MEMORY:-nominal}"
    export MM_MOCK_BATTERY_PCT="${MM_MOCK_BATTERY_PCT:-94}"
    export MM_MOCK_BATTERY="${MM_MOCK_BATTERY:-1}"
    export MM_MOCK_THERM="${MM_MOCK_THERM:-Note: No thermal warning level so far}"
    export MM_MOCK_FILEVAULT="${MM_MOCK_FILEVAULT:-on}"
    export MM_MOCK_SIP="${MM_MOCK_SIP:-on}"
    export MM_MOCK_GATEKEEPER="${MM_MOCK_GATEKEEPER:-on}"
    export MM_MOCK_FIREWALL="${MM_MOCK_FIREWALL:-on}"
    export MM_MOCK_AUTO_CHECK="${MM_MOCK_AUTO_CHECK:-1}"
    export MM_MOCK_AUTO_DOWNLOAD="${MM_MOCK_AUTO_DOWNLOAD:-1}"
    export MM_MOCK_AUTO_INSTALL="${MM_MOCK_AUTO_INSTALL:-0}"
    export MM_MOCK_TM_BACKUP="${MM_MOCK_TM_BACKUP:-/Volumes/Backup/Backups.backupdb/Mac/2026-09-10-051500}"
    export MM_MOCK_NOW="${MM_MOCK_NOW:-1789026900}"
}

load_mm_libs() {
    # shellcheck source=/dev/null
    source "$BATS_TEST_DIRNAME/../lib/mm/output.sh"
    # shellcheck source=/dev/null
    source "$BATS_TEST_DIRNAME/../lib/mm/utils.sh"
    # shellcheck source=/dev/null
    source "$BATS_TEST_DIRNAME/../lib/mm/config.sh"
    # shellcheck source=/dev/null
    source "$BATS_TEST_DIRNAME/../lib/mm/macos.sh"
    # shellcheck source=/dev/null
    source "$BATS_TEST_DIRNAME/../lib/mm/security.sh"
    # shellcheck source=/dev/null
    source "$BATS_TEST_DIRNAME/../lib/mm/health.sh"
}
