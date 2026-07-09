# Rewritr

[![CI](https://github.com/jameswei/rewritr/actions/workflows/ci.yml/badge.svg)](https://github.com/jameswei/rewritr/actions/workflows/ci.yml)

Rewritr is a native macOS app for helping non-native English speakers rewrite selected English into smoother, more natural, native-like English.

The v1 product is intentionally small: select text in another app, trigger Rewritr, send the selected text to your configured OpenAI-compatible provider, then either review the rewrite before replacing or replace it instantly. The rewrite should preserve meaning and avoid academic, thesis-like, overly formal, slangy, or filler-heavy English.

## Usage

- Launch Rewritr. It runs as a menu bar app and does not show a Dock icon.
- Open `Settings` from the menu bar item.
- Configure an OpenAI-compatible Chat Completions provider:
  - Base URL
  - Model
  - API key
  - Request timeout
  - Rewrite behavior: `Preview before replacing` or `Replace instantly`
- Grant Accessibility permission when prompted. Rewritr needs it to automate copy and paste for selected text.
- Select English text in another app and press `Control+Option+R`.

In preview mode, Rewritr shows the rewritten text with `Replace`, `Copy`, `Retry`, and `Dismiss` actions. In instant mode, it replaces the selected text in place after the provider returns.

## Privacy

- Selected text is sent only to the provider you configure.
- Rewritr has no backend service, accounts, analytics, or rewrite history in v1.
- Non-sensitive settings are stored in UserDefaults.
- The provider API key is stored locally in Keychain.
- Clipboard automation temporarily uses the macOS pasteboard and restores previous clipboard contents where safe.

## Compatibility

Rewritr works in most macOS apps and browser text fields that support normal copy and paste. There are important limits:

- You must explicitly select text before triggering rewrite.
- The target app must support normal `Command-C` and `Command-V` behavior for selected text.
- Secure fields such as password inputs should not be rewritten.
- Terminal support is limited because selected terminal text often refers to output/history rather than editable input.
- Remote desktops, virtual machines, browser-based IDEs, and apps with unusual focus handling may behave inconsistently.
- Clipboard managers may observe temporary clipboard changes even when Rewritr restores the clipboard afterward.

## Development Requirements

- macOS 15 or newer
- Xcode with macOS app build support

## Development

- Open `Rewritr.xcodeproj` in Xcode.
- Build the `Rewritr` scheme.
- Run a local build:

```sh
xcodebuild -project Rewritr.xcodeproj -scheme Rewritr -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/rewritr-dev-derived build CODE_SIGNING_ALLOWED=NO
```

- Run a test build:

```sh
xcodebuild -project Rewritr.xcodeproj -scheme Rewritr -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/rewritr-dev-derived build-for-testing CODE_SIGNING_ALLOWED=NO
```

- Run unit tests locally:

```sh
xcodebuild -project Rewritr.xcodeproj -scheme Rewritr -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/rewritr-dev-derived test CODE_SIGNING_ALLOWED=NO
```
