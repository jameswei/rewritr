# Rewritr Taskboard

This board tracks implementation work for Rewritr v1. Keep it updated as each slice starts and closes.

## Status Legend

- `[ ]` Not started
- `[~]` In progress
- `[x]` Done
- `[!]` Blocked or needs decision

## Milestone 0: Repo And CI

- `[x]` Create native Xcode macOS app scaffold.
- `[x]` Configure app name `Rewritr`, bundle id `space.lifeplayer.rewritr`, macOS 15+ target, and no App Sandbox.
- `[x]` Add placeholder app and test targets.
- `[x]` Add GitHub Actions CI for app build and test-target build.
- `[x]` Verify CI succeeds on GitHub.

## Milestone 1: Native App Shell

- `[x]` Convert app to menu-bar utility with no Dock icon.
- `[x]` Add status item menu with `Settings`, `Privacy`, `Check Permissions`, and `Quit`.
- `[x]` Add shell settings window.
- `[x]` Add privacy window.
- `[x]` Add permissions window with Accessibility status and System Settings link.

## Milestone 2: Settings, Storage, And Provider Test

- `[x]` Add typed settings model for provider config, timeout, shortcut label, and rewrite behavior.
- `[x]` Store non-sensitive settings in UserDefaults.
- `[x]` Store API key in Keychain.
- `[x]` Add OpenAI-compatible Chat Completions provider client.
- `[x]` Add settings `Test` button using a tiny `OK` request.
- `[x]` Add validation and user-facing error states for missing/invalid provider settings.
- `[x]` Add unit tests for provider config URL normalization and validation.
- `[x]` Add unit tests for Chat Completions response/error parsing.

## Milestone 3: Shortcut And Clipboard Loop

- `[ ]` Register default global shortcut `Control+Option+R`.
- `[ ]` Add explicit selected-text capture through clipboard automation.
- `[ ]` Restore previous clipboard after capture.
- `[ ]` Handle empty selection without model calls.
- `[ ]` Implement repeated-trigger cancellation with latest trigger winning.

## Milestone 4: Rewrite Core

- `[ ]` Add rewrite prompt builder matching the natural, smooth, native-like rewrite contract.
- `[ ]` Add `RewriteRequest`, `RewriteMode`, `RewriteBehavior`, and `RewriteResult` flow types.
- `[ ]` Add fixed hidden temperature `0.2`.
- `[ ]` Add word counting and length-warning thresholds.
- `[ ]` Add timeout, network, provider, cancellation, and malformed-response handling.

## Milestone 5: Rewrite Commit UI

- `[ ]` Add preview popover near cursor.
- `[ ]` Show loading, result, timeout, error, and empty-selection states.
- `[ ]` Implement `Replace`, `Copy`, `Retry`, and `Esc` dismiss.
- `[ ]` Implement instant replacement mode.
- `[ ]` Restore clipboard after replacement where safe.
- `[ ]` Leave refined text copied and show an error if paste dispatch fails.

## Milestone 6: Product Polish And Docs

- `[ ]` Add first-run onboarding.
- `[ ]` Add compatibility/restrictions copy before first use and in discoverable help/privacy surfaces.
- `[ ]` Improve popover positioning and keyboard controls.
- `[ ]` Tune prompt with real non-native English examples.
- `[ ]` Expand README with usage, build, privacy, compatibility, and local development instructions.
- `[ ]` Consider optional macOS Service / Quick Action after shortcut flow is stable.

## Verification Policy

- Run `xcodebuild ... build CODE_SIGNING_ALLOWED=NO` before each implementation commit.
- Run `xcodebuild ... build-for-testing CODE_SIGNING_ALLOWED=NO` before each implementation commit.
- Run local unit tests outside the managed sandbox when runtime test execution needs `testmanagerd`.
- Keep `FINAL_PLAN.md` ignored and local-only.
