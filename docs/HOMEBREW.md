# Distributing Notepad for macOS via Homebrew Cask

This guide explains how to distribute and install **Notepad for macOS** via Homebrew Cask without needing a paid Apple Developer Account or Apple Notarization.

---

## 1. How Users Install via Homebrew

### Method A: Single Command Direct Install (Easiest)

Any user can immediately install Notepad without adding a tap:

```bash
brew install --cask https://raw.githubusercontent.com/nitishprajapati5/notepad-macos/main/Casks/notepad.rb
```

### Method B: Via Custom Tap (`brew tap`)

Once you create a `homebrew-notepad` repository on GitHub:

```bash
# Tap your repository
brew tap nitishprajapati5/notepad

# Install Notepad
brew install --cask notepad
```

Or in a single line:
```bash
brew install --cask nitishprajapati5/notepad/notepad
```

---

## 2. Why Homebrew Solves the Gatekeeper Warning

When users download `.dmg` files via Safari or Chrome, macOS assigns a quarantine flag (`com.apple.quarantine`), blocking unnotarized apps.

The `Casks/notepad.rb` cask formula automatically includes a **postflight** action:

```ruby
postflight do
  system_command "/usr/bin/xattr",
                 args: ["-cr", "#{appdir}/Notepad.app"],
                 sudo: false
end
```

When Homebrew installs Notepad, it automatically removes the quarantine flag so the user can open `Notepad.app` directly from Spotlight or `/Applications` **without any Gatekeeper warning!**

---

## 3. Setting Up Your Homebrew Tap Repository (One-Time Setup)

To allow users to run `brew tap nitishprajapati5/notepad`:

1. On GitHub, create a new public repository named **`homebrew-notepad`**:
   - Repository URL: `https://github.com/nitishprajapati5/homebrew-notepad`
2. Clone it and create a `Casks` folder:
   ```bash
   git clone https://github.com/nitishprajapati5/homebrew-notepad.git
   cd homebrew-notepad
   mkdir -p Casks
   ```
3. Copy `Casks/notepad.rb` from this repository:
   ```bash
   cp /path/to/notepad/Casks/notepad.rb Casks/
   git add Casks/notepad.rb
   git commit -m "feat: add notepad cask"
   git push origin main
   ```
4. Done! Users can now run `brew tap nitishprajapati5/notepad && brew install --cask notepad`.

---

## 4. Updating the Cask for New Releases

Whenever you publish a new version (e.g. `v1.1.0`):

1. Build and package the release:
   ```bash
   make package
   ```
2. Automatically update the version and SHA-256 checksum:
   ```bash
   make update-cask
   ```
3. Commit and push the updated `Casks/notepad.rb`.
