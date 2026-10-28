import SwiftUI

/// Vidrio en forma de cápsula (la barra de pestañas flotante de la web).
struct GlassCapsule: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular, in: Capsule())
        } else {
            content
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.6), lineWidth: 1))
                .shadow(color: .black.opacity(0.09), radius: 15, y: 8)
        }
    }
}

/// La barra de abajo de la web: una píldora con las 4 pestañas a la izquierda y el botón redondo «+» a la derecha.
struct PlataTabBar: View {
    @Environment(AppModel.self) private var model
    @Binding var tab: AppTab
    /// En las pantallas abiertas encima del Resumen la web esconde las pestañas y deja solo el botón «+».
    var showTabs = true
    var onNewMovement: () -> Void

    private struct Item {
        let tab: AppTab
        let title: LocalizedStringKey
        let symbol: String
    }

    private let items: [Item] = [
        Item(tab: .resumen, title: "Resumen", symbol: "chart.pie"),
        Item(tab: .presupuesto, title: "Presupuesto", symbol: "wallet.bifold"),
        Item(tab: .proyeccion, title: "Proyección", symbol: "chart.line.uptrend.xyaxis"),
        Item(tab: .cuentas, title: "Cuentas", symbol: "creditcard"),
    ]

    @State private var held = false
    @State private var dragX: CGFloat?

    /// Las 4 pestañas con la píldora que se arrastra: al tocar y deslizar, la píldora sigue al dedo (como la web) y al soltar elige.
    private var tabsBar: some View {
        GeometryReader { geo in
            let tw = geo.size.width / CGFloat(items.count)
            let idx = items.firstIndex(where: { $0.tab == tab }) ?? 0
            let hover = dragX.map { min(max(Int($0 / tw), 0), items.count - 1) } ?? idx
            let pillX = dragX.map { min(max($0 - tw / 2, 0), geo.size.width - tw) } ?? CGFloat(idx) * tw
            ZStack(alignment: .leading) {
                pill(width: tw, height: geo.size.height)
                    .offset(x: pillX)
                    .animation(dragX == nil ? .spring(response: 0.35, dampingFraction: 0.8) : .interactiveSpring(), value: pillX)
                HStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                        let on = i == hover
                        VStack(spacing: 0) {
                            Image(systemName: item.symbol)
                                .symbolVariant(on ? .fill : .none)
                                .font(.system(size: 22, weight: .regular))
                                .frame(height: 28)
                            Text(item.title).font(.inter(10, .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(on ? Brand.accent : Color.primary)
                        .frame(width: tw, height: geo.size.height)
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(item.tab == tab ? .isSelected : [])
                        .accessibilityAction { tab = item.tab }
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        held = true
                        dragX = min(max(v.location.x, 0), geo.size.width)
                    }
                    .onEnded { v in
                        let x = min(max(v.location.x, 0), geo.size.width)
                        let i = min(max(Int(x / tw), 0), items.count - 1)
                        held = false
                        dragX = nil
                        if tab != items[i].tab { tab = items[i].tab }
                    }
            )
        }
    }

    @ViewBuilder
    private func pill(width: CGFloat, height: CGFloat) -> some View {
        if #available(iOS 26, *) {
            Capsule().fill(Color.clear)
                .frame(width: width, height: height)
                .glassEffect(held ? .regular.interactive() : .clear, in: Capsule())
                .overlay(Capsule().fill(Color(.secondarySystemFill)).opacity(held ? 0 : 1))
        } else {
            Capsule().fill(held ? Color(.systemFill) : Color(.secondarySystemFill))
                .frame(width: width, height: height)
                .shadow(color: .black.opacity(held ? 0.14 : 0), radius: 7, y: 3)
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            if !showTabs { Spacer(minLength: 0) }
            if showTabs {
            tabsBar
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(height: 62)
            .modifier(GlassCapsule())
            .scaleEffect(held ? 1.05 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: held)
            }

            Menu {
                Button { onNewMovement() } label: {
                    Label("Movimiento", systemImage: "plus.circle")
                    Text("Registra algo que ya pasó")
                }
                Button { model.activeSheet = .expected(kind: "income", id: nil) } label: {
                    Label("Ingreso previsto", systemImage: "building.columns")
                    Text("Sueldo, proyecto, pago esperado")
                }
                Button { model.activeSheet = .expected(kind: "expense", id: nil) } label: {
                    Label("Gasto previsto", systemImage: "creditcard")
                    Text("Alquiler, recibo, compra futura")
                }
                Button { model.activeSheet = .transfer } label: {
                    Label("Transferir", systemImage: "arrow.left.arrow.right")
                    Text("Entre tus cuentas")
                }
                Divider()
                Button { model.activeSheet = .job(id: nil) } label: {
                    Label("Trabajo", systemImage: "banknote")
                    Text("Pago por hora, impuestos, frecuencia")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(.primary)
                    .frame(width: 62, height: 62)
                    .modifier(GlassCircle())
            }
            .accessibilityLabel("Añadir")
        }
        .padding(.horizontal, 20)
        .padding(.bottom, -12)   // la web la deja a ~22 pt del borde: safe area inferior (34) − 12
    }
}
