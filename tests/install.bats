#!/usr/bin/env bats

load helpers/test_helper

setup() {
    mm_test_setup
    export PREFIX="$BATS_TEST_TMPDIR/prefix"
    export MM_INSTALL_DIR="$PREFIX/share/mm"
    export MM_BIN_DIR="$PREFIX/bin"
}

@test "mm works when invoked through a symlink outside the project" {
    mkdir -p "$BATS_TEST_TMPDIR/bindir"
    ln -s "$MM_BIN" "$BATS_TEST_TMPDIR/bindir/mm"
    run "$BATS_TEST_TMPDIR/bindir/mm" version
    [ "$status" -eq 0 ]
    [[ "$output" == "mm 0.1.0" ]]
}

@test "a copy of bin/mm without libraries explains how to reinstall" {
    mkdir -p "$BATS_TEST_TMPDIR/orphan/bin"
    cp "$MM_BIN" "$BATS_TEST_TMPDIR/orphan/bin/mm"
    run "$BATS_TEST_TMPDIR/orphan/bin/mm" version
    [ "$status" -eq 2 ]
    [[ "$output" == *"cannot find libraries"* ]]
    [[ "$output" == *"make install"* ]]
}

@test "install.sh copies payload and a working launcher" {
    run "$BATS_TEST_DIRNAME/../scripts/install.sh"
    [ "$status" -eq 0 ]
    [[ -f "$MM_INSTALL_DIR/lib/mm/output.sh" ]]
    [[ -x "$MM_BIN_DIR/mm" ]]
    [[ ! -L "$MM_BIN_DIR/mm" ]]
    run "$MM_BIN_DIR/mm" version
    [ "$status" -eq 0 ]
    [[ "$output" == "mm 0.1.0" ]]
}

@test "install.sh replaces a previously copied bin/mm in PATH" {
    mkdir -p "$MM_BIN_DIR"
    cp "$MM_BIN" "$MM_BIN_DIR/mm"
    run "$MM_BIN_DIR/mm" version
    [ "$status" -eq 2 ]
    run "$BATS_TEST_DIRNAME/../scripts/install.sh"
    [ "$status" -eq 0 ]
    run "$MM_BIN_DIR/mm" version
    [ "$status" -eq 0 ]
    [[ "$output" == "mm 0.1.0" ]]
}

@test "link install points at the checkout" {
    export MM_LINK_CHECKOUT=1
    local root
    root="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    run "$BATS_TEST_DIRNAME/../scripts/install.sh"
    [ "$status" -eq 0 ]
    grep -F "$root" "$MM_BIN_DIR/mm"
    [[ ! -d "$PREFIX/share/mm" ]]
    run "$MM_BIN_DIR/mm" version
    [ "$status" -eq 0 ]
}

@test "uninstall.sh removes launcher and copied payload but not a git checkout" {
    "$BATS_TEST_DIRNAME/../scripts/install.sh"
    [ -x "$MM_BIN_DIR/mm" ]
    run "$BATS_TEST_DIRNAME/../scripts/uninstall.sh"
    [ "$status" -eq 0 ]
    [[ ! -e "$MM_BIN_DIR/mm" ]]
    [[ ! -e "$MM_INSTALL_DIR" ]]
}
