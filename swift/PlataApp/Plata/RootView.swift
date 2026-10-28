import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    @State private var showAddMenu = false

    private enum TabSel: Hashable { case resumen, presupuesto, proyeccion, cuentas, add }

    var body: some View {
        @Bindable var model = model
        Group {
            if #available(iOS 26, *) { nativeTabs } else { legacyTabs }
        }
        .animation(.easeOut(duration: 0.2), value: model.path.isEmpty)
        .sheet(isPresented: $model.showAddTransaction) { TransactionSheet(mode: .new) }
        .sheet(item: $model.activeSheet) { sheet in
            switch sheet {
            case .transfer: TransferSheet()
            case .expected(let kind, let id): ExpectedSheet(kind: kind, id: id)
            case .job(let id): JobSheet(id: id)
            case .planned(let id): PlannedSheet(id: id)
            }
        }
        .sheet(isPresented: $showAddMenu) {
            AddMenuSheet { action in
                showAddMenu = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { action(self.model) }
            }
        }
        .tint(Brand.accent)
    }

    /// iOS 26+: la barra de pestañas del sistema (Liquid Glass de verdad: lupa al arrastrar, burbuja aparte para «+»).
    @available(iOS 26, *)
    private var nativeTabs: some View {
        let selection = Binding<TabSel>(
            get: {
                switch model.tab {
                case .resumen: return .resumen
                case .presupuesto: return .presupuesto
                case .proyeccion: return .proyeccion
                case .cuentas: return .cuentas
                }
            },
            set: { new in
                switch new {
                case .resumen: model.tab = .resumen
                case .presupuesto: model.tab = .presupuesto
                case .proyeccion: model.tab = .proyeccion
                case .cuentas: model.tab = .cuentas
                case .add: showAddMenu = true   // no cambia de pestaña: la burbuja «+» solo abre el menú
                }
            }
        )
        return TabView(selection: selection) {
            Tab("Resumen", systemImage: "chart.pie", value: TabSel.resumen) {
                ResumenView().toolbarVisibility(model.path.isEmpty ? .automatic : .hidden, for: .tabBar)
            }
            Tab("Presupuesto", systemImage: "wallet.bifold", value: TabSel.presupuesto) { NavigationStack { PresupuestoView() } }
            Tab("Proyección", systemImage: "chart.line.uptrend.xyaxis", value: TabSel.proyeccion) { NavigationStack { ProyeccionView() } }
            Tab("Cuentas", systemImage: "creditcard", value: TabSel.cuentas) { NavigationStack { CuentasView() } }
            Tab("Añadir", systemImage: "plus", value: TabSel.add, role: .search) { Color.clear }
        }
        // sobre una pantalla abierta (Movimientos, Ajustes…) se esconden las pestañas y queda solo el «+»
        .overlay(alignment: .bottomTrailing) {
            if !model.path.isEmpty {
                PlataTabBar(tab: Bindable(model).tab, showTabs: false) { model.showAddTransaction = true }
            }
        }
    }

    /// iOS 18 a 25: la barra propia con la forma de la web.
    private var legacyTabs: some View {
        @Bindable var model = model
        return ZStack {
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
    }
}

/// Lo que abre el «+» en la barra del sistema: las mismas opciones del menú de la web.
struct AddMenuSheet: View {
    var pick: (@escaping (AppModel) -> Void) -> Void

    private struct Item: Identifiable {
        let id: String
        let symbol: String
        let title: LocalizedStringKey
        let sub: LocalizedStringKey
        let action: (AppModel) -> Void
    }

    private let items: [Item] = [
        Item(id: "tx", symbol: "plus.circle", title: "Movimiento", sub: "Registra algo que ya pasó") { $0.showAddTransaction = true },
        Item(id: "inc", symbol: "building.columns", title: "Ingreso previsto", sub: "Sueldo, proyecto, pago esperado") { $0.activeSheet = .expected(kind: "income", id: nil) },
        Item(id: "exp", symbol: "creditcard", title: "Gasto previsto", sub: "Alquiler, recibo, compra futura") { $0.activeSheet = .expected(kind: "expense", id: nil) },
        Item(id: "xfer", symbol: "arrow.left.arrow.right", title: "Transferir", sub: "Entre tus cuentas") { $0.activeSheet = .transfer },
        Item(id: "job", symbol: "banknote", title: "Trabajo", sub: "Pago por hora, impuestos, frecuencia") { $0.activeSheet = .job(id: nil) },
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { i, it in
                if i > 0 { Divider().padding(.leading, 64) }
                Button { pick(it.action) } label: {
                    HStack(spacing: 14) {
                        Image(systemName: it.symbol).font(.system(size: 20)).foregroundStyle(Brand.accent).frame(width: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(it.title).font(.inter(17, .semibold)).foregroundStyle(.primary)
                            Text(it.sub).font(.inter(13)).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 24)
        .presentationDetents([.height(400)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(light: "#F4F4F8", dark: "#1C1C1E"))
    }
}
