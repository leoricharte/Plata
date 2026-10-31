import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(CloudModel.self) private var cloud
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var model = model
        @Bindable var cloud = cloud
        // Barra de pestañas del sistema: en iOS 26 es Liquid Glass (lupa al arrastrar); en iOS 18 a 25, la clásica.
        TabView(selection: $model.tab) {
            Tab(value: AppTab.resumen) {
                ResumenView().toolbarVisibility(model.path.isEmpty ? .automatic : .hidden, for: .tabBar)
            } label: { Label("Resumen", systemImage: "chart.pie") }
            Tab(value: AppTab.presupuesto) { NavigationStack { PresupuestoView().routeDestinations() } } label: { Label("Presupuesto", systemImage: "wallet.bifold") }
            Tab(value: AppTab.proyeccion) { NavigationStack { ProyeccionView().routeDestinations() } } label: { Label("Proyección", systemImage: "chart.line.uptrend.xyaxis") }
            Tab(value: AppTab.ahorro) { NavigationStack { AhorroView().routeDestinations().navigationDestination(for: AcctRef.self) { AccountDetailView(id: $0.id).toolbarVisibility(.hidden, for: .tabBar) } } } label: { Label("Ahorro", systemImage: "dollarsign.gauge.chart.leftthird.topthird.rightthird") }
            Tab(value: AppTab.cuentas) { NavigationStack { CuentasView().routeDestinations().navigationDestination(for: AcctRef.self) { AccountDetailView(id: $0.id).toolbarVisibility(.hidden, for: .tabBar) } } } label: { Label("Cuentas", systemImage: "creditcard") }
        }
        .sheet(isPresented: $model.showAddTransaction, onDismiss: { model.addAccountPreset = nil }) { TransactionSheet(mode: .new, presetAccount: model.addAccountPreset) }
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
            case .review: ReviewView()
            case .confirm(let k, let i, let p): ConfirmSheet(kind: k, id: i, pick: p)
            }
        }
        .fullScreenCover(isPresented: $model.showWelcome) { WelcomeView().interactiveDismissDisabled() }
        .fullScreenCover(isPresented: $model.showNews) { NewsStoryView() }
        .fullScreenCover(isPresented: $model.showImport, onDismiss: { model.importAtCapture = false; model.handoff = nil }) { ImportFlowView(startAtCapture: model.importAtCapture, handoff: model.handoff) }
        .fullScreenCover(isPresented: $model.showInboxReview, onDismiss: { model.processConstanciaInbox() }) { ImportFlowView(preloaded: model.inboxReviews) }
        .onChange(of: scenePhase) { _, p in
            if p == .active { Task { while model.splashDone == false || AppLock.shared.locked { try? await Task.sleep(for: .milliseconds(100)) }; model.processConstanciaInbox(); model.processShareHandoff() } }
        }
        .sheet(isPresented: $model.showHistory) { HistorySheet() }
        .fullScreenCover(isPresented: Binding(get: { cloud.flow != nil && !model.showWelcome }, set: { if !$0 { cloud.flow = nil } })) { CloudFlowHost().interactiveDismissDisabled() }
        .alert("¿Cargar la copia local como la de la nube?", isPresented: $cloud.askLocalUp) {
            Button("Enviar código") { cloud.confirmLocalUp() }
            Button("No, seguir en modo local", role: .cancel) {}
        } message: { Text("Los datos de este dispositivo reemplazarán tu copia en la nube y en tus otros dispositivos. Primero te enviaremos un código de verificación a tu correo.") }
        .alert("Plata", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("Entendido", role: .cancel) {}
        } message: { Text(model.errorMessage ?? "") }
        .modifier(CloudNoticeOverlay())
        .feedbackAlert(isPresented: $model.showFeedback, manual: model.feedbackManual)
        .tint(Brand.accent)
        .task {
            // los avisos esperan a que termine el splash
            while !model.splashDone || AppLock.shared.locked { try? await Task.sleep(for: .milliseconds(100)) }
            model.processConstanciaInbox()
            model.processShareHandoff()
            model.checkPending()
            try? await Task.sleep(for: .milliseconds(700))
            if Nudges.shouldShowNews(model) { model.showNews = true }
            else if Nudges.shouldShowFeedback(model) {
                try? await Task.sleep(for: .milliseconds(1800))
                if model.activeSheet == nil { model.feedbackManual = false; model.showFeedback = true }
            }
        }
    }
}
