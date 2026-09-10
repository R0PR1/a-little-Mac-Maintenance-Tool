class Mm < Formula
  desc "Tiny macOS health and maintenance CLI"
  homepage "https://github.com/R0PR1/a-little-Mac-Maintenance-Tool"
  url "https://github.com/R0PR1/a-little-Mac-Maintenance-Tool/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "REPLACE_WITH_RELEASE_SHA256"
  license "MIT"

  def install
    libexec.install Dir["*"]
    bin.install_symlink libexec/"bin/mm" => "mm"
    zsh_completion.install libexec/"completions/_mm"
  end

  def caveats
    <<~EOS
      mm never upgrades packages unless you run `mm upgrade`
      or enable weekly_upgrade in ~/.config/mm/config.

      Enable a daily read-only Homebrew check:
        mm schedule enable daily
    EOS
  end

  test do
    assert_match "mm 0.1.0", shell_output("#{bin}/mm version")
  end
end
