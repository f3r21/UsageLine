cask "usageline" do
  version "0.1.0"
  sha256 :no_check # replace with the real sha256 from the first published release

  url "https://github.com/f3r21/UsageLine/releases/download/v#{version}/UsageLine.dmg"
  name "UsageLine"
  desc "Minimal macOS menu bar text indicator for Claude Code rate limits"
  homepage "https://github.com/f3r21/UsageLine"

  app "UsageLine.app"

  caveats <<~EOS
    UsageLine is ad-hoc signed. After installing, run this once to fix the
    "damaged / unidentified developer" launch error:
      codesign --force --deep --sign - /Applications/UsageLine.app && xattr -d com.apple.quarantine /Applications/UsageLine.app
  EOS

  zap trash: [
    "~/Library/Preferences/local.usageline.plist",
  ]
end
