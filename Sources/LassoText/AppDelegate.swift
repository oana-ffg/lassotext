import AppKit
import LassoCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences()
    private let recognizer = TextRecognizer()
    private let overlay = SelectionOverlay()
    private var shortcut: GlobalShortcut?
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var busy = false
    private var languages: [String] = []
    private var screenObserver: NSObjectProtocol?
    private var previousApp: NSRunningApplication?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        makeMenu()
        do {
            languages = try TextRecognizer.supportedLanguages().sorted {
                (Locale.current.localizedString(forIdentifier: $0) ?? $0)
                    .localizedStandardCompare(Locale.current.localizedString(forIdentifier: $1) ?? $1) == .orderedAscending
            }
            shortcut = try GlobalShortcut { [weak self] in self?.beginCapture() }
        } catch { showError(error) }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.overlay.cancel() } }
        if !UserDefaults.standard.bool(forKey: "hasOpened") {
            UserDefaults.standard.set(true, forKey: "hasOpened")
            showSettings()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        shortcut?.stop()
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    }

    private func makeMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "viewfinder", accessibilityDescription: "LassoText")
        statusItem.button?.toolTip = "LassoText · Control–Shift–2"
        let menu = NSMenu()
        let capture = menu.addItem(withTitle: "Capture Text    ⌃⇧2", action: #selector(captureFromMenu), keyEquivalent: "")
        capture.target = self
        menu.addItem(.separator())
        let settings = menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit LassoText", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    @objc private func captureFromMenu() {
        // Let the menu dismiss before freezing the display.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            self?.beginCapture()
        }
    }

    @objc private func showSettings() {
        if settingsWindow == nil {
            let view = SettingsView(preferences: preferences, languages: languages) { [weak self] in
                self?.settingsWindow?.orderOut(nil)
                self?.captureFromMenu()
            }
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "LassoText"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func beginCapture() {
        guard !busy else { return }
        if !CGPreflightScreenCaptureAccess() {
            let granted = CGRequestScreenCaptureAccess()
            if !granted {
                let alert = NSAlert()
                alert.messageText = "Allow LassoText to read your screen"
                alert.informativeText = "Enable LassoText in System Settings → Privacy & Security → Screen & System Audio Recording. If macOS asks, quit and reopen LassoText, then press Control–Shift–2. Captures stay on this Mac."
                alert.addButton(withTitle: "Open System Settings")
                alert.addButton(withTitle: "Later")
                NSApp.activate(ignoringOtherApps: true)
                if alert.runModal() == .alertFirstButtonReturn { openScreenRecordingSettings() }
                return
            }
        }
        busy = true
        previousApp = NSWorkspace.shared.frontmostApplication
        setStatus("Capturing…", symbol: "ellipsis.circle")
        Task { [self] in
            do {
                let displays = try await ScreenCapture.captureDisplays()
                overlay.show(displays) { [weak self] result in self?.selectionFinished(result) }
            } catch {
                busy = false
                setStatus("Capture failed", symbol: "exclamationmark.triangle")
                showError(error)
            }
        }
    }

    private func selectionFinished(_ result: Result<CGImage?, Error>) {
        previousApp?.activate()
        previousApp = nil
        switch result {
        case .failure(let error):
            busy = false
            setStatus("Capture failed", symbol: "exclamationmark.triangle")
            showError(error)
        case .success(nil):
            busy = false
            setStatus("Control–Shift–2", symbol: "viewfinder")
        case .success(let image?):
            setStatus("Reading text…", symbol: "ellipsis.circle")
            let language = preferences.language == "auto" ? nil : preferences.language
            let keepLineBreaks = preferences.keepLineBreaks
            Task {
                defer { busy = false }
                do {
                    let text = try await recognizer.recognize(image, language: language, keepLineBreaks: keepLineBreaks)
                    let item = NSPasteboardItem()
                    guard item.setString(text, forType: .string) else { throw ClipboardError.writeFailed }
                    NSPasteboard.general.clearContents()
                    guard NSPasteboard.general.writeObjects([item]) else { throw ClipboardError.writeFailed }
                    setStatus("Copied \(text.count) characters", symbol: "checkmark.viewfinder")
                    if preferences.playSound { NSSound(named: "Pop")?.play() }
                } catch {
                    setStatus("Recognition failed", symbol: "exclamationmark.triangle")
                    showError(error)
                }
            }
        }
    }

    private func setStatus(_ message: String, symbol: String) {
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: message)
        statusItem.button?.toolTip = "LassoText · \(message)"
    }

    private func showError(_ error: Error) {
        let alert = NSAlert(error: error)
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

private enum ClipboardError: LocalizedError {
    case writeFailed
    var errorDescription: String? { "macOS could not write the recognized text to the clipboard. Please try again." }
}
