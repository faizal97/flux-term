#!/bin/bash
set -euo pipefail

# Updates Homebrew tap with new version and SHA256 hashes.
# Usage: ./scripts/update-tap.sh <version> <sha_app> <sha_arm64> <sha_x86_64>

VERSION="$1"
SHA_APP="$2"
SHA_ARM="$3"
SHA_X86="$4"

TAP_DIR="${TAP_DIR:-/tmp/homebrew-tap}"

cat > "$TAP_DIR/Casks/fluxterm.rb" << EOF
cask "fluxterm" do
  version "${VERSION}"
  sha256 "${SHA_APP}"

  url "https://github.com/faizal97/flux-term/releases/download/v#{version}/FluxTerm.app.zip"
  name "FluxTerm"
  desc "GPU-accelerated macOS terminal emulator built with Swift and Metal"
  homepage "https://github.com/faizal97/flux-term"

  depends_on macos: ">= :sonoma"

  app "FluxTerm.app"

  zap trash: [
    "~/Library/Caches/com.faizal.fluxterm",
    "~/Library/Preferences/com.faizal.fluxterm.plist",
  ]
end
EOF

cat > "$TAP_DIR/Formula/fluxterm.rb" << EOF
class Fluxterm < Formula
  desc "GPU-accelerated macOS terminal emulator built with Swift and Metal"
  homepage "https://github.com/faizal97/flux-term"
  version "${VERSION}"
  license "MIT"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/faizal97/flux-term/releases/download/v${VERSION}/FluxTerm-macos-arm64.zip"
      sha256 "${SHA_ARM}"
    else
      url "https://github.com/faizal97/flux-term/releases/download/v${VERSION}/FluxTerm-macos-x86_64.zip"
      sha256 "${SHA_X86}"
    end
  end

  depends_on :macos
  depends_on macos: :sonoma

  def install
    bin.install "FluxTerm-arm64" => "fluxterm" if Hardware::CPU.arm?
    bin.install "FluxTerm-x86_64" => "fluxterm" unless Hardware::CPU.arm?
    bin.install "FluxTerm_FluxTerm.bundle"
  end

  test do
    assert_predicate bin/"fluxterm", :executable?
    assert_predicate bin/"FluxTerm_FluxTerm.bundle", :exist?
  end
end
EOF

cd "$TAP_DIR"
git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"
git add -A
git commit -m "Update FluxTerm to ${VERSION}"
git push
