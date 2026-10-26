# frozen_string_literal: true

# Convenience copy of Formula/mm.rb for:
#   brew install --HEAD --build-from-source packaging/homebrew/mm.rb
#
# Canonical tap entry point is Formula/mm.rb:
#   brew tap r0pr1/mm https://github.com/R0PR1/a-little-Mac-Maintenance-Tool
#   brew install r0pr1/mm/mm

class Mm < Formula
  desc "Tiny macOS health dashboard and safe Homebrew maintenance CLI"
  homepage "https://github.com/R0PR1/a-little-Mac-Maintenance-Tool"
  license "MIT"
  head "https://github.com/R0PR1/a-little-Mac-Maintenance-Tool.git", branch: "main"

  depends_on :macos

  livecheck do
    skip "Head-only until a tagged release"
  end

  def install
    libexec.install "bin", "lib", "launchd", "completions", "macos", "scripts", "docs", "VERSION"
    (bin/"mm").write <<~EOS
      #!/bin/bash
      exec "#{libexec}/bin/mm" "$@"
    EOS
    chmod 0755, bin/"mm"
    zsh_completion.install libexec/"completions/_mm"
  end

  def caveats
    <<~EOS
      mm never upgrades packages unless you run `mm upgrade`
      or enable weekly_upgrade in ~/.config/mm/config.

      After install:
        mm schedule enable daily
        mm menubar enable

      Rebuild the menu extra after `brew upgrade mm`:
        mm menubar disable && mm menubar enable
    EOS
  end

  test do
    assert_match(/^mm /, shell_output("#{bin}/mm version"))
  end
end
