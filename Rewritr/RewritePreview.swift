import AppKit
import SwiftUI

enum RewritePreviewState: Equatable {
    case loading
    case result(text: String, isCopied: Bool)
    case emptySelection(String)
    case error(String)
}

@MainActor
final class RewritePreviewModel: ObservableObject {
    @Published var state: RewritePreviewState
    var actions: RewritePreviewActions

    init(
        state: RewritePreviewState = .loading,
        actions: RewritePreviewActions = .empty
    ) {
        self.state = state
        self.actions = actions
    }

    func update(state: RewritePreviewState, actions: RewritePreviewActions) {
        self.state = state
        self.actions = actions
    }
}

struct RewritePreviewActions {
    let replace: () -> Void
    let copy: () -> Void
    let retry: () -> Void
    let dismiss: () -> Void

    static var empty: RewritePreviewActions {
        RewritePreviewActions(
            replace: {},
            copy: {},
            retry: {},
            dismiss: {}
        )
    }
}

struct RewritePreviewView: View {
    @ObservedObject var model: RewritePreviewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
            Divider()
            controls
        }
        .padding(16)
        .frame(minWidth: 340, idealWidth: 440, maxWidth: 560)
        .onExitCommand {
            model.actions.dismiss()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("Rewriting...")
                    .font(.headline)
            }
        case .result(let text, let isCopied):
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Rewritten text", systemImage: "sparkles")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    if isCopied {
                        Spacer()
                        Label("Copied", systemImage: "checkmark.circle.fill")
                            .font(.callout)
                            .foregroundStyle(.green)
                    }
                }
                ScrollView {
                    Text(text)
                        .font(.title3)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(minHeight: 56, maxHeight: 280)
            }
        case .emptySelection(let message):
            Label(message, systemImage: "text.cursor")
                .font(.headline)
                .foregroundStyle(.secondary)
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var controls: some View {
        HStack {
            switch model.state {
            case .loading:
                Spacer()
                PreviewIconButton(
                    systemImage: "xmark",
                    accessibilityLabel: "Dismiss",
                    action: model.actions.dismiss
                )
                    .keyboardShortcut(.cancelAction)
            case .result:
                PreviewIconButton(
                    systemImage: "checkmark",
                    accessibilityLabel: "Replace",
                    action: model.actions.replace
                )
                    .keyboardShortcut(.defaultAction)
                PreviewIconButton(
                    systemImage: "doc.on.doc",
                    accessibilityLabel: "Copy",
                    action: model.actions.copy
                )
                PreviewIconButton(
                    systemImage: "arrow.clockwise",
                    accessibilityLabel: "Retry",
                    action: model.actions.retry
                )
                Spacer()
                PreviewIconButton(
                    systemImage: "xmark",
                    accessibilityLabel: "Dismiss",
                    action: model.actions.dismiss
                )
                .keyboardShortcut(.cancelAction)
            case .emptySelection, .error:
                PreviewIconButton(
                    systemImage: "arrow.clockwise",
                    accessibilityLabel: "Retry",
                    action: model.actions.retry
                )
                Spacer()
                PreviewIconButton(
                    systemImage: "xmark",
                    accessibilityLabel: "Dismiss",
                    action: model.actions.dismiss
                )
                    .keyboardShortcut(.cancelAction)
            }
        }
    }
}

private struct PreviewIconButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 22, height: 22)
        }
        .help(accessibilityLabel)
        .accessibilityLabel(accessibilityLabel)
    }
}

@MainActor
final class RewritePreviewPresenter {
    private var panel: NSPanel?
    private var model: RewritePreviewModel?

