# AGENTS.md

Guidance for coding agents working in this repository.

## Project Identity

Rewritr is a native macOS menu bar app for non-native English speakers who want selected English text rewritten into smoother, more natural, native-like English.

Keep the product intentionally narrow:

- Rewrite explicitly selected text in-place or through a preview popup.
- Preserve meaning and fix grammar.
- Avoid academic, thesis-style, overly formal, slangy, or filler-heavy English.
- Keep privacy central: no Rewritr backend, no analytics, no rewrite history.
- Use the user's configured OpenAI-compatible provider, including local providers.

Do not turn Rewritr into a general writing platform, document editor, prompt playground, browser extension, or input method.

## Repo Map

- `Rewritr/`: Swift app source.
- `RewritrTests/`: XCTest coverage for provider calls, settings, prompt behavior, shortcut persistence, pasteboard behavior, and preview model updates.
- `website/`: static GitHub Pages landing page.
- `assets/`: README/project assets.
- `.github/workflows/ci.yml`: macOS build and test workflow.
- `.github/workflows/release.yml`: unsigned Release build packaging workflow.
- `.github/workflows/deploy-website.yml`: GitHub Pages deployment.
- `README.md`: user-facing overview and install/use instructions.
- `CHANGELOG.md`: release notes.

Do not commit ignored local scratch files, build artifacts, screenshots-in-progress, or OS metadata. Historical planning files are not durable sources of truth for future work.

## Architecture Notes

The app is Swift/SwiftUI/AppKit with no third-party dependencies.

Key boundaries:

- `RewritrApp.swift` and `MenuBarApp.swift`: app lifecycle, menu bar UI, top-level windows.
- `SettingsView.swift`, `SettingsStore.swift`, `KeychainStore.swift`: provider settings, rewrite behavior, shortcut settings, Keychain storage.
- `ProviderClient.swift`: OpenAI-compatible Chat Completions HTTP client. The provider URL is used exactly as configured; do not append paths.
- `RewriteService.swift`: prompt construction, provider execution, length warnings.
- `RewriteCoordinator.swift`: selected-text capture, rewrite flow, preview/instant replacement behavior, HUD behavior.
- `ClipboardAutomator.swift`: macOS clipboard automation and pasteboard restore behavior.
- `RewritePreview.swift`: preview popup and floating HUD presentation.
- `ProductCopy.swift`: shared product positioning and compatibility wording.

Important behavior:

- Default shortcut is `Control+Option+R`.
- Rewrite behavior supports `Preview before replacing` and `Replace instantly`.
- Preview mode should focus the preview flow and should not show the floating status HUD on replace.
- Instant mode uses the floating HUD for rewrite/replacement status.
- API keys are optional. Local OpenAI-compatible providers may not need an API key.
- API keys are stored in macOS Keychain only after a successful provider test.
- Non-sensitive settings are stored in UserDefaults.

## Product and Privacy Guardrails

When changing user-facing copy or behavior:

- Target non-native English speakers writing everyday English.
- Keep wording plain, direct, and trust-building.
- Be explicit about restrictions: Rewritr works best where normal selection, `Command-C`, and `Command-V` work.
- Do not imply the app can reliably rewrite secure fields, terminals, remote desktops, virtual machines, browser-based IDEs, or custom editors.
- Do not add telemetry, accounts, hosted services, rewrite history, or server-side storage.
- Do not send anything except the explicitly selected text to the configured provider.
- Preserve the BYOK/local-model story.

## Development Commands

Build Debug:

```sh
xcodebuild -project Rewritr.xcodeproj -scheme Rewritr -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/rewritr-dev-derived build CODE_SIGNING_ALLOWED=NO
```

Run tests:

```sh
xcodebuild -project Rewritr.xcodeproj -scheme Rewritr -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/rewritr-dev-derived test CODE_SIGNING_ALLOWED=NO
```

Build Release locally:

```sh
xcodebuild -project Rewritr.xcodeproj -scheme Rewritr -configuration Release -destination 'platform=macOS' -derivedDataPath .build/rewritr-release-derived build CODE_SIGNING_ALLOWED=NO
```

Package local Release app:

```sh
ditto -c -k --keepParent .build/rewritr-release-derived/Build/Products/Release/Rewritr.app .build/Rewritr-local-release.zip
```

Static website preview:

```sh
open website/index.html
```

If using a local HTTP server, avoid assuming port `8000` is free.

## Verification Expectations

Before committing app changes:

- Run `git diff --check`.
- Run the XCTest command above.
- For release or packaging changes, run a local Release build.

Before committing website changes:

- Run `git diff --check`.
- Preview `website/index.html` locally.
- Check desktop and mobile layouts when changing CSS or page structure.
- Confirm no stale version-stage wording like `beta` or `v1` is introduced unless explicitly requested.

Before pushing:

- Confirm `git status --short --ignored` does not show unintended tracked changes.
- Keep ignored scratch files and build artifacts untracked.

## Release Notes and Packaging

The public release flow is handled by `.github/workflows/release.yml` when a `v*` tag is pushed or the workflow is manually dispatched.

Release builds are unsigned and not notarized because this project does not assume a paid Apple Developer account. User-facing install notes should say:

- Download the zip.
- Unzip it.
- Move `Rewritr.app` to a stable path such as `/Applications`.
- Grant Accessibility permission to that exact app bundle path.

macOS Accessibility permission is tied to the app bundle path. Moving the app after granting permission may require granting permission again.

## Collaboration Notes

The user prefers:

- Concrete local verification before commits and pushes.
- Narrow, implementable scope.
- Clear explanations of restrictions and tradeoffs.
- No accidental commits of planning scratch files.
- User preview before publishing visible website/product changes.

When unsure about product behavior, bias toward privacy, native macOS conventions, and a small focused workflow.
