# Contributing to Notepad for macOS

First off, thank you for considering contributing to **Notepad for macOS**! 🎉

Whether you are fixing a bug, adding a new feature, improving performance, polishing documentation, or suggesting enhancements, your contributions make this project better for everyone.

This project is an open-source initiative bringing the simplicity, speed, and familiarity of classic notepad editing natively to macOS, powered by the Scintilla 5 engine and native Cocoa/AppKit.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
  - [Reporting Bugs](#reporting-bugs)
  - [Suggesting Features](#suggesting-features)
  - [Contributing Code](#contributing-code)
  - [Improving Documentation](#improving-documentation)
- [Development Setup](#development-setup)
  - [Prerequisites](#prerequisites)
  - [Cloning the Repository](#cloning-the-repository)
  - [Building the Application](#building-the-application)
  - [Packaging Distribution Artifacts](#packaging-distribution-artifacts)
  - [Running and Debugging](#running-and-debugging)
- [Code Style & Standards](#code-style--standards)
  - [Formatting with ClangFormat](#formatting-with-clangformat)
  - [Objective-C++ & C++ Guidelines](#objective-c--c-guidelines)
  - [macOS Human Interface Guidelines](#macos-human-interface-guidelines)
- [Commit Message Conventions](#commit-message-conventions)
- [Pull Request Process](#pull-request-process)
- [Architecture Overview](#architecture-overview)
- [Getting Help](#getting-help)

---

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior following the guidelines outlined in that document.

---

## How Can I Contribute?

### Reporting Bugs

A great bug report helps us identify, reproduce, and fix issues quickly. Before filing an issue:

1. **Check existing issues** to see if the bug has already been reported.
2. Use the [Bug Report template](.github/ISSUE_TEMPLATE/bug_report.yml).
3. Provide essential details:
   - macOS version (e.g., macOS 14 Sonoma, macOS 15 Sequoia).
   - Machine architecture: Apple Silicon (`arm64`) vs. Intel (`x86_64`).
   - Clear, step-by-step reproduction steps.
   - Expected vs. actual behavior.
   - Screenshots or screen recordings if relevant.
   - Crash reports or console logs if applicable (available in macOS Console app).

### Suggesting Features

We welcome ideas that align with the project's vision of a clean, fast, native text editor. Before suggesting a feature:

1. Search existing issues and discussions to avoid duplicates.
2. Open an issue using the [Feature Request template](.github/ISSUE_TEMPLATE/feature_request.yml).
3. Clearly describe:
   - The problem or use-case you are trying to solve.
   - The proposed solution and expected workflow.
   - Any alternatives considered.
   - UI/UX mockups if visual changes are involved.

### Contributing Code

If you would like to submit code:

1. Browse open issues labeled `good first issue` or `help wanted` for beginner-friendly starting points.
2. If working on a significant feature or refactoring, open an issue first to discuss the design before writing extensive code.
3. Follow our [Commit Message Conventions](#commit-message-conventions) so that automated semantic versioning and changelog generation work seamlessly.

### Improving Documentation

Documentation improvements (fixing typos, explaining setup steps, updating keyboard shortcuts, or documenting architecture components) are always welcome and highly valued!

---

## Development Setup

### Prerequisites

- **macOS**: macOS 11.0 (Big Sur) or higher.
- **Xcode Command Line Tools**:
  ```bash
  xcode-select --install
  ```
- **Clang / AppleClang**: Comes with Xcode Command Line Tools (C++17 and Objective-C++ ARC support).
- **clang-format** (for code style enforcement):
  ```bash
  brew install clang-format
  ```
- **CMake** (optional, minimum version 3.16):
  ```bash
  brew install cmake
  ```

### Cloning the Repository

```bash
git clone https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos.git
cd nextpad-plus-plus-macos
```

### Building the Application

#### Option 1: Fast Build with Make (Recommended)

Our standalone `Makefile` compiles a Universal 2 fat binary supporting both **Apple Silicon (`arm64`)** and **Intel (`x86_64`)**:

```bash
# Compile using all available CPU cores
make -j$(sysctl -n hw.ncpu)
```

The resulting application bundle will be created at:
```
build/Notepad.app
```

To clean build artifacts:
```bash
make clean
```

#### Option 2: Building with CMake

```bash
# Configure release build
cmake -B build-cmake -DCMAKE_BUILD_TYPE=Release

# Build
cmake --build build-cmake -j$(sysctl -n hw.ncpu)
```

The resulting application bundle will be located at `build-cmake/Notepad.app`.

### Packaging Distribution Artifacts

To create release-ready `.dmg` installers and universal `.zip` archives with SHA-256 checksums:

```bash
make package
```

Generated outputs in `build/`:
- `Notepad-macOS.dmg` — Drag-and-drop installer image.
- `Notepad-macOS-Universal.zip` — Portable universal bundle archive.
- `checksums.txt` — SHA-256 integrity checksums.

### Running and Debugging

Launch your freshly built application directly:
```bash
open build/Notepad.app
```

Or open a specific file or sample:
```bash
open -a build/Notepad.app sample.txt
```

To run with terminal logs and lldb debugging:
```bash
./build/Notepad.app/Contents/MacOS/Notepad
```

---

## Code Style & Standards

### Formatting with ClangFormat

We enforce consistent code formatting across all C, C++, and Objective-C++ files using `.clang-format` (LLVM-derived, 4 spaces indent, 120 column limit).

Before committing your changes, always format your code:

```bash
# Format all source files automatically
make format

# Verify formatting without modifying files (same check run in CI)
make check-format
```

Pull requests will fail the automated CI check if `make check-format` reports any formatting discrepancies.

### Objective-C++ & C++ Guidelines

1. **Modern C++**: Use C++17 standards. Prefer standard library containers (`std::vector`, `std::string`) when interacting with Scintilla core.
2. **Automatic Reference Counting (ARC)**: All Objective-C code must use ARC. Never manually invoke `retain`, `release`, or `autorelease`.
3. **Memory Safety**:
   - Prevent retain cycles by using `__weak` references in block callbacks and delegate relationships.
   - Wrap large batch operations (such as streaming multi-megabyte files or heavy search operations) in local `@autoreleasepool { ... }` blocks to prevent memory spikes.
4. **Naming Conventions**:
   - Objective-C classes and categories should be clear and prefixed (e.g., `NotepadWindowController`, `ScintillaView+Notepad`).
   - Use descriptive method and property names following Apple's Cocoa conventions.
5. **Robust Error Handling**: Always check `NSError` when reading/writing files and present clear, native alerts to the user rather than failing silently.

### macOS Human Interface Guidelines

- **Appearance**: Support both macOS Light Mode and Dark Mode dynamically using semantic system colors (`NSColor.labelColor`, `NSColor.windowBackgroundColor`, etc.).
- **Typography**: Respect native font hierarchies, using `NSFont.monospacedSystemFontOfSize` or system monospaced fonts (`SF Mono`, `Menlo`).
- **Keyboard Navigation**: Maintain standard macOS keyboard shortcuts (`Cmd+S`, `Cmd+O`, `Cmd+F`, `Cmd+Z`, `Cmd+W`, etc.).

---

## Commit Message Conventions

This repository follows the **[Conventional Commits](https://www.conventionalcommits.org/)** specification. Automated tools (Semantic Release) analyze commit messages to automatically determine version bumps, generate changelogs, and publish releases.

### Format

```text
<type>(<optional scope>): <description>

[optional body]

[optional footer(s)]
```

### Types

| Type | Description | Release Bump |
|------|-------------|--------------|
| `feat` | A new feature | **Minor** (e.g., 1.0.0 -> 1.1.0) |
| `fix` | A bug fix | **Patch** (e.g., 1.0.0 -> 1.0.1) |
| `perf` | A code change that improves performance | **Patch** (e.g., 1.0.0 -> 1.0.1) |
| `docs` | Documentation changes only | None |
| `style` | Formatting, missing semi-colons, no code logic changes | None |
| `refactor` | Code restructuring without fixing a bug or adding a feature | None |
| `test` | Adding missing tests or correcting existing tests | None |
| `chore` | Build process, auxiliary tools, dependencies, workflows | None |

### Examples

```bash
# Feature
git commit -m "feat(tabs): add drag-and-drop tab reordering support"

# Bug fix
git commit -m "fix(statusbar): prevent line number overlapping status bar on window resize"

# Performance improvement
git commit -m "perf(search): optimize regex search across large documents"

# Documentation
git commit -m "docs: add contributor guidelines and security policy"
```

> **Note on Breaking Changes**: If introducing a breaking change, include `BREAKING CHANGE:` in the commit footer or append a `!` after the type (e.g., `feat!: rewrite preferences storage engine`). This triggers a **Major** release (e.g., 1.0.0 -> 2.0.0).

---

## Pull Request Process

1. **Fork and branch**: Create a descriptive branch name from `main`:
   ```bash
   git checkout -b feat/your-feature-name
   ```
2. **Make your changes**: Write clean, modular, and readable code.
3. **Verify formatting**:
   ```bash
   make format
   make check-format
   ```
4. **Compile and test**: Ensure the application compiles without warnings and runs smoothly:
   ```bash
   make clean && make -j4
   make package
   ```
5. **Commit**: Ensure commit messages adhere to Conventional Commits.
6. **Push to your fork**:
   ```bash
   git push origin feat/your-feature-name
   ```
7. **Open a Pull Request**: Submit your pull request against the `main` branch.
   - Complete the [Pull Request Template](.github/PULL_REQUEST_TEMPLATE.md).
   - Link any related issues (`Closes #123` or `Fixes #456`).
   - Include before/after screenshots or GIFs for any UI changes.
8. **Review**: Maintainers will review your PR. Be prepared to discuss implementation details or address requested revisions.

---

## Architecture Overview

Here is a quick map of the project structure to help orient your contributions:

```text
notepad/
├── Makefile                          # Fast build, packaging, and code formatting
├── CMakeLists.txt                    # Cross-platform CMake configuration
├── .clang-format                     # Unified C/C++/Obj-C++ formatting rules
├── .github/                          # Workflows, issue templates, PR template
│   ├── workflows/ci.yml              # CI: build, format check, packaging test
│   ├── workflows/release.yml         # Automated semantic release & asset uploads
│   └── ISSUE_TEMPLATE/               # Structured GitHub issue forms
├── resources/                        # Application icons, Info.plist
├── scintilla/                        # Scintilla 5 editing component
│   ├── include/                      # Public Scintilla API headers
│   ├── src/                          # C++ core editing engine & buffers
│   └── cocoa/                        # ScintillaView Cocoa wrapper
└── src/                              # Application native layer
    ├── main.mm                       # Application entry point
    ├── AppDelegate.{h,mm}            # Application lifecycle & menu setup
    ├── NotepadWindowController.{h,mm}# Main window & editor coordinator
    ├── ScintillaView+Notepad.{h,mm}  # Notepad styling & zoom/encoding helpers
    ├── StatusBarView.{h,mm}          # Status bar cells (cursor, zoom, CRLF, UTF-8)
    ├── NotepadTabBarView.{h,mm}      # Multi-document tab bar component
    ├── FindReplaceController.{h,mm}  # Modeless Find & Replace panel
    ├── NotepadDocumentController.{h,mm} # Document & Recent Files management
    ├── NotepadFileManager.{h,mm}     # Streaming file loader & encoding detection
    └── PreferencesManager.{h,mm}     # Preferences storage & theme manager
```

---

## Getting Help

If you have questions or get stuck:
- Open a question or discussion topic in [GitHub Issues](https://github.com/nextpad-plus-plus/nextpad-plus-plus-macos/issues).
- Check the [README](README.md) for full application feature lists and shortcuts.
- Feel free to ask for guidance in your pull request!

Thank you for helping make Notepad for macOS an outstanding open-source application! 🚀
