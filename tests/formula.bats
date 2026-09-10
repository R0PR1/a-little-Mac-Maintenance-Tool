#!/usr/bin/env bats

load helpers/test_helper

setup() {
    mm_test_setup
}

@test "Formula/mm.rb is a head-only macOS tap formula" {
    formula="$BATS_TEST_DIRNAME/../Formula/mm.rb"
    [[ -f "$formula" ]]
    grep -q 'class Mm < Formula' "$formula"
    grep -q 'head "https://github.com/R0PR1/a-little-Mac-Maintenance-Tool.git"' "$formula"
    grep -q 'depends_on :macos' "$formula"
    grep -q 'exec "#{libexec}/bin/mm"' "$formula"
    ! grep -q 'REPLACE_WITH_RELEASE_SHA256' "$formula"
}

@test "packaging formula stays in sync with Formula/mm.rb" {
    tap="$BATS_TEST_DIRNAME/../Formula/mm.rb"
    copy="$BATS_TEST_DIRNAME/../packaging/homebrew/mm.rb"
    [[ -f "$copy" ]]
    tap_body="$(awk '/^class Mm /{p=1} p' "$tap")"
    copy_body="$(awk '/^class Mm /{p=1} p' "$copy")"
    [[ "$tap_body" == "$copy_body" ]]
}
