# Commands

`mm` with no arguments is `mm status`.

## `mm status`

Read-only dashboard. Exit `1` when something needs attention, `2` when a health check is critical (for example disk above `disk_critical`).

Sections: automation, Homebrew, system (disk, memory, thermal, battery, Time Machine, macOS update policy), security (FileVault, SIP, Gatekeeper).

## `mm update`

Runs `brew update`, then lists outdated formulae and casks. Never upgrades.

## `mm upgrade [--casks]`

1. `brew update`
2. `brew upgrade --formula`
3. `brew upgrade --cask` only if `--casks` was passed or `upgrade_casks=true`
4. `brew cleanup` if `cleanup=true`

## `mm doctor`

Verbose, still non-mutating aside from Homebrew’s own `brew doctor`. Prints `sw_vers`, disk, memory pressure, thermal, battery, Time Machine, brew prefix, and the security report.

## `mm security`

FileVault, SIP, Gatekeeper, Application Firewall, and the Software Update automatic-check policy. Does not enable or disable anything.

## `mm logs [daily|weekly|--follow]`

Reads `~/Library/Logs/mm/`. `--follow` tails the daily and weekly logs.

## `mm config`

```text
mm config
mm config get <key>
mm config set <key> <value>
mm config reset <key>
```

Unknown keys exit `2`. Invalid values (bad booleans, hours outside 0–23, `disk_warning >= disk_critical`) exit `2`. Missing arguments exit `64`.

## `mm schedule`

```text
mm schedule status
mm schedule enable daily|weekly
mm schedule disable daily|weekly
mm schedule reload
```

Plists are rendered from `launchd/mm.*.plist.template` and loaded with `launchctl bootstrap` / `bootout` / `kickstart` in the `gui/$UID` domain.

## `mm self-update`

Detects Homebrew, git checkout, or standalone install. Dirty git trees are refused. Prefix installs from `make install` are standalone copies; use `make link` if you want git self-update from a checkout.

## `mm version`

Prints `mm <semver>` from `VERSION`. If `~/Library/Caches/mm/remote-version` exists and is newer, mentions it. No network I/O.

## `mm internal daily|weekly`

Used by launchd. Not advertised in `mm help`.
