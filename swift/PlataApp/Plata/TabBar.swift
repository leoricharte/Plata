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

    var body: some View {
        HStack(spacing: 8) {
            if !showTabs { Spacer(minLength: 0) }
            if showTabs {
            HStack(spacing: 2) {
                ForEach(items, id: \.tab) { item in
                    let on = tab == item.tab
                    Button { tab = item.tab } label: {
                        VStack(spacing: 0) {
                            Image(systemName: item.symbol)
                                .symbolVariant(on ? .fill : .none)
                                .font(.system(size: 22, weight: .regular))
                                .frame(height: 28)
                            Text(item.title).font(.inter(10, .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(on ? Brand.accent : Color.primary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(on ? Color(.secondarySystemFill) : Color.clear, in: Capsule())
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(height: 62)
            .modifier(GlassCapsule())
            }

            Menu {
                Button { onNewMovement() } label: {
                    Label("Movimiento", systemImage: "plus.circle")
                    Text("Registra algo que ya pasó")
                }
                Button {} label: {
                    Label("Ingreso previsto", systemImage: "building.columns")
                    Text("Sueldo, proyecto, pago esperado")
                }.disabled(true)
                Button {} label: {
                    Label("Gasto previsto", systemImage: "creditcard")
                    Text("Alquiler, recibo, compra futura")
                }.disabled(true)
                Button {} label: {
                    Label("Transferir", systemImage: "arrow.left.arrow.right")
                    Text("Entre tus cuentas")
                }.disabled(true)
                Divider()
                Button {} label: {
                    Label("Trabajo", systemImage: "banknote")
                    Text("Pago por hora, impuestos, frecuencia")
                }.disabled(true)
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
