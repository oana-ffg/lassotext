import AppKit
@testable import LassoMenuBar
import Testing

@Suite(.serialized)
@MainActor
struct MenuBarInteractionTests {
    @Test func panelTogglesAndLeavesOutsideClicksAlone() throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.finishLaunching()
        // A CLI test runner has no system menu-bar scene. Anchor the same real
        // popover and event routing to an ordinary AppKit window instead.
        let host = NSWindow(contentRect: NSRect(x: 50, y: 50, width: 260, height: 80),
                            styleMask: .titled, backing: .buffered, defer: false)
        host.isReleasedWhenClosed = false
        let anchorButton = NSButton(title: "LassoText", target: nil, action: nil)
        anchorButton.frame = NSRect(x: 20, y: 20, width: 90, height: 28)
        host.contentView?.addSubview(anchorButton)
        host.makeKeyAndOrderFront(nil)
        defer { host.close() }
        var errors: [String] = []
        var actionCount = 0
        let menu = MenuBarController(shortcut: "⌘ ⇧ 2", capture: { _ in actionCount += 1 },
                                     settings: { actionCount += 1 }, quit: { actionCount += 1 },
                                     reportError: { errors.append($0.localizedDescription) })
        defer { menu.stop() }

        menu.togglePanel(anchorButton)
        try waitForWindow(menu)
        try #require(menu.isShown)
        #expect(errors.isEmpty)
        #expect(actionCount == 0, "Opening the panel must never start screen capture")

        // A real second click arrives as mouse-down at the anchor, then its action.
        let anchor = try #require(menu.anchorView)
        let anchorWindow = try #require(anchor.window)
        let anchorCenter = anchor.convert(NSPoint(x: anchor.bounds.midX, y: anchor.bounds.midY), to: nil)
        let anchorPress = try #require(NSEvent.mouseEvent(
            with: .leftMouseDown, location: anchorCenter, modifierFlags: [], timestamp: 0,
            windowNumber: anchorWindow.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
        menu.handleGlobalEvent(anchorPress)
        #expect(menu.isShown, "An anchor press must not dismiss through either event route")
        #expect(menu.handleLocalEvent(anchorPress) === anchorPress)
        #expect(menu.isShown, "Mouse-down must not close then reopen the popover on mouse-up")
        menu.togglePanel(anchorButton)
        #expect(!menu.isShown)

        menu.togglePanel(anchorButton)
        try waitForWindow(menu)
        try #require(menu.isShown)
        let panelWindow = try #require(menu.panelWindow)
        let insidePress = try #require(NSEvent.mouseEvent(
            with: .leftMouseDown, location: NSPoint(x: 20, y: 20), modifierFlags: [], timestamp: 0,
            windowNumber: panelWindow.windowNumber, context: nil, eventNumber: 2, clickCount: 1, pressure: 1))
        #expect(menu.handleLocalEvent(insidePress) === insidePress)
        #expect(menu.isShown)

        let outside = NSWindow(contentRect: NSRect(x: 50, y: 50, width: 100, height: 100),
                               styleMask: .borderless, backing: .buffered, defer: false)
        outside.isReleasedWhenClosed = false
        defer { outside.close() }
        let outsidePress = try #require(NSEvent.mouseEvent(
            with: .leftMouseDown, location: NSPoint(x: 10, y: 10), modifierFlags: [], timestamp: 0,
            windowNumber: outside.windowNumber, context: nil, eventNumber: 3, clickCount: 1, pressure: 1))
        #expect(menu.handleLocalEvent(outsidePress) === outsidePress,
                "The original outside click must still reach its destination")
        #expect(!menu.isShown)

        menu.togglePanel(anchorButton)
        try waitForWindow(menu)
        try #require(menu.isShown)
        let escape = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: panelWindow.windowNumber, context: nil,
            characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53))
        #expect(menu.handleLocalEvent(escape) == nil)
        #expect(!menu.isShown)
        #expect(actionCount == 0)
        #expect(errors.isEmpty)

        menu.togglePanel(anchorButton)
        try waitForWindow(menu)
        menu.handleGlobalEvent(outsidePress)
        #expect(!menu.isShown)

        // A second click during presentation must cancel, not enqueue another show.
        menu.togglePanel(anchorButton)
        menu.togglePanel(anchorButton)
        _ = RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.05))
        #expect(!menu.isShown)
        #expect(menu.panelWindow?.isVisible != true)
    }

    private func waitForWindow(_ menu: MenuBarController) throws {
        let deadline = Date().addingTimeInterval(2)
        while menu.panelWindow?.isVisible != true, Date() < deadline {
            _ = RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
        try #require(menu.panelWindow?.isVisible == true, "The real popover must be visible")
        let window = try #require(menu.panelWindow)
        #expect(window.frame.width >= 260)
        #expect(window.frame.height >= 180, "All three action rows must fit in the panel")
    }

    @Test func iconUsesTheSystemTemplateColor() {
        let image = MenuBarIcon.makeImage()
        #expect(image.isTemplate)
        #expect(image.size == NSSize(width: 18, height: 18))
    }
}
