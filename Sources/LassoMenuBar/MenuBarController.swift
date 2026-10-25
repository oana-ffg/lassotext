import AppKit
import SwiftUI

/// A nonmodal status panel. Mouse events outside it are observed, never consumed.
@MainActor
public final class MenuBarController: NSObject, NSPopoverDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private let state = MenuBarState()
    private let reportError: (Error) -> Void
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var resignObserver: NSObjectProtocol?
    private var previousApplication: NSRunningApplication?
    private var opening = false
    private weak var positioningView: NSView?

    public var isShown: Bool { opening || popover.isShown }

    public init(shortcut: String, capture: @escaping (NSRunningApplication?) -> Void,
                settings: @escaping () -> Void, quit: @escaping () -> Void,
                reportError: @escaping (Error) -> Void) {
        self.reportError = reportError
        super.init()
        popover.behavior = .applicationDefined
        popover.animates = false
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: MenuBarView(
            state: state, shortcut: shortcut,
            capture: { [weak self] in capture(self?.close()) },
            settings: { [weak self] in self?.close(); settings() },
            quit: { [weak self] in self?.close(); quit() }
        ))
        if let button = item.button {
            button.image = MenuBarIcon.makeImage()
            button.setAccessibilityLabel("LassoText")
            button.toolTip = "LassoText · \(shortcut)"
            button.target = self
            button.action = #selector(togglePanel(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    public func setStatus(_ message: String) {
        state.message = message
        item.button?.toolTip = "LassoText · \(message)"
    }

    @objc func togglePanel(_ sender: Any?) {
        if isShown {
            close()?.activate()
            return
        }
        guard let button = (sender as? NSView) ?? item.button else { return }
        positioningView = button
        previousApplication = NSWorkspace.shared.frontmostApplication
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            let consumed = MainActor.assumeIsolated {
                guard let self else { return false }
                return self.handleLocalEvent(event) == nil
            }
            return consumed ? nil : event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            MainActor.assumeIsolated {
                if let self { self.handleGlobalEvent(event) }
            }
        }
        guard localMonitor != nil, globalMonitor != nil else {
            removeMonitors()
            previousApplication = nil
            reportError(MenuBarError.monitorUnavailable)
            return
        }
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: NSApp, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { _ = self?.close() } }
        opening = true
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
        popover.contentViewController?.view.window?.makeKey()
    }

    /// Returning the original foreground app lets capture restore focus afterward.
    @discardableResult
    public func close() -> NSRunningApplication? {
        let previous = previousApplication
        previousApplication = nil
        opening = false
        popover.close()
        removeMonitors()
        return previous
    }

    public func stop() {
        close()
        NSStatusBar.system.removeStatusItem(item)
    }

    public func popoverDidShow(_ notification: Notification) {
        opening = false
    }

    public func popoverDidClose(_ notification: Notification) {
        opening = false
        previousApplication = nil
        removeMonitors()
    }

    func handleLocalEvent(_ event: NSEvent) -> NSEvent? {
        guard isShown else { return event }
        if event.type == .keyDown {
            if event.keyCode == 53 {
                close()?.activate()
                return nil
            }
            return event
        }
        // Leave the anchor press alone. Its mouse-up action closes the shown panel.
        // Closing here first would cause that same mouse-up to reopen it.
        if isAnchorEvent(event) || event.window === panelWindow {
            return event
        }
        close()
        return event
    }

    func handleGlobalEvent(_ event: NSEvent) {
        guard isShown, !isAnchorEvent(event) else { return }
        close()
    }

    var panelWindow: NSWindow? { popover.contentViewController?.view.window }
    var anchorView: NSView? { positioningView ?? item.button }

    private func isAnchorEvent(_ event: NSEvent) -> Bool {
        guard let button = anchorView, let window = button.window else { return false }
        let point = event.window.map { $0.convertPoint(toScreen: event.locationInWindow) } ?? NSEvent.mouseLocation
        let frame = window.convertToScreen(button.convert(button.bounds, to: nil))
        return frame.contains(point)
    }

    private func removeMonitors() {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        localMonitor = nil
        globalMonitor = nil
        resignObserver = nil
    }
}

private enum MenuBarError: LocalizedError {
    case monitorUnavailable
    var errorDescription: String? {
        "LassoText could not open its menu-bar panel. Please quit and reopen LassoText."
    }
}

@MainActor
private final class MenuBarState: ObservableObject {
    @Published var message = "Ready to capture"
}

private struct MenuBarView: View {
    @ObservedObject var state: MenuBarState
    let shortcut: String
    let capture: () -> Void
    let settings: () -> Void
    let quit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 10) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
                    .resizable().interpolation(.high).frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("LassoText").font(.system(size: 13, weight: .semibold))
                    Text(state.message).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }.padding(.horizontal, 9).padding(.vertical, 8)
            Divider()
            PanelButton(title: "Capture Text", symbol: "text.viewfinder", shortcut: shortcut, action: capture)
            PanelButton(title: "Settings…", symbol: "gearshape", shortcut: "⌘ ,", action: settings)
                .keyboardShortcut(",", modifiers: .command)
            Divider()
            PanelButton(title: "Quit LassoText", symbol: "power", shortcut: "⌘ Q", action: quit)
                .keyboardShortcut("q", modifiers: .command)
        }
        .padding(8).frame(width: 260)
    }
}

private struct PanelButton: View {
    let title: String
    let symbol: String
    let shortcut: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol).frame(width: 18)
                Text(title)
                Spacer()
                Text(shortcut).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .font(.system(size: 13)).padding(.horizontal, 9).frame(height: 32)
            .contentShape(Rectangle())
            .background(hovering ? Color.primary.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain).onHover { hovering = $0 }
    }
}
