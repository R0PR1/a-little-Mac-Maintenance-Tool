# Contributing

Thanks for wanting to improve `mm`. Keep the tool small, honest, and safe.

## Before you open a PR

```bash
make syntax
make lint
make test
```

To install a local copy:

```bash
make install          # payload in ~/.local/share/mm, launcher in ~/.local/bin
make link             # launcher pointing at this checkout
```

## Rules of the road

- Keep `bin/mm` as a router. Put logic in `lib/mm/*.sh`.
- Status, doctor, security, logs, and version stay read-only.
- Do not introduce implicit `sudo` or surprise upgrades.
- Weekly upgrades and cask upgrades must default to off.
- Add or update Bats tests for every behavior change.
- Tests must mock system commands. Never touch the developer’s real Homebrew, LaunchAgents, or security settings.
- Quote every expansion. Stay ShellCheck-clean.

Read [CURSOR.md](CURSOR.md) and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
