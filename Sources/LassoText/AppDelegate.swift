import AppKit
import LassoCore
import LassoMenuBar
import ScreenCaptureKit
import OSLog
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences()
    private let recognizer = TextRecognizer()
    private let overlay = SelectionOverlay()
    private var shortcut: GlobalShortcut?
    private var menuBar: MenuBarController!
    private let logger = Logger(subsystem: "io.github.oana-ffg.LassoText", category: "Workflow")
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
        } catch { showError(error) }
        do {
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

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !busy, !menuBar.isShown else { return false }
        showSettings()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        shortcut?.stop()
        menuBar.stop()
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    }

    private func makeMenu() {
        menuBar = MenuBarController(
            shortcut: CaptureShortcut.symbols,
            capture: { [weak self] previous in self?.beginCapture(returningTo: previous) },
            settings: { [weak self] in self?.showSettings() },
            quit: { NSApp.terminate(nil) },
            reportError: { [weak self] error in self?.showError(error) }
        )
    }

    private func showSettings() {
        if settingsWindow == nil {
            let view = SettingsView(preferences: preferences, languages: languages) { [weak self] in
                self?.settingsWindow?.orderOut(nil)
                self?.beginCapture()
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

    private func beginCapture(returningTo application: NSRunningApplication? = nil) {
        logger.notice("Capture requested; busy: \(self.busy)")
        guard !busy else { return }
        let menuApplication = menuBar.close()
        busy = true
        previousApp = application ?? menuApplication ?? NSWorkspace.shared.frontmostApplication
        setStatus("Capturing…")
        Task { [self] in
            do {
                let displays = try await ScreenCapture.captureDisplays()
                logger.notice("Captured \(displays.count) displays; waiting for selection")
                setStatus("Drag an area")
                overlay.show(displays) { [weak self] result in self?.selectionFinished(result) }
            } catch {
                busy = false
                setStatus("Capture failed")
                let captureError = error as NSError
                if captureError.domain == SCStreamError.errorDomain,
                   captureError.code == SCStreamError.Code.userDeclined.rawValue {
                    showScreenPermissionHelp()
                } else {
                    showError(error)
                }
            }
        }
    }

    private func selectionFinished(_ result: Result<CGImage?, Error>) {
        logger.notice("Selection completed")
        previousApp?.activate()
        previousApp = nil
        switch result {
        case .failure(let error):
            busy = false
            setStatus("Capture failed")
            showError(error)
        case .success(nil):
            busy = false
            setStatus(CaptureShortcut.label)
        case .success(let image?):
            setStatus("Reading text…")
            let language = preferences.language == "auto" ? nil : preferences.language
            let keepLineBreaks = preferences.keepLineBreaks
            Task {
                defer {
                    busy = false
                    logger.notice("Recognition finished; capture ready again")
                }
                do {
                    let text = try await recognizer.recognize(image, language: language, keepLineBreaks: keepLineBreaks)
                    let item = NSPasteboardItem()
                    guard item.setString(text, forType: .string) else { throw ClipboardError.writeFailed }
                    NSPasteboard.general.clearContents()
                    guard NSPasteboard.general.writeObjects([item]) else { throw ClipboardError.writeFailed }
                    logger.notice("Copied \(text.count) characters")
                    setStatus("Copied \(text.count) characters")
                    if preferences.playSound { NSSound(named: "Pop")?.play() }
                } catch {
                    setStatus("Recognition failed")
                    showError(error)
                }
            }
        }
    }

    private func setStatus(_ message: String) {
        menuBar.setStatus(message)
    }

    private func showScreenPermissionHelp() {
        let alert = NSAlert()
        alert.messageText = "Allow LassoText to read your screen"
        alert.informativeText = "Enable LassoText in System Settings → Privacy & Security → Screen & System Audio Recording. If macOS asks, quit and reopen LassoText, then press \(CaptureShortcut.label). Captures stay on this Mac."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn { openScreenRecordingSettings() }
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
