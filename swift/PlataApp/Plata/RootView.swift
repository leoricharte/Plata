import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ZStack {
            switch model.tab {
            case .resumen: ResumenView()
            case .presupuesto: NavigationStack { PresupuestoView() }
            case .proyeccion: NavigationStack { ProyeccionView() }
            case .cuentas: NavigationStack { CuentasView() }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if model.path.isEmpty {
                PlataTabBar(tab: $model.tab) { model.showAddTransaction = true }
            }
        }
        // como la web: sobre una pantalla abierta (Movimientos, Ajustes…) se esconden las pestañas y queda solo el «+»
        .overlay(alignment: .bottomTrailing) {
            if !model.path.isEmpty {
                PlataTabBar(tab: $model.tab, showTabs: false) { model.showAddTransaction = true }
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.path.isEmpty)
        .sheet(isPresented: $model.showAddTransaction) { TransactionSheet(mode: .new) }
        .sheet(item: $model.activeSheet) { sheet in
            switch sheet {
            case .transfer: TransferSheet()
            case .expected(let kind, let id): ExpectedSheet(kind: kind, id: id)
            case .job(let id): JobSheet(id: id)
            }
        }
        .tint(Brand.accent)
    }
}
