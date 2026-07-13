# Rewritr

[![CI](https://github.com/jameswei/rewritr/actions/workflows/ci.yml/badge.svg)](https://github.com/jameswei/rewritr/actions/workflows/ci.yml)

Languages: English | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [日本語](README.ja.md)

<p align="center">
  <img src="assets/app-icon.png" width="96" alt="Rewritr app icon"/>
</p>

**Project site:** https://lifeplayer.space/rewritr/

> Rewritr comes from `Rewriter`, a real English word for someone who revises writing into a better form. The missing letter `e` keeps the name small, light, and a little playful, just like the app itself.

Rewritr is a privacy-first, native macOS menu bar app for non-native English speakers who want selected English to sound smoother, more natural, and more native-like.

It is intentionally small: select text in another app, trigger Rewritr, and replace the selected text with a clearer version. Rewritr preserves meaning and avoids academic, thesis-style, overly formal, slangy, or filler-heavy English.

## Screenshots

<table>
  <tr>
    <td><img src="assets/screenshot_settings.png" width="360" alt="Rewritr settings with provider configuration, rewrite behavior, HUD appearance, and shortcut"/></td>
    <td><img src="assets/screenshot_permissions.png" width="360" alt="Rewritr permission setup screen with Accessibility permission status"/></td>
  </tr>
  <tr>
    <td align="center"><em>Settings</em></td>
    <td align="center"><em>Permission setup</em></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><img src="assets/screenshot_privacy.png" width="520" alt="macOS Privacy and Security Accessibility permission screen for Rewritr"/></td>
  </tr>
  <tr>
    <td colspan="2" align="center"><em>macOS Accessibility permission</em></td>
  </tr>
</table>

## Download

Download the latest release from [GitHub Releases](https://github.com/jameswei/rewritr/releases).

The current release artifact is an unsigned macOS app zip. Because it is not signed or notarized by Apple, macOS may block it the first time you open it. Download only from this project's GitHub Releases page and verify the published SHA-256 checksum if you need to confirm the download.

After unzipping:

- Move `Rewritr.app` somewhere stable, such as `/Applications`.
- Try to open Rewritr. If macOS blocks it, open **System Settings > Privacy & Security**, scroll to **Security**, then click **Open Anyway** and confirm **Open**. This approval is needed only once for that app bundle.
- Grant Accessibility permission when prompted.
- Configure your OpenAI-compatible provider in Settings. Cloud providers usually require an API key; local OpenAI-compatible models may not.

macOS grants Accessibility permission to the exact app bundle path. If you move the app after granting permission, you may need to grant permission again.

## How It Works

1. Select English text in any editable app.
2. Press `Control+Option+R`.
3. Rewritr copies the selected text with macOS automation.
4. Rewritr sends it to your configured OpenAI-compatible Chat Completions provider.
5. Rewritr either previews the rewrite or replaces the selected text instantly.

Rewritr supports two rewrite behaviors:

- `Preview before replacing`: show the rewrite first, then choose `Replace`, `Copy`, `Retry`, or `Dismiss`.
- `Replace instantly`: replace the selected text as soon as the provider returns, with a small floating status HUD while Rewritr works.

The menu bar icon shows lightweight progress:

- `hourglass`: rewriting or replacing
- `checkmark.circle`: replaced successfully
- `exclamationmark.triangle`: failed

## Privacy

Your privacy matters, and it should stay in your hands. Rewritr has no backend service and stores no selected text, rewrite history, analytics, or account data.

- Only the text you explicitly select is sent, and only to the provider endpoint you configure.
- If you use a local OpenAI-compatible model, selected text can stay inside your own machine or network.
- Non-sensitive settings are stored in UserDefaults.
- Provider API keys, when needed, are stored locally in macOS Keychain after a successful provider test.
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

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release notes.

## Release

Releases are built by GitHub Actions when a `v*` tag is pushed, or manually through the `Release` workflow. The workflow packages `Rewritr.app` into a zip and attaches it to a GitHub Release with a SHA-256 checksum.
