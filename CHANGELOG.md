## [1.2.2](https://github.com/nitishprajapati5/notepad-macos/compare/v1.2.1...v1.2.2) (2026-10-24)


### Bug Fixes

* remove postflight_steps block (appdir not available in modern Homebrew DSL) ([eb6d255](https://github.com/nitishprajapati5/notepad-macos/commit/eb6d2551879204cf040cd657800fef3eed6c7240))
* update sha256 checksum to match current DMG release ([02d41b4](https://github.com/nitishprajapati5/notepad-macos/commit/02d41b4f2439c771307276b2224184b1d24abfef))

## [1.2.1](https://github.com/nitishprajapati5/notepad-macos/compare/v1.2.0...v1.2.1) (2026-10-24)


### Bug Fixes

* replace deprecated postflight with postflight_steps ([fa26664](https://github.com/nitishprajapati5/notepad-macos/commit/fa266648cb1a96bddeefb7606f341a8febfdaf20))

# [1.2.0](https://github.com/nitishprajapati5/notepad-macos/compare/v1.1.0...v1.2.0) (2026-10-24)


### Features

* add ad-hoc signing workflow and homebrew cask distribution ([e0f9bbb](https://github.com/nitishprajapati5/notepad-macos/commit/e0f9bbba322cb3cc0e88c907709db70d146353ff))
* add hardened runtime entitlements, signing, and notarization pipeline ([cf65e5e](https://github.com/nitishprajapati5/notepad-macos/commit/cf65e5ee1ee13aaeaed0411f707354bd1f933158))

# [1.1.0](https://github.com/nitishprajapati5/notepad-macos/compare/v1.0.0...v1.1.0) (2026-10-18)


### Features

* implement automatic session preservation, continuous auto-save, and macOS version history ([e99448d](https://github.com/nitishprajapati5/notepad-macos/commit/e99448dd3801ef7c15974690d7426bebddbc6bf3))

# 1.0.0 (2026-10-17)


### Bug Fixes

* enforce Aqua appearance and robust default text styling in Scintilla view and Cocoa platform layer ([8acd196](https://github.com/nitishprajapati5/notepad-macos/commit/8acd196b4eb960286b1f327a3be79199da11a5d8))


### Features

* add animated empty document overlay view with shortcut and tip guidance ([20bc394](https://github.com/nitishprajapati5/notepad-macos/commit/20bc3948c9004eadce9371d92596bc51a7d57307))
* add CI/CD workflows, packaging make targets, and documentation ([79c2e83](https://github.com/nitishprajapati5/notepad-macos/commit/79c2e830da60cab7dab05d13df1d9dc1657dbcba))
* add custom document controller for open recent and improve file management and menu validation ([b230d4d](https://github.com/nitishprajapati5/notepad-macos/commit/b230d4d87b2dda18da534b4ec81b8984aa887b3f))
* add initial project files and Scintilla text editor integration for macOS notepad ([8261ee5](https://github.com/nitishprajapati5/notepad-macos/commit/8261ee51069ee74f71ce970547c47a457fd68168))
* add multi-tab support with custom tab bar view and tab management actions ([8351af6](https://github.com/nitishprajapati5/notepad-macos/commit/8351af66655050ea11a81ee9ace2d8d043bfd9f7))
* add native macOS app icon and empty document vector illustration ([81d43a8](https://github.com/nitishprajapati5/notepad-macos/commit/81d43a83e471dd205f1c10113dfe5df24bc6f375))
* add preferences window and expand user configuration options ([a50eb84](https://github.com/nitishprajapati5/notepad-macos/commit/a50eb844d3c9cdaec8b175f789cf736bf4fea1bf))
* add ScintillaPrintView to support document printing and pagination ([f650213](https://github.com/nitishprajapati5/notepad-macos/commit/f650213b94915105d586133a544c85afdc9198bc))
* add Settings menu with Style Configurator and update tab bar styling ([e1ff04b](https://github.com/nitishprajapati5/notepad-macos/commit/e1ff04bb1807aa2cd7997be5ed78fdbc5f4fe4b5))
* add support for customizable theme modes with light, dark, and system options ([f76f783](https://github.com/nitishprajapati5/notepad-macos/commit/f76f783d8c49c1e0ecd780e21a98e6d4d742d92f))
* configure semantic-release and dynamic build versioning ([369202b](https://github.com/nitishprajapati5/notepad-macos/commit/369202b2eac93a1a0b3f94fba823f21c905788b7))
* enhance find and replace panel with regex support, match counters, and navigation UI ([c7c2cd2](https://github.com/nitishprajapati5/notepad-macos/commit/c7c2cd21c32f01ca676078d9cd18c03ecde644e0))
* improve line number scaling, file encoding detection, status bar styling, and layout management ([895e2b1](https://github.com/nitishprajapati5/notepad-macos/commit/895e2b15e96a5cbcd5cbcfea61d7ab2f6e0427e8))
* replace status bar text labels with interactive custom buttons ([3670bc2](https://github.com/nitishprajapati5/notepad-macos/commit/3670bc2796472e93b1a612243bdc7b54ce6b1acc))
* update default font size from 12 to 16 points ([6cc3617](https://github.com/nitishprajapati5/notepad-macos/commit/6cc36172091587f9b5ef28ae311b7c6878bcef02))


### Performance Improvements

* optimize search performance and file loading efficiency for large documents ([9ad2f7e](https://github.com/nitishprajapati5/notepad-macos/commit/9ad2f7ee42460c8947aff4dd92fdc07a64d8b8f1))
