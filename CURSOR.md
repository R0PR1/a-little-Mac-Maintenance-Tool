# Cursor implementation brief

You are implementing `mac-maintenance`, a public macOS CLI whose user-facing command is `mm`.

## Product positioning

A tiny, reliable health and maintenance CLI for macOS.

The default command must be safe and observational:

```bash
mm
```

must behave exactly like:

```bash
mm status
```

It must never perform destructive or surprise changes.

## Non-negotiable principles

1. Safety first
   - no automatic package upgrade unless the user explicitly enables it
   - no forced cask upgrade by default
   - no implicit `sudo`
   - no deleting user files
   - no mutation during `status`, `doctor`, `security`, `version`, or `logs`

2. macOS-native
   - prefer native tools: `launchctl`, `pmset`, `tmutil`, `diskutil`, `softwareupdate`, `sysctl`, `system_profiler`, `fdesetup`, `csrutil`, `spctl`
   - use `launchd`, not cron

3. Shell quality
   - Bash
   - `set -euo pipefail` in executable scripts
   - ShellCheck clean
   - small functions
   - no duplicated shell logic
   - explicit quoting everywhere

4. UX
   - concise dashboard
   - human-readable colors only when stdout is a TTY
   - graceful fallback when a command is unavailable
   - useful exit codes
   - actionable remediation messages

5. Portability across Macs
   - Apple Silicon Homebrew: `/opt/homebrew`
   - Intel Homebrew: `/usr/local`
   - do not hardcode either path as the only option

## Architecture

Keep `bin/mm` as a thin command router.

Business logic belongs in `lib/mm/*.sh`.

Expected modules:

- `output.sh`: colors, sections, status lines
- `utils.sh`: command detection, paths, version helpers
- `config.sh`: config read/write/defaults
- `brew.sh`: brew checks/update/upgrade
- `health.sh`: disk/memory/load/thermal/battery/Time Machine
- `macos.sh`: macOS update checks
- `security.sh`: FileVault/SIP/Gatekeeper/firewall/update policy
- `launchd.sh`: schedule install/remove/reload/status
- `self_update.sh`: update `mm` according to installation mode

## Required CLI behavior

### `mm` / `mm status`

Display concise sections:

```text
MM 0.1.0
MacBook Pro · macOS 26.x · arm64

AUTOMATION
✓ Daily check       09:15
− Weekly upgrade    disabled

HOMEBREW
✓ Homebrew          healthy
! Formulae          3 outdated
✓ Casks             up to date

SYSTEM
✓ Disk              54% · 421 GB free
✓ Memory            healthy
✓ Thermal           normal
✓ Battery           94%
✓ Time Machine      2h ago

SECURITY
✓ FileVault
✓ SIP
✓ Gatekeeper

STATUS              ATTENTION
```

### `mm update`

- `brew update`
- list outdated formulae
- list outdated casks
- must not upgrade anything

### `mm upgrade`

- explicit user-invoked upgrade
- upgrade formulae
- casks only if configuration explicitly enables it or a dedicated flag is passed
- cleanup only if enabled

### `mm doctor`

Detailed diagnostics, read-only except safe Homebrew diagnostic commands.

### `mm security`

Check at minimum:

- FileVault
- SIP
- Gatekeeper
- Application Firewall
- macOS automatic update configuration

Do not attempt to enable or disable security settings.

### `mm config`

Target config file:

```text
~/.config/mm/config
```

Support:

```bash
mm config
mm config get weekly_upgrade
mm config set weekly_upgrade true
mm config reset weekly_upgrade
```

Defaults:

```ini
daily_enabled=true
daily_hour=09
daily_minute=15
weekly_enabled=false
weekly_day=0
weekly_hour=10
weekly_minute=00
weekly_upgrade=false
upgrade_casks=false
cleanup=true
check_macos=true
check_battery=true
check_time_machine=true
check_thermal=true
disk_warning=80
disk_critical=90
```

Do not use `source` on user-editable config files. Parse allowed keys explicitly.

### `mm schedule`

Support:

```bash
mm schedule status
mm schedule enable daily
mm schedule disable daily
mm schedule enable weekly
mm schedule disable weekly
mm schedule reload
```

Generate plists from templates and install under:

```text
~/Library/LaunchAgents/
```

Use modern `launchctl bootstrap` / `bootout` / `kickstart` flows.

### `mm logs`

Logs live in:

```text
~/Library/Logs/mm/
```

Support:

```bash
mm logs
mm logs daily
mm logs weekly
mm logs --follow
```

### `mm self-update`

Detect installation mode.

Preferred behavior:

1. Homebrew install
   - update through Homebrew only
   - never overwrite Homebrew-managed files directly

2. Git checkout
   - `git fetch`
   - require a clean working tree
   - update with fast-forward only

3. Standalone install
   - report that automated self-update is unavailable unless a release-based installer is implemented

### `mm version`

Display local version and, if a cached remote version check exists, indicate update availability.

Do not perform a network call on every invocation.

## Scheduling internals

`launchd` should invoke internal commands that are not advertised as normal public UX:

```bash
mm internal daily
mm internal weekly
```

Daily:

- update Brew metadata
- collect outdated packages
- write logs

Weekly:

- only upgrade when `weekly_upgrade=true`
- otherwise perform the same safe checks as daily

## Testing

Use Bats.

Tests must not mutate the developer's real Homebrew installation or LaunchAgents.

Use PATH-injected mocks/fixtures for:

- brew
- launchctl
- pmset
- tmutil
- diskutil
- softwareupdate
- fdesetup
- csrutil
- spctl

Required test groups:

- CLI routing
- unknown commands
- config allow-listing and validation
- status exit codes
- Brew detection Intel/Apple Silicon
- schedule generation
- weekly upgrade opt-in enforcement
- self-update detection
- security parser behavior

## Exit codes

Use:

- 0: healthy / success
- 1: attention / updates available / non-critical warnings
- 2: action required / critical health issue / invalid operation
- 64: command usage error where appropriate

`mm status` should return 1 when attention is needed, not only print yellow output.

## CI

GitHub Actions should run:

- ShellCheck
- Bats
- syntax check

Target macOS runners when possible and keep tests mockable so Linux lint jobs can still run.

## Releases

Use SemVer.

Git tag:

```text
v0.1.0
```

Release should produce source archive and SHA256 checksum.

Keep the Homebrew tap formula in `Formula/mm.rb` (copy in `packaging/homebrew/mm.rb`). Head-only until a tag on `main`; then fill `url` / `sha256` from GitHub’s `refs/tags/vX.Y.Z.tar.gz`.

Do not hardcode a GitHub owner in core runtime logic. Packaging placeholders are acceptable until the repository owner is chosen.

## Definition of done for v0.1.0

- `mm` dashboard works on Apple Silicon and Intel
- `mm update`, `upgrade`, `doctor`, `security`, `logs`, `config`, `schedule`, `self-update`, `version`
- safe defaults
- Bats coverage for critical flows
- ShellCheck clean
- CI green
- install and uninstall scripts
- README complete
- Homebrew formula template
