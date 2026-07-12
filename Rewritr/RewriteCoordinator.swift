import AppKit
import Foundation
import os

enum RewriteActivityState: Equatable {
    case idle
    case working(String)
    case succeeded(String)
    case failed(String)
}

@MainActor
final class RewriteCoordinator {
    private let clipboardAutomator: ClipboardAutomator
    private let rewriteService: RewriteService
    private let previewPresenter: RewritePreviewPresenter
    private let statusHUDPresenter: RewriteStatusHUDPresenter
    private let logger = Logger(subsystem: "space.lifeplayer.rewritr", category: "rewrite")
    private var activeTask: Task<Void, Never>?
    private static let sourceActivationTimeout: TimeInterval = 1.5
    var activityHandler: ((RewriteActivityState) -> Void)?

    init(
        clipboardAutomator: ClipboardAutomator = ClipboardAutomator(),
        rewriteService: RewriteService = RewriteService(),
        previewPresenter: RewritePreviewPresenter = RewritePreviewPresenter(),
        statusHUDPresenter: RewriteStatusHUDPresenter = RewriteStatusHUDPresenter()
    ) {
        self.clipboardAutomator = clipboardAutomator
        self.rewriteService = rewriteService
        self.previewPresenter = previewPresenter
        self.statusHUDPresenter = statusHUDPresenter
    }

    func triggerRewrite() {
        activeTask?.cancel()
        previewPresenter.dismiss()
        statusHUDPresenter.dismiss()
        activeTask = Task { [weak self] in
            guard let self else { return }
            await self.captureSelectionForRewrite()
        }
    }

    private func captureSelectionForRewrite() async {
        do {
            activityHandler?(.working("Capturing selected text..."))
            let capture = try await clipboardAutomator.captureSelectedText()
            logger.info("Captured selected text for rewrite. characters=\(capture.text.count, privacy: .public)")
            await rewrite(capture: capture)
        } catch where isCancellation(error) {
            logger.debug("Selection capture cancelled.")
            activityHandler?(.idle)
        } catch ClipboardAutomationError.emptySelection {
            logger.info("Rewrite trigger ignored because no selected text was captured.")
            activityHandler?(.failed("No selected text."))
            showEmptySelection(anchor: nil)
        } catch {
            logger.error("Selection capture failed: \(error.localizedDescription, privacy: .public)")
            activityHandler?(.failed("Rewrite failed."))
            showError(error.localizedDescription, anchor: nil)
        }
    }

    private func rewrite(capture: SelectedTextCapture, allowsLongRewrite: Bool = false) async {
        let behavior = rewriteService.rewriteBehavior()
        if behavior == .previewBeforeReplacing {
            showLoading(capture: capture)
        } else {
            statusHUDPresenter.show(.rewriting, anchor: capture.selectionBounds)
        }
        activityHandler?(.working("Rewriting selected text..."))

        do {
            let result = try await rewriteService.rewrite(
                inputText: capture.text,
                allowsLongRewrite: allowsLongRewrite
            )
            logger.info("Rewrite completed. characters=\(result.refinedText.count, privacy: .public)")

            switch behavior {
            case .previewBeforeReplacing:
                activityHandler?(.idle)
                showResult(capture: capture, refinedText: result.refinedText)
            case .replaceInstantly:
                await replace(capture: capture, refinedText: result.refinedText, showsHUD: true)
            }
        } catch where isCancellation(error) {
            logger.debug("Rewrite cancelled.")
            activityHandler?(.idle)
        } catch {
            logger.error("Rewrite failed: \(error.localizedDescription, privacy: .public)")
            activityHandler?(.failed("Rewrite failed."))
            showError(error.localizedDescription, retryCapture: capture, anchor: capture.selectionBounds)
        }
    }

    private func replace(capture: SelectedTextCapture, refinedText: String, showsHUD: Bool) async {
        do {
            previewPresenter.dismiss()
            activityHandler?(.working("Replacing selected text..."))
            if showsHUD {
                statusHUDPresenter.show(.applyingRewrite, anchor: capture.selectionBounds)
            }
            try await activateSourceApp(for: capture)
            try await clipboardAutomator.pasteText(refinedText)
            activityHandler?(.succeeded("Rewrite replaced."))
            if showsHUD {
                statusHUDPresenter.show(.success, anchor: capture.selectionBounds)
            }
        } catch {
            logger.error("Replacement paste failed: \(error.localizedDescription, privacy: .public)")
            clipboardAutomator.copyTextToClipboard(refinedText)
            activityHandler?(.failed("Could not replace text."))
            if showsHUD {
                statusHUDPresenter.show(.pasteFallback, anchor: capture.selectionBounds)
            } else {
                showError("Could not paste into the original app. The refined text was copied so you can paste it manually.", retryCapture: capture, anchor: capture.selectionBounds)
            }
        }
    }

