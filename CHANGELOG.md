# Changelog

## Unreleased

- Follow symlinks and install a real launcher so `~/.local/bin/mm` finds `lib/mm`
- `make install`, `make uninstall`, `make reinstall`, and `make link` with `PREFIX`

## 0.1.0

- `mm` / `mm status` dashboard with automation, Homebrew, system, and security
- `mm update` refreshes Homebrew metadata without upgrading
- `mm upgrade` upgrades formulae; casks require `--casks` or config
- `mm doctor`, `mm security`, `mm logs`, `mm config`, `mm schedule`, `mm self-update`
- launchd daily/weekly agents generated from templates
- weekly upgrades and cask upgrades disabled by default
- Bats coverage with PATH-injected mocks
- ShellCheck-clean Bash, MIT license
