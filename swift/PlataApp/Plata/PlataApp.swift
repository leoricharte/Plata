import SwiftUI
import PlataCore

@main
struct PlataApp: App {
    @State private var model = AppModel()
    @State private var cloud = CloudModel()
    @AppStorage(Prefs.themeKey) private var theme = "auto"
    @AppStorage(Prefs.langKey) private var lang = "auto"
    @State private var showSplash = true
    @State private var opening = false
    @Environment(\.scenePhase) private var scenePhase

    init() { PlataFont.register() }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView().id(Tr.resolve(lang))
                if !showSplash { TourOverlay() }
                if showSplash {
                    SplashView(opening: opening).zIndex(1)
                }
            }
            .task {
                try? await Task.sleep(for: .seconds(1.0))
                withAnimation(.easeInOut(duration: 0.75)) { opening = true }
                try? await Task.sleep(for: .seconds(0.85))
                showSplash = false
            }
            .environment(model)
                .environment(cloud)
                .task { cloud.attach(model) }
                .preferredColorScheme(Prefs.scheme(theme))
                .environment(\.locale, Prefs.locale(lang))
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { model.refreshToday() }
                    cloud.scene(active: phase == .active)
                }
        }
    }
}
