import AppKit
import Foundation
import os

@MainActor
final class RewriteCoordinator {
    private let clipboardAutomator: ClipboardAutomator
    private let rewriteService: RewriteService
    private let previewPresenter: RewritePreviewPresenter
    private let logger = Logger(subsystem: "space.lifeplayer.rewritr", category: "rewrite")
    private var activeTask: Task<Void, Never>?

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
            let capture = try await clipboardAutomator.captureSelectedText()
            logger.info("Captured selected text for rewrite. characters=\(capture.text.count, privacy: .public)")
            await rewrite(capture: capture)
        } catch is CancellationError {
            logger.debug("Selection capture cancelled.")
        } catch ClipboardAutomationError.emptySelection {
            logger.info("Rewrite trigger ignored because no selected text was captured.")
            showEmptySelection()
        } catch {
            logger.error("Selection capture failed: \(error.localizedDescription, privacy: .public)")
            showError(error.localizedDescription)
        }
    }

    private func rewrite(capture: SelectedTextCapture, allowsLongRewrite: Bool = false) async {
        let behavior = rewriteService.rewriteBehavior()
        showLoading(capture: capture)

        do {
            let result = try await rewriteService.rewrite(
                inputText: capture.text,
                allowsLongRewrite: allowsLongRewrite
            )
            logger.info("Rewrite completed. characters=\(result.refinedText.count, privacy: .public)")

            switch behavior {
            case .previewBeforeReplacing:
                showResult(capture: capture, refinedText: result.refinedText)
            case .replaceInstantly:
                await replace(capture: capture, refinedText: result.refinedText)
            }
        } catch is CancellationError {
            logger.debug("Rewrite cancelled.")
        } catch {
            logger.error("Rewrite failed: \(error.localizedDescription, privacy: .public)")
            showError(error.localizedDescription, retryCapture: capture)
        }
    }

    private func replace(capture: SelectedTextCapture, refinedText: String) async {
        do {
            activateSourceApp(for: capture)
            try await Task.sleep(nanoseconds: 80_000_000)
            try await clipboardAutomator.pasteText(refinedText)
            previewPresenter.dismiss()
        } catch {
            clipboardAutomator.copyTextToClipboard(refinedText)
            showError("Could not paste into the original app. The refined text was copied so you can paste it manually.", retryCapture: capture)
        }
    }

    private func showLoading(capture: SelectedTextCapture) {
        previewPresenter.show(
            state: .loading,
            actions: actions(for: capture, refinedText: nil)
        )
    }

    private func showResult(capture: SelectedTextCapture, refinedText: String) {
        previewPresenter.show(
            state: .result(refinedText),
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
                self.clipboardAutomator.copyTextToClipboard(refinedText)
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

    private func activateSourceApp(for capture: SelectedTextCapture) {
        guard
            let processIdentifier = capture.sourceProcessIdentifier,
            let app = NSRunningApplication(processIdentifier: processIdentifier)
        else {
            return
        }
        app.activate(options: [])
    }
}
