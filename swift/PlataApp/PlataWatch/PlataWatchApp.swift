import SwiftUI

@main
struct PlataWatchApp: App {
    @State private var store = WatchStore()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootPages()
                .environment(store)
                .tint(WatchTheme.accent)
                .onChange(of: phase) { _, p in if p != .active { store.flushPending() } }
        }
    }
}

enum WatchTheme {
    /// El verde Plata (el mismo acento de la app).
    static let accent = Color(red: 0.133, green: 0.710, blue: 0.451)
}
