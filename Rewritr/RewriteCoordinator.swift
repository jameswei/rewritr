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
    private let logger = Logger(subsystem: "space.lifeplayer.rewritr", category: "rewrite")
    private var activeTask: Task<Void, Never>?
    private static let sourceActivationTimeout: TimeInterval = 1.5
    var activityHandler: ((RewriteActivityState) -> Void)?

    init(
        clipboardAutomator: ClipboardAutomator = ClipboardAutomator(),
        rewriteService: RewriteService = RewriteService(),
        previewPresenter: RewritePreviewPresenter = RewritePreviewPresenter()
    ) {
        self.clipboardAutomator = clipboardAutomator
        self.rewriteService = rewriteService
        self.previewPresenter = previewPresenter
    }

    func triggerRewrite() {
        activeTask?.cancel()
        previewPresenter.dismiss()
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
        } catch is CancellationError {
            logger.debug("Selection capture cancelled.")
            activityHandler?(.idle)
        } catch ClipboardAutomationError.emptySelection {
            logger.info("Rewrite trigger ignored because no selected text was captured.")
            activityHandler?(.failed("No selected text."))
            showEmptySelection()
        } catch {
            logger.error("Selection capture failed: \(error.localizedDescription, privacy: .public)")
            activityHandler?(.failed("Rewrite failed."))
            showError(error.localizedDescription)
        }
    }

    private func rewrite(capture: SelectedTextCapture, allowsLongRewrite: Bool = false) async {
        let behavior = rewriteService.rewriteBehavior()
        if behavior == .previewBeforeReplacing {
            showLoading(capture: capture)
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
                await replace(capture: capture, refinedText: result.refinedText)
            }
        } catch is CancellationError {
            logger.debug("Rewrite cancelled.")
            activityHandler?(.idle)
        } catch {
            logger.error("Rewrite failed: \(error.localizedDescription, privacy: .public)")
            activityHandler?(.failed("Rewrite failed."))
            showError(error.localizedDescription, retryCapture: capture)
        }
    }

    private func replace(capture: SelectedTextCapture, refinedText: String) async {
        do {
            previewPresenter.dismiss()
            activityHandler?(.working("Replacing selected text..."))
            try await activateSourceApp(for: capture)
            try await clipboardAutomator.pasteText(refinedText)
            activityHandler?(.succeeded("Rewrite replaced."))
        } catch {
            logger.error("Replacement paste failed: \(error.localizedDescription, privacy: .public)")
            clipboardAutomator.copyTextToClipboard(refinedText)
            activityHandler?(.failed("Could not replace text."))
            showError("Could not paste into the original app. The refined text was copied so you can paste it manually.", retryCapture: capture)
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

    private func showEmptySelection() {
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

    private func showError(_ message: String, retryCapture: SelectedTextCapture? = nil) {
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
                    await self?.replace(capture: capture, refinedText: refinedText)
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
}
