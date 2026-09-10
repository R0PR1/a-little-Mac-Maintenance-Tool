# Security policy

Please report security issues privately to the repository maintainer
([@R0PR1](https://github.com/R0PR1)) rather than opening a public issue.

`mm` must never request or store credentials and should not require `sudo`
for normal operation. It must not delete user documents, and it must not
enable or disable FileVault, SIP, Gatekeeper, or the firewall.

A useful report includes:

- `mm version`
- macOS version and chip (Intel / Apple Silicon)
- The exact command you ran
- Why the behavior is surprising or unsafe
