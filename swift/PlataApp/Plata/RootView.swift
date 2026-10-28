import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ZStack {
            switch model.tab {
            case .resumen: ResumenView()
            case .presupuesto: NavigationStack { ComingSoonView(title: "Presupuesto") }
            case .proyeccion: NavigationStack { ComingSoonView(title: "Proyección") }
            case .cuentas: NavigationStack { ComingSoonView(title: "Cuentas") }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // como la web: la barra se esconde cuando hay una pantalla abierta encima del Resumen
            if model.path.isEmpty {
                PlataTabBar(tab: $model.tab) { model.showAddTransaction = true }
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.path.isEmpty)
        .sheet(isPresented: $model.showAddTransaction) { TransactionSheet(mode: .new) }
        .tint(Brand.accent)
    }
}
