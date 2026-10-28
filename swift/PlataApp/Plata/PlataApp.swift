import SwiftUI
import PlataCore

@main
struct PlataApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { model.refreshToday() }
                }
        }
    }
}
