import SwiftUI
import PlataCore

/// El tutorial guiado (`TOUR` / `tourTick` de la web): una pista breve la primera vez que llegas a cada pantalla.
/// Igual que la web: el fondo se atenúa con un hueco y un anillo sobre el botón que explica (el hueco deja pulsarlo).
/// Los botones se miden con `tourAnchor`; la barra de pestañas es la del sistema y no se puede medir, así que
/// ahí la tarjeta queda sobre la barra con una flecha hacia la pestaña (por su posición, 1/5 del ancho cada una).
private struct TourTip {
    let id: String
    let title: String
    let text: String
    /// Se marca como vista en cuanto aparece (no hace falta tocar «Entendido»).
    let auto: Bool
    /// Botón que se resalta (`tourAnchor`); si no está en pantalla, la pista se salta, como en la web.
    var anchor: String? = nil
    /// Pestaña a la que apunta la flecha (0 = primera).
    var tabIndex: Int? = nil
}

private enum TourStep {
    static let start = TourTip(id: "start", title: "Empieza por Cuentas", text: "Ahí pones tu saldo real, agregas tarjetas y puedes importar tus estados de cuenta.", auto: false, tabIndex: 4)
    static let plus = TourTip(id: "plus", title: "Añade desde aquí", text: "Con el + registras un movimiento, algo previsto, una transferencia o tu trabajo.", auto: false, anchor: "plus")
    static let cuentas = TourTip(id: "deuda", title: "Tus cuentas", text: "Ajusta tu saldo real y añade tus cuentas, tarjetas y préstamos para que Plata cuadre tu mes.", auto: true)
    static let presupuesto = TourTip(id: "presu", title: "Presupuesto", text: "Pon un tope por categoría y mira cuánto llevas gastado este mes.", auto: true)
    static let proyeccion = TourTip(id: "proy", title: "Proyección", text: "Con lo que tienes previsto, aquí ves cómo irá tu saldo en las próximas semanas.", auto: true)
    static let importar = TourTip(id: "imp", title: "Importa en vez de escribir", text: "Sube el PDF o CSV de tu banco y Plata lee los movimientos en tu dispositivo. Nada sale de aquí.", auto: false, anchor: "imp")
    static let gear = TourTip(id: "gear", title: "Ajustes", text: "Perfil, idioma, tema y respaldo de tus datos. Aquí también puedes repetir este tutorial.", auto: false, anchor: "gear")
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
            && !model.showWelcome && !model.showFeedback && !model.showImport
    }

    private var current: TourTip? {
        guard model.tourOn, !model.isDemo, free else { return nil }
        let candidates: [(TourTip, Bool)]
        switch model.tab {
        case .resumen:
            let root = model.path.isEmpty
            let plusSeen = model.tourSeen("plus")
            candidates = [(TourStep.start, root), (TourStep.plus, root && model.tourFrames["plus"] != nil),
                          (TourStep.importar, root && plusSeen && model.tourFrames["imp"] != nil),
                          (TourStep.gear, root && plusSeen && model.tourFrames["gear"] != nil)]
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
                GeometryReader { geo in
                    let origin = geo.frame(in: .global).origin
                    let box = tip.anchor.flatMap { model.tourFrames[$0] }.map { $0.offsetBy(dx: -origin.x, dy: -origin.y).insetBy(dx: -6, dy: -6) }
                    ZStack(alignment: .topLeading) {
                        dim(size: geo.size, hole: box).allowsHitTesting(false)
                        if let box {
                            RoundedRectangle(cornerRadius: min(22, box.height / 2 + 4), style: .continuous)
                                .stroke(Brand.accent, lineWidth: 2.5)
                                .frame(width: box.width, height: box.height)
                                .offset(x: box.minX, y: box.minY)
                                .allowsHitTesting(false)
                        }
                        place(tip, box: box, size: geo.size, safe: geo.safeAreaInsets)
                    }
                }
                .ignoresSafeArea()
                .transition(.opacity)
                .onAppear { show(tip) }
                .onChange(of: tip.id) { _, _ in show(tip) }
            }
        }
        .animation(.easeOut(duration: 0.22), value: current?.id)
    }

    /// Fondo atenuado con un hueco redondeado sobre el botón (como `.tourdim.hole` de la web).
    private func dim(size: CGSize, hole: CGRect?) -> some View {
        Path { p in
            p.addRect(CGRect(origin: .zero, size: size))
            if let h = hole { p.addRoundedRect(in: h, cornerSize: CGSize(width: min(22, h.height / 2 + 4), height: min(22, h.height / 2 + 4)), style: .continuous) }
        }
        .fill(Color.black.opacity(0.28), style: FillStyle(eoFill: true))
    }

    /// La tarjeta va debajo del botón si está en la mitad de arriba, encima si está abajo; sin botón, sobre la barra de pestañas.
    @ViewBuilder
    private func place(_ tip: TourTip, box: CGRect?, size: CGSize, safe: EdgeInsets) -> some View {
        let w = min(300, size.width - 28)
        if let box {
            let below = box.midY < size.height * 0.5
            let x = min(max(14, box.midX - w / 2), size.width - w - 14)
            card(tip, width: w, arrowX: box.midX - x, arrowUp: below)
                .offset(x: x, y: below ? box.maxY + 10 : max(safe.top + 8, box.minY - 10 - 190))
        } else {
            let tabs = 5.0
            let x = (size.width - 32) / tabs
            let center: CGFloat? = tip.tabIndex.map { 16 + x * (CGFloat($0) + 0.5) }
            let left = min(max(14, (center ?? size.width / 2) - w / 2), size.width - w - 14)
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                card(tip, width: w, arrowX: center.map { $0 - left }, arrowUp: false)
                    .padding(.leading, left)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, safe.bottom + 78)
            }
            .frame(width: size.width, height: size.height)
        }
    }

    private func show(_ tip: TourTip) {
        shown = tip.id
        if tip.auto && !model.tourSeen(tip.id) { model.tourMark(tip.id) }
    }

    private func card(_ tip: TourTip, width: CGFloat, arrowX: CGFloat?, arrowUp: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(tip.title).font(.inter(17, .bold)).tracking(-0.3).padding(.bottom, 4)
            Text(tip.text).font(.inter(15)).lineSpacing(3).foregroundStyle(.primary.opacity(0.78))
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
                .padding(.horizontal, 20).frame(minHeight: 40)
                .background(Brand.accent, in: Capsule())
            }
            .padding(.top, 12)
        }
        .padding(.top, 18).padding(.horizontal, 18).padding(.bottom, 12)
        .frame(width: width, alignment: .leading)
        .background(Color(light: "#FFFFFF", dark: "#0D2A1D"), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Brand.accent.opacity(0.45), lineWidth: 1))
        .shadow(color: .black.opacity(0.24), radius: 20, y: 12)
        .overlay(alignment: arrowUp ? .topLeading : .bottomLeading) {
            if let ax = arrowX {
                Triangle().fill(Color(light: "#FFFFFF", dark: "#0D2A1D"))
                    .overlay(Triangle().stroke(Brand.accent.opacity(0.45), lineWidth: 1.5))
                    .frame(width: 18, height: 10)
                    .rotationEffect(.degrees(arrowUp ? 0 : 180))
                    .offset(x: min(max(18, ax), width - 36) - 9, y: arrowUp ? -9 : 9)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: r.midX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); p.closeSubpath(); return p
    }
}

