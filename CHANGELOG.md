# Changelog

## 1.1.0 - 2026-07-12

### Added

- Added a HUD appearance preference for instant replacement, with Minimal as the default and Classic as an alternative.

### Changed

- Refined instant-rewrite status feedback with clearer wording, a compact Minimal HUD, and longer visibility for failures that require manual pasting.
- Made Settings a larger, fixed one-page window so Provider, Rewrite, and Shortcut configuration are available without scrolling.

## 1.0.1 - 2026-07-11

### Fixed

- Fixed the packaged macOS app bundle icon so Finder, app switcher, and installed builds use the approved Rewritr icon.

## 1.0.0 - 2026-07-10

### Added

- First polished 1.0 macOS menu bar experience for selected-text English rewriting.
- First-run onboarding, How to Use, Permissions, Privacy, and About windows.
- Preview-before-replacing and replace-instantly rewrite modes.
- Floating status HUD for instant replacement progress.
- Keyboard shortcut recorder for changing the global rewrite shortcut.
- OpenAI-compatible provider setup with exact endpoint URL, model, timeout, and optional API key.
- Local-provider support when an OpenAI-compatible local model does not require an API key.
- App icon assets and a simplified About page with version and project links.
- GitHub Actions release packaging for unsigned macOS app zip artifacts.

### Changed

- Improved rewrite prompt to produce natural, native-like English without becoming academic, thesis-style, overly formal, slangy, or filler-heavy.
- Made provider connection testing friendlier, including clearer HTTP failure messages.
- Autosaved settings consistently and stored API keys only in macOS Keychain after a successful provider test.
- Refined Settings, Permissions, Privacy, How to Use, and rewrite preview UI layout.
- Updated the release workflow to build the Release configuration before packaging.

### Fixed

- Fixed preview Replace and Copy actions so rewritten text is applied or copied correctly.
- Fixed instant-replace mode so it no longer shows the preview window.
- Fixed preview dismissal during loading so cancellation does not reopen a failure preview.
- Fixed Settings spacing, menu ordering, and About page icon rendering.