    func show(
        state: RewritePreviewState,
        anchor: CGRect? = nil,
        actions: RewritePreviewActions
    ) {
        if let model {
            model.update(state: state, actions: actions)
            panel?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let model = RewritePreviewModel(state: state, actions: actions)
        let rootView = RewritePreviewView(model: model)
        let hostingController = NSHostingController(rootView: rootView)
        let panel = NSPanel(contentViewController: hostingController)
        panel.title = "Rewritr"
        panel.styleMask = [.titled, .closable, .utilityWindow]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.setContentSize(size(for: state))
        if let anchor {
            placeNearSelection(anchor, panel: panel)
        } else {
            placeNearCursor(panel)
        }
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.model = model
        self.panel = panel
    }

    func update(_ state: RewritePreviewState) {
        model?.state = state
        if let panel {
            panel.setContentSize(size(for: state))
        }
    }

    func dismiss() {
        panel?.close()
        panel = nil
        model = nil
    }

    private func placeNearSelection(_ selectionBounds: CGRect, panel: NSPanel) {
        let screen = NSScreen.screens.first { screen in
            screen.visibleFrame.intersects(selectionBounds)
        } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let panelSize = panel.frame.size

        let preferredX = selectionBounds.minX
        let preferredY = selectionBounds.minY - 10
        let x = min(max(preferredX, visibleFrame.minX), visibleFrame.maxX - panelSize.width)
        let y = min(max(preferredY, visibleFrame.minY + panelSize.height), visibleFrame.maxY)
        panel.setFrameTopLeftPoint(NSPoint(x: x, y: y))
    }

    private func placeNearCursor(_ panel: NSPanel) {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { screen in
            screen.visibleFrame.contains(mouseLocation)
        } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let panelSize = panel.frame.size
        let x = min(max(mouseLocation.x, visibleFrame.minX), visibleFrame.maxX - panelSize.width)
        let y = min(max(mouseLocation.y, visibleFrame.minY + panelSize.height), visibleFrame.maxY)
        panel.setFrameTopLeftPoint(NSPoint(x: x, y: y))
    }

    private func size(for state: RewritePreviewState) -> NSSize {
        switch state {
        case .loading:
            return NSSize(width: 340, height: 130)
        case .emptySelection, .error:
            return NSSize(width: 420, height: 170)
        case .result(let text, _):
            let characterCount = text.count
            let width = min(560, max(360, 320 + characterCount / 8))
            let height = min(420, max(180, 150 + characterCount / 6))
            return NSSize(width: CGFloat(width), height: CGFloat(height))
        }
    }
}

enum RewriteStatusHUDState: Equatable {
    case rewriting
    case applyingRewrite
    case success
    case pasteFallback
    case genericFailure
    case noSelection
}

enum RewriteStatusHUDStyle: Int, CaseIterable {
    case classic = 0
    case minimalSystem = 1

    var displayName: String {
        switch self {
        case .classic:
            "Classic"
        case .minimalSystem:
            "Minimal"
        }
    }

    static func load(from defaults: UserDefaults = .standard) -> RewriteStatusHUDStyle {
        guard let rawValue = defaults.object(forKey: SettingsKey.rewriteStatusHUDStyle) as? Int else {
            return .minimalSystem
        }
        return RewriteStatusHUDStyle(rawValue: rawValue) ?? .minimalSystem
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: SettingsKey.rewriteStatusHUDStyle)
    }
}

enum RewriteStatusHUDIcon: Equatable {
    case working
    case success
    case failure
}

struct RewriteStatusHUDPresentation: Equatable {
    let message: String
    let icon: RewriteStatusHUDIcon
    let dismissDelayNanoseconds: UInt64?

    init(state: RewriteStatusHUDState, style: RewriteStatusHUDStyle) {
        message = Self.refinedMessage(for: state)

        switch state {
        case .rewriting, .applyingRewrite:
            icon = .working
            dismissDelayNanoseconds = nil
        case .success:
            icon = .success
            dismissDelayNanoseconds = 1_600_000_000
        case .pasteFallback, .genericFailure, .noSelection:
            icon = .failure
            dismissDelayNanoseconds = 3_000_000_000
        }
    }

    private static func refinedMessage(for state: RewriteStatusHUDState) -> String {
        switch state {
        case .rewriting:
            "Rewriting selected text..."
        case .applyingRewrite:
            "Applying rewrite..."
        case .success:
            "Rewrite applied"
        case .pasteFallback:
            "Couldn't replace. Copied for pasting."
        case .genericFailure:
            "Rewrite couldn't be completed"
        case .noSelection:
            "No text selected"
        }
    }
}

@MainActor
final class RewriteStatusHUDPresenter {
    private var panel: NSPanel?
    private var hostingController: NSHostingController<RewriteStatusHUDView>?
    private var dismissTask: Task<Void, Never>?
    private var displayedState: RewriteStatusHUDState?
    private var presentationGeneration = 0

    func show(_ state: RewriteStatusHUDState, anchor: CGRect? = nil) {
        dismissTask?.cancel()
        presentationGeneration &+= 1
        let generation = presentationGeneration
        displayedState = state
        let style = currentStyle
        if let panel, let hostingController {
            panel.alphaValue = 1
            hostingController.rootView = RewriteStatusHUDView(state: state, style: style)
            panel.setContentSize(size(for: state, style: style))
            place(panel: panel, anchor: anchor)
            panel.orderFrontRegardless()
            scheduleDismissIfNeeded(for: state, style: style, generation: generation)
            return
        }

        let hostingController = NSHostingController(rootView: RewriteStatusHUDView(state: state, style: style))
        let panel = NSPanel(contentViewController: hostingController)
        panel.styleMask = [.borderless, .nonactivatingPanel]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        panel.setContentSize(size(for: state, style: style))
        place(panel: panel, anchor: anchor)
        if style != .classic {
            panel.alphaValue = 0
        }
        panel.orderFrontRegardless()

        if style != .classic {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
        }

        self.panel = panel
        self.hostingController = hostingController
        scheduleDismissIfNeeded(for: state, style: style, generation: generation)
    }

