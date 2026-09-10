# Architecture

`bin/mm` is a thin command router. Every real behavior lives in `lib/mm/*.sh` so that parsers and policy can be unit-tested without a Mac.

```text
bin/mm
  ├─ output.sh        colors, status glyphs, TTY detection
  ├─ utils.sh         paths, version, Homebrew prefix, helpers
  ├─ config.sh        allow-listed ~/.config/mm/config
  ├─ brew.sh          brew update / upgrade / doctor summary
  ├─ health.sh        dashboard, doctor, logs, internal jobs
  ├─ macos.sh         softwareupdate list + automatic update policy
  ├─ security.sh      FileVault / SIP / Gatekeeper / firewall
  ├─ json.sh          mm status --json snapshot
  ├─ menubar.sh       mm menubar enable/disable
  ├─ launchd.sh       plist render, bootstrap / bootout / kickstart
  └─ self_update.sh   Homebrew vs git vs standalone
```

The macOS menu extra lives in `macos/MmExtra.swift` and is built by `scripts/build-menubar.sh`.

## Installation

`make install` copies `bin/`, `lib/mm/`, `launchd/`, `completions/`, `macos/MmExtra.swift`, `scripts/build-menubar.sh`, and `VERSION` into `$(PREFIX)/share/mm` (default `~/.local/share/mm`) and writes a launcher at `$(PREFIX)/bin/mm`. The launcher `exec`s the real `bin/mm` with an absolute path.

`bin/mm` also follows symlinks before locating `lib/mm`, so a Homebrew `bin/mm` symlink still works.

`make link` skips the copy and points the launcher at the git checkout.

## Data on disk

| Path | Role |
| --- | --- |
| `~/.config/mm/config` | User settings, mode `600`, never `source`d |
| `~/Library/Logs/mm/` | Daily / weekly stdout from launchd |
| `~/Library/LaunchAgents/io.mm.{daily,weekly}.plist` | Generated agents |
| `~/Library/Caches/mm/remote-version` | Cached remote version from self-update |
| `~/Library/Caches/mm/last-status.json` | Last `mm status --json` snapshot |
| `~/Library/Caches/mm/run.lock` | Live job (pid) while update/upgrade/internal runs |
| `~/Library/LaunchAgents/io.mm.menubar.plist` | Menu extra |

## Safety boundaries

- Status, doctor, security, logs, and version never mutate packages or security settings.
- `mm upgrade` is the only public command that upgrades formulae.
- Cask upgrades require `--casks` or `upgrade_casks=true`.
- `mm internal weekly` calls `mm upgrade` only when `weekly_upgrade=true`.
- Tests prepend `tests/fixtures/bin` to `PATH` and set `HOME` to a tempdir.

## Homebrew layout

`mm` never assumes a single prefix:

1. `brew --prefix` if `brew` is on `PATH`
2. `/opt/homebrew/bin/brew` (Apple Silicon)
3. `/usr/local/bin/brew` (Intel)

## Exit codes

| Code | Meaning |
| --- | --- |
| 0 | Healthy / success |
| 1 | Attention (outdated packages, unloaded schedule, FileVault off, …) |
| 2 | Action required (critical disk, invalid operation, dirty git self-update) |
| 64 | Usage error |
