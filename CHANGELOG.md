# Changelog

## Unreleased

- Follow symlinks and install a real launcher so `~/.local/bin/mm` finds `lib/mm`
- `make install`, `make uninstall`, `make reinstall`, and `make link` with `PREFIX`
- `mm status --json` snapshot for the menu extra, plus a run lock while jobs execute
- macOS menu extra (`mm menubar enable`) with healthy / attention / running pips
- Menu extra **Run check now** no longer deadlocks on `brew update` pipe output
- Menu extra no longer deadlocks on `status --json` pipe output (was stuck on “waiting for first check”)
- Menu extra decodes disk JSON (`percent`/`free`) instead of requiring a missing `detail` field
- Menu extra lists clear **Needs attention** lines (Time Machine, FileVault, Casks, …)
- Compact security lines are recorded in the JSON snapshot
- Homebrew tap of this repo (`Formula/mm.rb`, head-only until a git tag)

## 0.1.0

- `mm` / `mm status` dashboard with automation, Homebrew, system, and security
- `mm update` refreshes Homebrew metadata without upgrading
- `mm upgrade` upgrades formulae; casks require `--casks` or config
- `mm doctor`, `mm security`, `mm logs`, `mm config`, `mm schedule`, `mm self-update`
- launchd daily/weekly agents generated from templates
- weekly upgrades and cask upgrades disabled by default
- Bats coverage with PATH-injected mocks
- ShellCheck-clean Bash, MIT license
