import SwiftUI
import PlataCore

@main
struct PlataApp: App {
    @State private var model = AppModel()
    @State private var showSplash = true
    @Environment(\.scenePhase) private var scenePhase

    init() { PlataFont.register() }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                if showSplash {
                    SplashView().transition(.opacity).zIndex(1)
                }
            }
            .task {
                try? await Task.sleep(for: .seconds(1.4))
                withAnimation(.easeOut(duration: 0.6)) { showSplash = false }
            }
            .environment(model)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { model.refreshToday() }
                }
        }
    }
}
