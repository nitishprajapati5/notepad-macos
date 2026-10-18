# Notepad for macOS

[![CI](https://github.com/nitishprajapati5/notepad-macos/actions/workflows/ci.yml/badge.svg)](https://github.com/nitishprajapati5/notepad-macos/actions/workflows/ci.yml)
[![Release](https://github.com/nitishprajapati5/notepad-macos/actions/workflows/release.yml/badge.svg)](https://github.com/nitishprajapati5/notepad-macos/actions/workflows/release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.1-4baaaa.svg)](CODE_OF_CONDUCT.md)

A fast, lightweight, native macOS text editor designed to bring the classic simplicity, speed, and familiarity of **Windows Notepad** to the Mac. Powered by the battle-tested **Scintilla 5** editing engine and built with **Objective-C++** directly on Cocoa.

---

## Highlights

* **Classic Notepad Simplicity**: Minimalist plain-text editor with instant startup and near-zero memory footprint. No bloated IDE highlighters, trees, or sidebars.
* **Faithful Windows Notepad Features**:
  * **Status Bar**: Real-time 4-section status bar tracking cursor `Ln X, Col Y`, `Zoom %`, Line Endings (`Windows (CRLF)` / `Unix (LF)`), and Encoding (`UTF-8`, `ANSI`, `UTF-16`).
  * **Time/Date Insertion (F5)**: Instant timestamp stamp matching the signature Windows Notepad behavior.
  * **Go To Line**: Quick navigation prompt (`Cmd+L`).
  * **Zoom Control**: Zoom In (`Cmd++`), Zoom Out (`Cmd+-`), and Reset to 100% (`Cmd+0`).
  * **Word Wrap**: Easily toggleable without altering underlying document line breaks.
  * **Find & Replace**: Clean modeless find and replace dialog (`Cmd+F` / `Cmd+H`).
* **Universal 2 Binary**: Compiled natively for both **Apple Silicon (`arm64`)** and **Intel (`x86_64`)** processors.
* **Mac-Native Experience**:
  * Dynamic Dark Mode & Light Mode appearance adaptation.
  * macOS document proxy icons (Cmd+click title bar to see file hierarchy).
  * Native sheet dialogs for Save / Don't Save / Cancel confirmations.
  * High-DPI Retina text rendering and native selection accents.
  * Monospaced typography using **SF Mono** or **Menlo**.

---

## Installation

### Option A: Install via Homebrew Cask (Recommended)

Install directly with a single command without worrying about macOS Gatekeeper warnings:

```bash
brew install --cask https://raw.githubusercontent.com/nitishprajapati5/notepad-macos/main/Casks/notepad.rb
```

Or via the custom tap:

```bash
brew tap nitishprajapati5/notepad
brew install --cask notepad
```

---

### Option B: Download Installer DMG (GitHub Releases)

1. Download the latest **`Notepad-macOS-vX.X.X.dmg`** from [GitHub Releases](https://github.com/nitishprajapati5/notepad-macos/releases).
2. Open the DMG and drag **Notepad.app** into your **/Applications** folder.
3. **First-Launch on macOS (Unnotarized / Open-Source):**
   - **Method 1 (GUI):** In Finder, go to `/Applications`, **Right-click (Control-click)** on `Notepad.app`, and select **Open**. Click **Open** on the confirmation prompt.
   - **Method 2 (Terminal):** Run the following command once:
     ```bash
     xattr -cr /Applications/Notepad.app
     ```

---

## Architecture & Project Structure

The project follows a clean, modular structure modeled after modern Mac Scintilla applications:

```
notepad/
├── CMakeLists.txt              # Cross-platform CMake build configuration
├── Makefile                    # Standalone fast Makefile (Universal fat binary)
├── resources/                  # Bundle assets & Info.plist
│   └── Info.plist
├── scintilla/                  # Scintilla 5 Core & Cocoa platform layer
│   ├── include/                # Scintilla public headers (Scintilla.h, Sci_Position.h)
│   ├── src/                    # C++ core editing engine (buffer, document, undo)
│   └── cocoa/                  # Native Cocoa implementation (ScintillaView, PlatCocoa)
└── src/                        # Application Objective-C++ source files
    ├── main.mm                 # Application entry point
    ├── AppDelegate.{h,mm}      # Application lifecycle, menus, and window registry
    ├── NotepadWindowController.{h,mm} # Document window controller & Scintilla delegate
    ├── ScintillaView+Notepad.{h,mm}   # Category adding Notepad styling & conveniences
    ├── StatusBarView.{h,mm}    # Fixed-cell status bar with native separators
    ├── FindReplaceController.{h,mm}   # Find and replace panel
    ├── NotepadDocumentController.{h,mm} # Custom NSDocumentController for Open Recent
    ├── NotepadFileManager.{h,mm}      # File load/save operations & encoding detection
    └── PreferencesManager.{h,mm}      # Persistent defaults (font, wrap, tabs, status bar)
```

---

## Requirements

* **macOS**: macOS 11.0 (Big Sur) or later.
* **Compiler**: Clang / AppleClang with C++17 and Objective-C++ ARC support.
* **Build Tools**: Xcode Command Line Tools (`xcode-select --install`) and optionally `cmake` 3.16+.

---

## Building

### Method 1: Using Make (Recommended)

To build the universal application bundle:

```bash
# Build Universal 2 binary (arm64 + x86_64)
make -j4
```

The resulting application bundle will be created at:
```
build/Notepad.app
```

To clean previous build artifacts:
```bash
make clean
```

---

### Method 2: Using CMake

```bash
# Configure
cmake -B build-cmake -DCMAKE_BUILD_TYPE=Release

# Build
cmake --build build-cmake -j4
```

The resulting application bundle will be located at:
```
build-cmake/Notepad.app
```

---

## Packaging for Distribution (DMG & ZIP)

Create a signed/notarized-ready installer disk image (`.dmg`) and compressed archive (`.zip`) with SHA-256 checksums:

```bash
make package
```

Outputs:
* `build/Notepad-macOS.dmg` — Drag-and-drop macOS installer disk image.
* `build/Notepad-macOS-Universal.zip` — Portable universal bundle archive.
* `build/checksums.txt` — SHA-256 integrity hashes.

---

## Verifying Universal 2 Binary

You can verify that the compiled executable contains fat binary slices for both Apple Silicon and Intel systems:

```bash
lipo -info build/Notepad.app/Contents/MacOS/Notepad
# Output:
# Architectures in the fat file: build/Notepad.app/Contents/MacOS/Notepad are: x86_64 arm64
```

---

## Running the App

Launch the application directly from the terminal:

```bash
open build/Notepad.app
```

Or open a specific file:

```bash
open -a build/Notepad.app document.txt
```

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd + N` | New Document |
| `Cmd + Shift + N` | New Window |
| `Cmd + O` | Open Document… |
| `Cmd + S` | Save |
| `Cmd + Shift + S` | Save As… |
| `Cmd + P` | Print… |
| `Cmd + W` | Close Window |
| `Cmd + Z` | Undo |
| `Cmd + Shift + Z` | Redo |
| `Cmd + F` | Find… |
| `Cmd + G` | Find Next |
| `Cmd + Shift + G` | Find Previous |
| `Cmd + H` | Replace… |
| `Cmd + L` | Go To Line… |
| `F5` | Insert Current Time/Date |
| `Cmd + +` | Zoom In |
| `Cmd + -` | Zoom Out |
| `Cmd + 0` | Restore Default Zoom |

---

## Contributing & Community

Contributions are warmly welcome! Whether you are reporting a bug, proposing a new feature, improving documentation, or submitting a pull request, we'd love your help:

* **[Contributing Guidelines](CONTRIBUTING.md)** — Step-by-step development setup, build instructions, coding standards, and Conventional Commits workflow.
* **[Code of Conduct](CODE_OF_CONDUCT.md)** — Contributor Covenant v2.1 community standards and pledge.
* **[Security Policy](SECURITY.md)** — Vulnerability disclosure procedure and supported versions.
* **[Issue Tracker](https://github.com/nitishprajapati5/notepad-macos/issues)** — Bug reports, feature suggestions, and discussions.

---

## License & Credits

* **Scintilla**: Copyright © 1998-2023 by Neil Hodgson. Used under the [Scintilla License](scintilla/License.txt).
* **Notepad for macOS**: Open-source, licensed under the [MIT License](LICENSE).
