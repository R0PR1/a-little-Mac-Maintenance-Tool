# Configuration

Location: `~/.config/mm/config`

The file is created on first use with the defaults below. `mm` parses it with `awk` and an allow-list. It is **never** `source`d, so a malicious value cannot execute code.

Permissions: `600`.

## Keys

| Key | Type | Default | Notes |
| --- | --- | --- | --- |
| `daily_enabled` | bool | `true` | Whether a daily check is desired |
| `daily_hour` | 0–23 | `09` | launchd hour |
| `daily_minute` | 0–59 | `15` | launchd minute |
| `weekly_enabled` | bool | `false` | Weekly LaunchAgent |
| `weekly_day` | 0–6 | `0` | Sunday = 0 |
| `weekly_hour` | 0–23 | `10` | |
| `weekly_minute` | 0–59 | `00` | |
| `weekly_upgrade` | bool | `false` | Weekly job may run `mm upgrade` |
| `upgrade_casks` | bool | `false` | Allow cask upgrades |
| `cleanup` | bool | `true` | `brew cleanup` after upgrade |
| `check_macos` | bool | `true` | Show automatic update policy on the dashboard |
| `check_battery` | bool | `true` | Hide battery on desktops automatically if none is present |
| `check_time_machine` | bool | `true` | |
| `check_thermal` | bool | `true` | |
| `disk_warning` | 0–100 | `80` | Must be **lower** than `disk_critical` |
| `disk_critical` | 0–100 | `90` | Dashboard exit 2 at or above this percent |

Booleans must be exactly `true` or `false`.
