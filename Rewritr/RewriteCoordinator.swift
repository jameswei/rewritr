import Foundation
import os

@MainActor
final class RewriteCoordinator {
    private let clipboardAutomator: ClipboardAutomator
    private let rewriteService: RewriteService
    private let logger = Logger(subsystem: "space.lifeplayer.rewritr", category: "rewrite")
    private var activeTask: Task<Void, Never>?

    init(
        clipboardAutomator: ClipboardAutomator = ClipboardAutomator(),
        rewriteService: RewriteService = RewriteService()
    ) {
        self.clipboardAutomator = clipboardAutomator
        self.rewriteService = rewriteService
    }

    func triggerRewrite() {
        activeTask?.cancel()
        activeTask = Task { [weak self] in
            guard let self else { return }
            await self.captureSelectionForRewrite()
        }
    }

    private func captureSelectionForRewrite() async {
        do {
            let capture = try await clipboardAutomator.captureSelectedText()
            logger.info("Captured selected text for rewrite. characters=\(capture.text.count, privacy: .public)")
            let result = try await rewriteService.rewrite(inputText: capture.text)
            logger.info("Rewrite completed. characters=\(result.refinedText.count, privacy: .public)")
        } catch is CancellationError {
            logger.debug("Selection capture cancelled.")
        } catch ClipboardAutomationError.emptySelection {
            logger.info("Rewrite trigger ignored because no selected text was captured.")
        } catch {
            logger.error("Selection capture failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
