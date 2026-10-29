import SwiftUI
import AppKit

@main
struct GuitarJimApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel()
    var body: some Scene {
        WindowGroup("Guitar Jim") {
            RootView(model: model)
                .frame(minWidth: 1000, minHeight: 740)
                .onAppear { delegate.model = model }
        }
        .defaultSize(width: 1280, height: 850)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Import chart…") { model.showImporter = true }.keyboardShortcut("i", modifiers: .command)
            }
            CommandMenu("Practice") {
                Button("Start / pause practice") { model.toggleTransport() }.keyboardShortcut(.space, modifiers: [])
                Button("Turn mic off and save") { Task { await model.stopMic() } }.keyboardShortcut("s", modifiers: [.command, .shift])
                    .disabled(!model.isRecording)
            }
        }
        Settings { IntegrationSettingsView().frame(width: 560).preferredColorScheme(.dark) }
        MenuBarExtra {
            Text(model.isRecording ? "Recording · \(formatTime(model.recordingSeconds))" : "Microphone off")
            if model.isRecording {
                Button("Turn mic off and save") { Task { await model.stopMic() } }
            }
            Button("Show Guitar Jim") { NSApp.activate(ignoringOtherApps: true); NSApp.windows.first?.makeKeyAndOrderFront(nil) }
        } label: {
            Label {
                Text(model.isRecording ? "Recording" : "Guitar Jim")
            } icon: {
                Image(nsImage: model.isRecording ? AppResources.recordingMenuBarIcon : AppResources.menuBarIcon)
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: AppModel?
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model, model.isRecording else { return .terminateNow }
        Task { await model.stopMic(); sender.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.applicationIconImage = AppResources.appIcon
    }
}

func formatTime(_ seconds: Double) -> String {
    let seconds = Int(max(0, seconds)); return String(format: "%02d:%02d", seconds / 60, seconds % 60)
}
