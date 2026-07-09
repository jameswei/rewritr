# Rewritr

[![CI](https://github.com/jameswei/rewritr/actions/workflows/ci.yml/badge.svg)](https://github.com/jameswei/rewritr/actions/workflows/ci.yml)

Rewritr is a native macOS menu bar app for non-native English speakers who want to rewrite selected English into smoother, more natural, native-like English.

It is intentionally small: select text in another app, trigger Rewritr, and replace the selected text with a clearer version. Rewritr preserves meaning and avoids academic, thesis-style, overly formal, slangy, or filler-heavy English.

## Download

Download the latest beta from [GitHub Releases](https://github.com/jameswei/rewritr/releases).

The current release artifact is an unsigned macOS app zip. After unzipping:

- Move `Rewritr.app` somewhere stable, such as `/Applications`.
- Open Rewritr.
- Grant Accessibility permission when prompted.
- Configure your OpenAI-compatible provider in Settings.

macOS grants Accessibility permission to the exact app bundle path. If you move the app after granting permission, you may need to grant permission again.

## How It Works

1. Select English text in any editable app.
2. Press `Control+Option+R`.
3. Rewritr copies the selected text with macOS automation.
4. Rewritr sends it to your configured OpenAI-compatible Chat Completions provider.
5. Rewritr either previews the rewrite or replaces the selected text instantly.

Rewritr supports two rewrite behaviors:

- `Preview before replacing`: show the rewrite first, then choose `Replace`, `Copy`, `Retry`, or `Dismiss`.
- `Replace instantly`: replace the selected text as soon as the provider returns.

The menu bar icon shows lightweight progress:

- `hourglass`: rewriting or replacing
- `checkmark.circle`: replaced successfully
- `exclamationmark.triangle`: failed

## Privacy

- Selected text is sent only to the provider you configure.
- Rewritr has no backend service.
- Rewritr has no accounts, analytics, or rewrite history in v1.
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

Open `Rewritr.xcodeproj` in Xcode and build the `Rewritr` scheme.

Build locally:

```sh
xcodebuild -project Rewritr.xcodeproj -scheme Rewritr -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/rewritr-dev-derived build CODE_SIGNING_ALLOWED=NO
```

Build tests:

```sh
xcodebuild -project Rewritr.xcodeproj -scheme Rewritr -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/rewritr-dev-derived build-for-testing CODE_SIGNING_ALLOWED=NO
```

Run tests:

```sh
xcodebuild -project Rewritr.xcodeproj -scheme Rewritr -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/rewritr-dev-derived test CODE_SIGNING_ALLOWED=NO
```

## Release

Releases are built by GitHub Actions when a `v*` tag is pushed, or manually through the `Release` workflow. The workflow packages `Rewritr.app` into a zip and attaches it to a GitHub Release with a SHA-256 checksum.