    func dismiss() {
        dismissTask?.cancel()
        presentationGeneration &+= 1
        closePanel()
    }

    private var currentStyle: RewriteStatusHUDStyle {
        RewriteStatusHUDStyle.load()
    }

    private func closePanel() {
        panel?.close()
        panel = nil
        hostingController = nil
        displayedState = nil
    }

    private func scheduleDismissIfNeeded(
        for state: RewriteStatusHUDState,
        style: RewriteStatusHUDStyle,
        generation: Int
    ) {
        guard let delay = RewriteStatusHUDPresentation(state: state, style: style).dismissDelayNanoseconds else {
            return
        }

        dismissTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: delay)
            } catch {
                return
            }
            await MainActor.run {
                self?.dismissAfterPresentation(style: style, generation: generation)
            }
        }
    }

    private func dismissAfterPresentation(style: RewriteStatusHUDStyle, generation: Int) {
        guard presentationGeneration == generation, let panel else {
            return
        }
        dismissTask?.cancel()

        guard style != .classic else {
            closePanel()
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            Task { @MainActor in
                guard self?.presentationGeneration == generation else {
                    return
                }
                self?.closePanel()
            }
        }
    }

    private func size(for state: RewriteStatusHUDState, style: RewriteStatusHUDStyle) -> NSSize {
        switch style {
        case .classic:
            return NSSize(width: 240, height: 56)
        case .minimalSystem:
            let messageLength = RewriteStatusHUDPresentation(state: state, style: style).message.count
            let width = min(290, max(164, 72 + messageLength * 7))
            let height = messageLength > 31 ? 54 : 38
            return NSSize(width: CGFloat(width), height: CGFloat(height))
        }
    }

    private func place(panel: NSPanel, anchor: CGRect?) {
        if let anchor {
            placeNearSelection(anchor, panel: panel)
        } else {
            placeNearCursor(panel)
        }
    }

    private func placeNearSelection(_ selectionBounds: CGRect, panel: NSPanel) {
        let screen = NSScreen.screens.first { screen in
            screen.visibleFrame.intersects(selectionBounds)
        } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let panelSize = panel.frame.size
        let preferredX = selectionBounds.midX - panelSize.width / 2
        let preferredY = selectionBounds.maxY + panelSize.height + 12
        let x = min(max(preferredX, visibleFrame.minX), visibleFrame.maxX - panelSize.width)
        let y = min(max(preferredY, visibleFrame.minY + panelSize.height), visibleFrame.maxY)
        panel.setFrameTopLeftPoint(NSPoint(x: x, y: y))
    }

    private func placeNearCursor(_ panel: NSPanel) {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { screen in
            screen.visibleFrame.contains(mouseLocation)
        } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let panelSize = panel.frame.size
        let preferredX = mouseLocation.x - panelSize.width / 2
        let preferredY = mouseLocation.y + panelSize.height + 12
        let x = min(max(preferredX, visibleFrame.minX), visibleFrame.maxX - panelSize.width)
        let y = min(max(preferredY, visibleFrame.minY + panelSize.height), visibleFrame.maxY)
        panel.setFrameTopLeftPoint(NSPoint(x: x, y: y))
    }
}

struct RewriteStatusHUDView: View {
    let state: RewriteStatusHUDState
    let style: RewriteStatusHUDStyle

    var body: some View {
        switch style {
        case .classic:
            classicBody
        case .minimalSystem:
            minimalSystemBody
        }
    }

    private var classicBody: some View {
        HStack(spacing: 10) {
            icon
            Text(presentation.message)
                .font(.headline)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
        )
    }

    private var minimalSystemBody: some View {
        refinedContent(spacing: 8, font: .callout.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .shadow(color: Color.black.opacity(0.12), radius: 5, y: 1)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private func refinedContent(spacing: CGFloat, font: Font) -> some View {
        HStack(spacing: spacing) {
            icon
            Text(presentation.message)
                .font(font)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch presentation.icon {
        case .working:
            ProgressView()
                .controlSize(.small)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failure:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }

    private var presentation: RewriteStatusHUDPresentation {
        RewriteStatusHUDPresentation(state: state, style: style)
    }
}
