import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        // Barra de pestañas del sistema: en iOS 26 es Liquid Glass (lupa al arrastrar); en iOS 18 a 25, la clásica.
        TabView(selection: $model.tab) {
            Tab("Resumen", systemImage: "chart.pie", value: AppTab.resumen) {
                ResumenView().toolbarVisibility(model.path.isEmpty ? .automatic : .hidden, for: .tabBar)
            }
            Tab("Presupuesto", systemImage: "wallet.bifold", value: AppTab.presupuesto) { NavigationStack { PresupuestoView() } }
            Tab("Proyección", systemImage: "chart.line.uptrend.xyaxis", value: AppTab.proyeccion) { NavigationStack { ProyeccionView() } }
            Tab("Ahorro", systemImage: "leaf", value: AppTab.ahorro) { NavigationStack { AhorroView() } }
            Tab("Cuentas", systemImage: "creditcard", value: AppTab.cuentas) { NavigationStack { CuentasView() } }
        }
        .sheet(isPresented: $model.showAddTransaction) { TransactionSheet(mode: .new) }
        .sheet(item: $model.activeSheet) { sheet in
            switch sheet {
            case .transfer: TransferSheet()
            case .expected(let kind, let id): ExpectedSheet(kind: kind, id: id)
            case .job(let id): JobSheet(id: id)
            case .planned(let id): PlannedSheet(id: id)
            case .saving(let id): SavingSheet(id: id)
            case .contrib: ContribSheet()
            case .account(let id): AccountSheet(id: id)
            case .debt(let id): DebtSheet(id: id)
            case .sub(let id): SubSheet(id: id)
            case .category(let n): CategorySheet(name: n)
            case .event(let k): EventSheet(key: k)
            case .budgetSets: BudgetSetsSheet()
            }
        }
        .tint(Brand.accent)
    }
}
