# Roadmap

## Milestone 1 — harden the foundation — done in 0.1.0

- complete config value validation (booleans, hours, minutes, thresholds)
- add command mocks and Bats fixtures
- make `mm status` fully testable without touching real system state
- validate status exit codes
- eliminate any ShellCheck findings

## Milestone 2 — launchd — done in 0.1.0

- render plist templates safely
- implement `mm schedule enable daily|weekly`
- implement `mm schedule disable daily|weekly`
- implement `mm schedule reload`
- display configured schedule in `mm status`
- validate generated plist with `plutil -lint` when available
- add complete Bats tests with mocked `launchctl`

## Milestone 3 — health dashboard — done in 0.1.0

- disk thresholds from config
- real memory-pressure parsing
- thermal-pressure parsing
- battery health/cycle count
- Time Machine last backup age
- concise remediation messages

## Milestone 4 — security — done in 0.1.0

- FileVault
- SIP
- Gatekeeper
- Application Firewall
- macOS automatic update policy
- tests for parser variants

## Milestone 5 — Homebrew lifecycle — done in 0.1.0

- robust formula/cask counts
- explicit `mm upgrade`
- optional cask upgrades
- cleanup setting
- Brew doctor summary
- detect Apple Silicon and Intel correctly

## Milestone 6 — self update — done in 0.1.0

- robust Homebrew installation detection
- Git fast-forward-only self update
- clean-tree protection
- cached version check
- standalone update reports that it is unavailable

## Milestone 7 — release quality

- Zsh completion polish
- README screenshots/examples
- Homebrew formula finalization (checksum after first tag)
- release checksum workflow
- CI on Ubuntu (mocked) and macOS runners
- v1.0.0 release checklist