extension View {
    /// Marca un botón para que el tutorial lo resalte (guarda su posición en pantalla en `AppModel.tourFrames`).
    func tourAnchor(_ id: String) -> some View { modifier(TourAnchor(id: id)) }
}

private struct TourAnchor: ViewModifier {
    @Environment(AppModel.self) private var model
    let id: String
    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { if model.tourFrames[id] != $0 { model.tourFrames[id] = $0 } }
            .onDisappear { model.tourFrames[id] = nil }
    }
}


/// El paso «Guarda aquí» (`addtx` de la web): dentro de la hoja de movimiento nuevo, con anillo sobre el check verde.
/// La capa del tutorial de la app queda detrás de las hojas, así que este paso se dibuja dentro de la propia hoja.
private struct TourSheetTip: ViewModifier {
    @Environment(AppModel.self) private var model
    let active: Bool
    @State private var shown = false

    private var tip: TourTip {
        TourTip(id: "addtx", title: "Guarda aquí", text: "Escribe el monto, elige gasto o ingreso y la categoría, y toca el check verde para guardar.", auto: true, anchor: "submit")
    }

    private var visible: Bool {
        active && model.tourOn && !model.isDemo && (shown || !model.tourSeen("addtx")) && model.tourFrames["submit"] != nil
    }