    private func showLoading(capture: SelectedTextCapture) {
        previewPresenter.show(
            state: .loading,
            anchor: capture.selectionBounds,
            actions: actions(for: capture, refinedText: nil)
        )
    }

    private func showResult(capture: SelectedTextCapture, refinedText: String) {
        previewPresenter.show(
            state: .result(text: refinedText, isCopied: false),
            anchor: capture.selectionBounds,
            actions: actions(for: capture, refinedText: refinedText)
        )
    }

    private func showEmptySelection(anchor: CGRect?) {
        if rewriteService.rewriteBehavior() == .replaceInstantly {
            statusHUDPresenter.show(.noSelection, anchor: anchor)
            return
        }

        previewPresenter.show(
            state: .emptySelection(ClipboardAutomationError.emptySelection.localizedDescription),
            actions: RewritePreviewActions(
                replace: {},
                copy: {},
                retry: { [weak self] in self?.triggerRewrite() },
                dismiss: { [weak self] in self?.previewPresenter.dismiss() }
            )
        )
    }

    private func showError(_ message: String, retryCapture: SelectedTextCapture? = nil, anchor: CGRect? = nil) {
        if rewriteService.rewriteBehavior() == .replaceInstantly {
            statusHUDPresenter.show(.genericFailure, anchor: anchor)
            return
        }

        previewPresenter.show(
            state: .error(message),
            actions: RewritePreviewActions(
                replace: {},
                copy: {},
                retry: { [weak self] in
                    guard let self else { return }
                    if let retryCapture {
                        self.activeTask?.cancel()
                        self.activeTask = Task { [weak self] in
                            await self?.rewrite(capture: retryCapture)
                        }
                    } else {
                        self.triggerRewrite()
                    }
                },
                dismiss: { [weak self] in self?.previewPresenter.dismiss() }
            )
        )
    }

    private func actions(for capture: SelectedTextCapture, refinedText: String?) -> RewritePreviewActions {
        RewritePreviewActions(
            replace: { [weak self] in
                guard let self, let refinedText else { return }
                self.activeTask?.cancel()
                self.activeTask = Task { [weak self] in
                    await self?.replace(capture: capture, refinedText: refinedText, showsHUD: false)
                }
            },
            copy: { [weak self] in
                guard let self, let refinedText else { return }
                self.activeTask?.cancel()
                self.activeTask = Task { [weak self] in
                    await self?.copy(refinedText, retryCapture: capture)
                }
            },
            retry: { [weak self] in
                guard let self else { return }
                self.activeTask?.cancel()
                self.activeTask = Task { [weak self] in
                    await self?.rewrite(capture: capture)
                }
            },
            dismiss: { [weak self] in
                self?.activeTask?.cancel()
                self?.previewPresenter.dismiss()
            }
        )
    }

    private func copy(_ refinedText: String, retryCapture: SelectedTextCapture) async {
        guard clipboardAutomator.copyTextToClipboard(refinedText) else {
            showError(ClipboardAutomationError.clipboardWriteFailed.localizedDescription, retryCapture: retryCapture)
            return
        }

        do {
            try await Task.sleep(nanoseconds: 150_000_000)
        } catch {
            return
        }

        if clipboardAutomator.currentClipboardText() == refinedText {
            previewPresenter.update(.result(text: refinedText, isCopied: true))
        } else {
            showError("Rewritr tried to copy the rewrite, but another app changed the clipboard immediately after. Try Copy again, or paste manually from the visible rewrite text.", retryCapture: retryCapture)
        }
    }

    private func activateSourceApp(for capture: SelectedTextCapture) async throws {
        guard
            let processIdentifier = capture.sourceProcessIdentifier,
            let app = NSRunningApplication(processIdentifier: processIdentifier)
        else {
            throw ClipboardAutomationError.pasteTimedOut
        }

        app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])

        let deadline = Date().addingTimeInterval(Self.sourceActivationTimeout)
        while Date() < deadline {
            try Task.checkCancellation()
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == processIdentifier {
                try await Task.sleep(nanoseconds: 120_000_000)
                return
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        if let bundleIdentifier = capture.sourceBundleIdentifier, let bundleURL = app.bundleURL {
            NSWorkspace.shared.openApplication(
                at: bundleURL,
                configuration: NSWorkspace.OpenConfiguration()
            ) { _, _ in }
            let fallbackDeadline = Date().addingTimeInterval(0.5)
            while Date() < fallbackDeadline {
                try Task.checkCancellation()
                if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleIdentifier {
                    try await Task.sleep(nanoseconds: 120_000_000)
                    return
                }
                try await Task.sleep(nanoseconds: 20_000_000)
            }
        }

        throw ClipboardAutomationError.pasteTimedOut
    }

    private func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }

        return (error as NSError).code == NSUserCancelledError
    }
}
