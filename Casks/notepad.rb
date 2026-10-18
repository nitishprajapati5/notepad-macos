cask "notepad" do
  version "1.0.0"
  sha256 "5287607cbddf927937c9ef9db0a5fded46755b0b408f98ba1719b1e825bf5c04"

  url "https://github.com/nitishprajapati5/notepad-macos/releases/download/v#{version}/Notepad-macOS-v#{version}.dmg"
  name "Notepad"
  desc "Notepad++ clone for macOS powered by Scintilla"
  homepage "https://github.com/nitishprajapati5/notepad-macos"

  livecheck do
    url :url
    strategy :github_latest
  end

  app "Notepad.app"

  postflight do
    # Remove macOS quarantine flag so users can open the app without Gatekeeper blocking
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{appdir}/Notepad.app"],
                   sudo: false
  end

  zap trash: [
    "~/Library/Application Support/Notepad",
    "~/Library/Preferences/com.notepad.mac.plist",
    "~/Library/Saved Application State/com.notepad.mac.savedState",
  ]
end
