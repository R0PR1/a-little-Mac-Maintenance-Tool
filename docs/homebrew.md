# Homebrew tap

`mm` is installed from **this repository as a tap**, not from `homebrew/core`. The short name is too generic for core until there is a tagged release and a stable user base.

```bash
brew tap r0pr1/mm https://github.com/R0PR1/a-little-Mac-Maintenance-Tool
brew install r0pr1/mm/mm
```

The formula is head-only (`Formula/mm.rb`) until a git tag exists. `brew install r0pr1/mm/mm` therefore builds from `main`.

```bash
mm schedule enable daily
mm menubar enable
```

`mm self-update` on a Homebrew install runs `brew update` then `brew upgrade mm`. After an upgrade, rebuild the menu extra so it picks up a new `MmExtra` binary:

```bash
mm menubar disable && mm menubar enable
```

## Adding a stable bottle later

Do **not** tag from a feature branch. After this formula has merged to `main`:

```bash
git tag v0.1.0
git push origin v0.1.0
curl -sL https://github.com/R0PR1/a-little-Mac-Maintenance-Tool/archive/refs/tags/v0.1.0.tar.gz | shasum -a 256
```

Put that checksum in `Formula/mm.rb` (and the copy in `packaging/homebrew/mm.rb`):

```ruby
url "https://github.com/R0PR1/a-little-Mac-Maintenance-Tool/archive/refs/tags/v0.1.0.tar.gz"
sha256 "<checksum>"
head "https://github.com/R0PR1/a-little-Mac-Maintenance-Tool.git", branch: "main"
```

That URL is GitHub’s automatic source archive, not the `mac-maintenance-*.tar.gz` artifact from `.github/workflows/release.yml`.

Local file install from a checkout:

```bash
brew install --HEAD --build-from-source Formula/mm.rb
```
