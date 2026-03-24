import SwiftUI

@main
struct GHNCodeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var workspaceManager = WorkspaceManager()
    @StateObject private var activityDetector = ActivityDetector()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workspaceManager)
                .environmentObject(activityDetector)
                .preferredColorScheme(.dark)
                .onAppear {
                    guard !workspaceManager.hasInitialized else { return }
                    workspaceManager.hasInitialized = true

                    NSApp.appearance = NSAppearance(named: .darkAqua)
                    activityDetector.start(workspaceManager: workspaceManager)
                    PersistenceManager.shared.restore(into: workspaceManager)
                    // Autosave every 30 seconds
                    Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak workspaceManager] _ in
                        guard let manager = workspaceManager else { return }
                        Task { @MainActor in
                            PersistenceManager.shared.save(workspaceManager: manager)
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    PersistenceManager.shared.save(workspaceManager: workspaceManager)
                }
        }
        .commands {
            AppCommands(workspaceManager: workspaceManager)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}