    func body(content: Content) -> some View {
        content.overlay {
            if visible, let frame = model.tourFrames["submit"] {
                GeometryReader { geo in
                    let o = geo.frame(in: .global).origin
                    let box = frame.offsetBy(dx: -o.x, dy: -o.y).insetBy(dx: -6, dy: -6)
                    let w = min(300, geo.size.width - 28)
                    ZStack(alignment: .topLeading) {
                        Path { p in
                            p.addRect(CGRect(origin: .zero, size: geo.size))
                            p.addRoundedRect(in: box, cornerSize: CGSize(width: box.height / 2, height: box.height / 2), style: .continuous)
                        }
                        .fill(Color.black.opacity(0.28), style: FillStyle(eoFill: true)).allowsHitTesting(false)
                        Circle().stroke(Brand.accent, lineWidth: 2.5).frame(width: box.width, height: box.height)
                            .offset(x: box.minX, y: box.minY).allowsHitTesting(false)
                        tipCard(w: w, arrowX: box.midX - min(max(14, box.midX - w / 2), geo.size.width - w - 14))
                            .offset(x: min(max(14, box.midX - w / 2), geo.size.width - w - 14), y: box.maxY + 12)
                    }
                }
                .transition(.opacity)
                .onAppear { shown = true; if !model.tourSeen("addtx") { model.tourMark("addtx") } }
            }
        }
        .animation(.easeOut(duration: 0.22), value: visible)
    }

    private func tipCard(w: CGFloat, arrowX: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(tip.title).font(.inter(17, .bold)).tracking(-0.3).padding(.bottom, 4)
            Text(tip.text).font(.inter(15)).lineSpacing(3).foregroundStyle(.primary.opacity(0.78))
            HStack(spacing: 8) {
                Button("Omitir tutorial") { shown = false; model.tourEnd() }
                    .font(.inter(14, .medium)).foregroundStyle(.secondary).frame(minHeight: 40)
                Spacer(minLength: 0)
                Button("Entendido") { shown = false }
                    .font(.inter(14, .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 20).frame(minHeight: 40)
                    .background(Brand.accent, in: Capsule())
            }
            .padding(.top, 12)
        }
        .padding(.top, 18).padding(.horizontal, 18).padding(.bottom, 12)
        .frame(width: w, alignment: .leading)
        .background(Color(light: "#FFFFFF", dark: "#0D2A1D"), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Brand.accent.opacity(0.45), lineWidth: 1.5))
        .overlay(alignment: .topLeading) {
            Triangle().fill(Color(light: "#FFFFFF", dark: "#0D2A1D"))
                .overlay(Triangle().stroke(Brand.accent.opacity(0.45), lineWidth: 1.5))
                .frame(width: 18, height: 10)
                .offset(x: min(max(18, arrowX), w - 36) - 9, y: -9)
        }
        .shadow(color: .black.opacity(0.24), radius: 20, y: 12)
    }
}

extension View {
    /// Pista del tutorial dentro de la hoja de movimiento nuevo.
    func tourSheetTip(active: Bool) -> some View { modifier(TourSheetTip(active: active)) }
}
