import Carbon
import Foundation
import OSLog

enum CaptureShortcut {
    static let keyCode = UInt32(kVK_ANSI_2)
    static let modifiers = UInt32(cmdKey | shiftKey)
    static let label = "Command–Shift–2"
    static let symbols = "⌘ ⇧ 2"
}

@MainActor
final class GlobalShortcut {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void
    private let logger = Logger(subsystem: "io.github.oana-ffg.LassoText", category: "Shortcut")

    init(action: @escaping () -> Void) throws {
        self.action = action
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context, let event else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                          EventParamType(typeEventHotKeyID), nil,
                                          MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard status == noErr, identifier.signature == 0x4C415353, identifier.id == 1 else {
                return OSStatus(eventNotHandledErr)
            }
            MainActor.assumeIsolated {
                let shortcut = Unmanaged<GlobalShortcut>.fromOpaque(context).takeUnretainedValue()
                shortcut.logger.notice("Capture shortcut received")
                shortcut.action()
            }
            return noErr
        }, 1, &event, context, &handler)
        guard installStatus == noErr else { throw ShortcutError.status(installStatus) }
        let status = RegisterEventHotKey(CaptureShortcut.keyCode, CaptureShortcut.modifiers,
                                        EventHotKeyID(signature: 0x4C415353, id: 1),
                                        GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &hotKey)
        logger.notice("Registered \(CaptureShortcut.label, privacy: .public); status: \(status)")
        guard status == noErr else {
            if let handler { RemoveEventHandler(handler) }
            handler = nil
            throw ShortcutError.status(status)
        }
    }

    func stop() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
        hotKey = nil
        handler = nil
    }
}

private enum ShortcutError: LocalizedError {
    case status(OSStatus)
    var errorDescription: String? {
        "Could not register \(CaptureShortcut.label) (error \(code)). Another app may be using it. You can still capture from the menu bar."
    }
    private var code: OSStatus { switch self { case .status(let value): value } }
}
