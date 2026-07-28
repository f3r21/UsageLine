cask "usageline" do
  version "0.1.0"
  sha256 "33b07fde09e193e40a83cd028bab4a3b00e4f05a70fa4cf4b0149edd1b7d60af"

  url "https://github.com/f3r21/UsageLine/releases/download/v#{version}/UsageLine.dmg"
  name "UsageLine"
  desc "One-click installer for a Claude Code rate-limit usage line in your terminal"
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
