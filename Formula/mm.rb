# frozen_string_literal: true

# Homebrew tap of this repository (not homebrew/core — the name `mm` is too short
# for core until a tagged release and a stable install base exist).
#
#   brew tap r0pr1/mm https://github.com/R0PR1/a-little-Mac-Maintenance-Tool
#   brew install r0pr1/mm/mm
#
# Head-only until a git tag exists. After tagging v0.1.0 on main:
#   curl -L https://github.com/R0PR1/a-little-Mac-Maintenance-Tool/archive/refs/tags/v0.1.0.tar.gz | shasum -a 256
# then add url/sha256 above `head`.

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
    libexec.install "bin", "lib", "launchd", "completions", "macos", "scripts", "VERSION"
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
