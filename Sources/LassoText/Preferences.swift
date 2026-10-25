import AppKit
import ServiceManagement
import SwiftUI

@MainActor
final class Preferences: ObservableObject {
    @Published var language: String { didSet { UserDefaults.standard.set(language, forKey: "language") } }
    @Published var keepLineBreaks: Bool { didSet { UserDefaults.standard.set(keepLineBreaks, forKey: "keepLineBreaks") } }
    @Published var playSound: Bool { didSet { UserDefaults.standard.set(playSound, forKey: "playSound") } }

    init() {
        UserDefaults.standard.register(defaults: ["language": "auto", "keepLineBreaks": true, "playSound": true])
        language = UserDefaults.standard.string(forKey: "language") ?? "auto"
        keepLineBreaks = UserDefaults.standard.bool(forKey: "keepLineBreaks")
        playSound = UserDefaults.standard.bool(forKey: "playSound")
    }
}

struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    let languages: [String]
    let capture: () -> Void
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "viewfinder")
                    .font(.system(size: 34, weight: .medium)).foregroundStyle(.teal)
                    .frame(width: 64, height: 64)
                    .background(.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 17))
                VStack(alignment: .leading, spacing: 5) {
                    Text("LassoText").font(.largeTitle.bold())
                    Text("Grab text. Get on with it.").foregroundStyle(.secondary)
                }
            }
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Your screen → your clipboard").font(.headline)
                    Text("Press the shortcut, then drag around any text.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Text("⌃ ⇧ 2").font(.system(.title3, design: .monospaced).weight(.semibold))
                    .padding(12).background(.quaternary, in: RoundedRectangle(cornerRadius: 9))
            }
            Form {
                Picker("Recognition language", selection: $preferences.language) {
                    Text("Automatic · all supported languages").tag("auto")
                    ForEach(languages, id: \.self) { language in
                        Text(Locale.current.localizedString(forIdentifier: language) ?? language).tag(language)
                    }
                }
                Toggle("Keep line breaks", isOn: $preferences.keepLineBreaks)
                Toggle("Play a sound after copying", isOn: $preferences.playSound)
                Toggle("Start at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled { try SMAppService.mainApp.register() }
                            else { try SMAppService.mainApp.unregister() }
                        } catch {
                            loginError = error.localizedDescription
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }.formStyle(.grouped).frame(height: 190)
            Text("Recognition runs entirely on your Mac. Captures are held in memory and discarded after recognition. Escape or right-click cancels.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Screen Recording Settings…") { openScreenRecordingSettings() }
                Spacer()
                Button("Capture Text", action: capture).buttonStyle(.borderedProminent).tint(.teal)
            }
        }
        .padding(28).frame(width: 560)
        .alert("Could not change login setting", isPresented: Binding(
            get: { loginError != nil }, set: { if !$0 { loginError = nil } }
        )) { Button("OK") { loginError = nil } } message: { Text(loginError ?? "") }
    }
}

@MainActor
func openScreenRecordingSettings() {
    guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
    NSWorkspace.shared.open(url)
}
