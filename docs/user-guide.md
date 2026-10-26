# How mm works

`mm` is a small macOS health dashboard. It watches Homebrew drift, disk, battery, Time Machine, and a few security switches — without surprise upgrades, `sudo`, or deleting your files.

## Colors in the menu bar

| Pip | Meaning |
| --- | --- |
| Sage ● | Healthy |
| Amber ● | Attention — something needs a look |
| Red ● | Action required (for example critical disk) |
| Pulsing | A job is running (`update`, `upgrade`, …) |

Click the `mm` item for details. Amber is not a crash: it lists each reason under **Needs attention**.

## What each command does

| Action | Effect |
| --- | --- |
| **Open Dashboard** | Runs `mm status` in Terminal (full report) |
| **Run check now** | Runs `mm update` — refreshes Homebrew metadata only, never upgrades |
| **Upgrade formulae…** | Runs `mm upgrade` in Terminal (explicit) |
| **Parameters** | Enable or disable launchd automation (not cron) |
| **How mm works** | Opens this guide |

## Automation (launchd, not cron)

macOS schedules are LaunchAgents under `~/Library/LaunchAgents/`.

| Job | Default | What it does |
| --- | --- | --- |
| **Daily check** | on (09:15) | Read-only `brew update` + status log |
| **Weekly job** | off | Runs only if you enable it |
| **Allow weekly upgrades** | **off** | When on *and* the weekly job is enabled, the weekly run may call `mm upgrade` |

Weekly upgrades stay off until you opt in. Cask upgrades stay off unless you pass `--casks` or set `upgrade_casks=true`.

From the menu: **Parameters → Daily check / Weekly job / Allow weekly upgrades**.

From the terminal:

```bash
mm schedule enable daily
mm schedule enable weekly
mm config set weekly_upgrade true   # opt-in; still needs weekly job enabled
mm schedule status
```

## Safety promises

- No implicit `sudo`
- No deleting user files or caches
- `mm` / `mm status` / `mm doctor` / `mm security` / `mm logs` / `mm version` are read-only
- Package upgrades only via `mm upgrade` or the weekly opt-in

## Config and logs

| Path | Role |
| --- | --- |
| `~/.config/mm/config` | Settings (never `source`d) |
| `~/Library/Logs/mm/` | Daily / weekly / menu-extra logs |
| `~/Library/Caches/mm/last-status.json` | Last menu snapshot |

```bash
mm config
mm config set daily_hour 8
mm logs
mm logs --follow
```

## Install tips

```bash
make reinstall
mm menubar disable && mm menubar enable   # rebuild the menu extra after upgrades
```

Homebrew tap of this repo:

```bash
brew tap r0pr1/mm https://github.com/R0PR1/a-little-Mac-Maintenance-Tool
brew install r0pr1/mm/mm
```

More detail: [commands.md](commands.md), [configuration.md](configuration.md), [homebrew.md](homebrew.md).
