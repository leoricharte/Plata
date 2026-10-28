import SwiftUI
import PlataCore

/// El tutorial guiado (`TOUR` / `tourTick` de la web): una tarjeta con una pista breve la primera vez que llegas a cada pantalla.
/// En la web también resalta el botón con un anillo; aquí la barra de pestañas es la del sistema y no se puede resaltar,
/// así que la pista se muestra sobre la barra, con el fondo atenuado.
private struct TourTip {
    let id: String
    let title: String
    let text: String
    /// Se marca como vista en cuanto aparece (no hace falta tocar «Entendido»).
    let auto: Bool
}

private enum TourStep {
    static let start = TourTip(id: "start", title: "Empieza por Cuentas", text: "Ahí pones tu saldo real, agregas tarjetas y puedes importar tus estados de cuenta.", auto: false)
    static let plus = TourTip(id: "plus", title: "Añade desde aquí", text: "Con el + registras un movimiento, algo previsto, una transferencia o tu trabajo.", auto: false)
    static let cuentas = TourTip(id: "deuda", title: "Tus cuentas", text: "Ajusta tu saldo real y añade tus cuentas, tarjetas y préstamos para que Plata cuadre tu mes.", auto: true)
    static let presupuesto = TourTip(id: "presu", title: "Presupuesto", text: "Pon un tope por categoría y mira cuánto llevas gastado este mes.", auto: true)
    static let proyeccion = TourTip(id: "proy", title: "Proyección", text: "Con lo que tienes previsto, aquí ves cómo irá tu saldo en las próximas semanas.", auto: true)
    static let gear = TourTip(id: "gear", title: "Ajustes", text: "Perfil, idioma, tema y respaldo de tus datos. Aquí también puedes repetir este tutorial.", auto: false)
}

extension AppModel {
    var tourOn: Bool { engine.data["settings"]?["tour"]?["on"] == .bool(true) }

    fileprivate func tourSeen(_ id: String) -> Bool { engine.data["settings"]?["tour"]?["seen"]?[id] != nil }

    fileprivate func tourMark(_ id: String) {
        var seen = engine.data["settings"]?["tour"]?["seen"] ?? .object([:])
        seen[id] = .number(1)
        setSetting("tour", .object(["on": .bool(true), "seen": seen]))
    }

    fileprivate func tourEnd() {
        let seen = engine.data["settings"]?["tour"]?["seen"] ?? .object([:])
        setSetting("tour", .object(["on": .bool(false), "seen": seen]))
    }
}

struct TourOverlay: View {
    @Environment(AppModel.self) private var model
    /// La pista que se está mostrando: se queda en pantalla aunque ya se haya marcado como vista.
    @State private var shown = ""

    private var free: Bool {
        model.activeSheet == nil && !model.showAddTransaction && !model.showNews && !model.showHistory
            && !model.showWelcome && !model.showFeedback
    }

    private var current: TourTip? {
        guard model.tourOn, !model.isDemo, free else { return nil }
        let candidates: [(TourTip, Bool)]
        switch model.tab {
        case .resumen:
            let root = model.path.isEmpty
            candidates = [(TourStep.start, root), (TourStep.plus, root), (TourStep.gear, root && model.tourSeen("plus"))]
        case .cuentas: candidates = [(TourStep.cuentas, true)]
        case .presupuesto: candidates = [(TourStep.presupuesto, true)]
        case .proyeccion: candidates = [(TourStep.proyeccion, true)]
        case .ahorro: candidates = []
        }
        for (tip, ok) in candidates where ok && (!model.tourSeen(tip.id) || tip.id == shown) { return tip }
        return nil
    }

    var body: some View {
        Group {
            if let tip = current {
                ZStack(alignment: .bottom) {
                    Color.black.opacity(0.26).ignoresSafeArea().allowsHitTesting(false)
                    card(tip)
                        .padding(.horizontal, 14).padding(.bottom, 110)
                        .transition(.opacity.combined(with: .offset(y: 6)))
                }
                .onAppear { show(tip) }
                .onChange(of: tip.id) { _, _ in show(tip) }
            }
        }
        .animation(.easeOut(duration: 0.22), value: current?.id)
    }

    private func show(_ tip: TourTip) {
        shown = tip.id
        if tip.auto && !model.tourSeen(tip.id) { model.tourMark(tip.id) }
    }

    private func card(_ tip: TourTip) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(tip.title).font(.inter(15.5, .bold)).padding(.bottom, 3)
            Text(tip.text).font(.inter(14)).lineSpacing(2)
            HStack(spacing: 8) {
                Button("Omitir tutorial") { shown = ""; model.tourEnd() }
                    .font(.inter(14, .medium)).foregroundStyle(.secondary)
                    .frame(minHeight: 40)
                Spacer(minLength: 0)
                Button("Entendido") {
                    let id = tip.id
                    shown = ""
                    if !model.tourSeen(id) { model.tourMark(id) }
                }
                .font(.inter(14, .semibold)).foregroundStyle(.white)
                .padding(.horizontal, 12).frame(minHeight: 40)
                .background(Brand.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.top, 8)
        }
        .padding(.top, 14).padding(.horizontal, 14).padding(.bottom, 8)
        .frame(maxWidth: 276, alignment: .leading)
        .background(Color(light: "#FFFFFF", dark: "#1C1C1E"), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Brand.accent.opacity(0.45), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.24), radius: 20, y: 12)
        .accessibilityElement(children: .contain)
    }
}
