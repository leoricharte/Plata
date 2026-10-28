import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.tab) {
            Tab("Resumen", systemImage: "chart.pie.fill", value: AppTab.resumen) { ResumenView() }
            Tab("Presupuesto", systemImage: "wallet.bifold.fill", value: AppTab.presupuesto) {
                NavigationStack { ComingSoonView(title: "Presupuesto") }
            }
            Tab("Proyección", systemImage: "chart.line.uptrend.xyaxis", value: AppTab.proyeccion) {
                NavigationStack { ComingSoonView(title: "Proyección") }
            }
            Tab("Cuentas", systemImage: "creditcard.fill", value: AppTab.cuentas) {
                NavigationStack { ComingSoonView(title: "Cuentas") }
            }
        }
        .tint(Brand.accent)
    }
}
