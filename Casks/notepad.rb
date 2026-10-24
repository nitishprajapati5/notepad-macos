cask "notepad" do
  version "1.0.0"
  sha256 "45509453a21f7b5775e92064c02e0fb774c4975a0340c668d588616ebfa306ac"

  url "https://github.com/nitishprajapati5/notepad-macos/releases/download/v#{version}/Notepad-macOS-v#{version}.dmg"
  name "Notepad"
  desc "Notepad++ clone for macOS powered by Scintilla"
  homepage "https://github.com/nitishprajapati5/notepad-macos"

  livecheck do
    url :url
    strategy :github_latest
  end

  app "Notepad.app"

  zap trash: [
    "~/Library/Application Support/Notepad",
    "~/Library/Preferences/com.notepad.mac.plist",
    "~/Library/Saved Application State/com.notepad.mac.savedState",
  ]
end
