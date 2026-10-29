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
    @State private var footerGone = false
    @Environment(\.scenePhase) private var scenePhase

    init() { PlataFont.register() }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView().id(Tr.resolve(lang))
                if !showSplash { TourOverlay() }
                if showSplash {
                    SplashView(opening: opening, footerGone: footerGone).zIndex(1)
                }
            }
            .onAppear { AppLock.shared.attach() }
            .onChange(of: lang) { _, _ in WidgetBridge.shared.push() }
            .task {
                try? await Task.sleep(for: .seconds(0.9))
                footerGone = true
                try? await Task.sleep(for: .seconds(0.5))
                withAnimation(.easeInOut(duration: 0.75)) { opening = true }
                try? await Task.sleep(for: .seconds(0.85))
                showSplash = false
                model.splashDone = true
            }
            .environment(model)
                .environment(cloud)
                .task { cloud.attach(model); WatchBridge.shared.start(model); WidgetBridge.shared.start(model); Reminders.shared.attach(model) }
                .preferredColorScheme(Prefs.scheme(theme))
                .environment(\.locale, Prefs.locale(lang))
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { model.refreshToday(); AppLock.shared.sceneActive() }
                    else if phase == .inactive { AppLock.shared.sceneInactive() }
                    else if phase == .background { AppLock.shared.sceneBackground(); Reminders.shared.schedule() }
                    cloud.scene(active: phase == .active)
                }
        }
    }
}
