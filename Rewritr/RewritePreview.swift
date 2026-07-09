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
        .frame(width: 440)
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
                    Text("Rewrite")
                        .font(.headline)
                    if isCopied {
                        Spacer()
                        Label("Copied", systemImage: "checkmark.circle.fill")
                            .font(.callout)
                            .foregroundStyle(.green)
                    }
                }
                ScrollView {
                    Text(text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(minHeight: 120, maxHeight: 220)
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
                Button("Dismiss", action: model.actions.dismiss)
                    .keyboardShortcut(.cancelAction)
            case .result:
                Button("Replace", action: model.actions.replace)
                    .keyboardShortcut(.defaultAction)
                Button("Copy", action: model.actions.copy)
                Button("Retry", action: model.actions.retry)
                Spacer()
                Button("Dismiss", action: model.actions.dismiss)
                    .keyboardShortcut(.cancelAction)
            case .emptySelection, .error:
                Button("Retry", action: model.actions.retry)
                Spacer()
                Button("Dismiss", action: model.actions.dismiss)
                    .keyboardShortcut(.cancelAction)
            }
        }
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
        panel.setContentSize(NSSize(width: 440, height: 260))
        if let anchor {
            placeNearSelection(anchor, panel: panel)
        } else {
            placeNearCursor(panel)
        }
        panel.makeKeyAndOrderFront(nil)

        self.model = model
        self.panel = panel
    }

    func update(_ state: RewritePreviewState) {
        model?.state = state
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
}
