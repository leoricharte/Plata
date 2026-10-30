import SwiftUI

/// Una acción de deslizar (`SW_BTN` de la web): círculo de color con icono y la etiqueta debajo.
struct SwipeAction: Identifiable {
    let id = UUID()
    let label: String
    let symbol: String
    let color: Color
    /// Si lleva texto, pide confirmación antes de ejecutarla (eliminar).
    var confirm: String? = nil
    let run: () -> Void
}

/// Deslizar a la izquierda una fila que NO está en una `List` (las tarjetas del Resumen, Cuentas, Presupuesto…),
/// con las mismas acciones que la web (`PX_ACTS`). En una `List` se usa `.swipeActions`.
private struct SwipeRowModifier: ViewModifier {
    let actions: [SwipeAction]
    @State private var offset: CGFloat = 0
    @State private var dragging = false
    @State private var startOffset: CGFloat = 0
    @State private var pending: SwipeAction?
    private let item: CGFloat = 74

    private var width: CGFloat { item * CGFloat(actions.count) }

    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 0) {
                ForEach(actions) { a in
                    Button {
                        close()
                        if a.confirm != nil { pending = a } else { a.run() }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: a.symbol).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                                .frame(width: 40, height: 40).background(a.color, in: Circle())
                            Text(a.label).font(.inter(11, .medium)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .frame(width: item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .opacity(offset < -8 ? 1 : 0)
            .mask(alignment: .trailing) { Rectangle().frame(width: max(0, -offset)) }   // solo se ven las acciones ya reveladas: la fila no necesita fondo propio

            content
                .offset(x: offset)
                .overlay { if offset < 0 && !dragging { Color.clear.contentShape(Rectangle()).onTapGesture { close() } } }
        }
        .clipped()
        .simultaneousGesture(
            DragGesture(minimumDistance: 14)
                .onChanged { g in
                    if !dragging {
                        guard abs(g.translation.width) > abs(g.translation.height) * 1.4 else { return }
                        dragging = true; startOffset = offset
                    }
                    offset = min(0, max(-width - 24, startOffset + g.translation.width))
                }
                .onEnded { _ in
                    guard dragging else { return }
                    dragging = false
                    withAnimation(.snappy(duration: 0.22)) { offset = offset < -width * 0.45 ? -width : 0 }
                }
        )
        .alert(pending?.confirm ?? "", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })) {
            Button("Eliminar", role: .destructive) { pending?.run(); pending = nil }
            Button("Cancelar", role: .cancel) { pending = nil }
        }
    }

    private func close() { withAnimation(.snappy(duration: 0.22)) { offset = 0 } }
}

extension View {
    func swipeRow(_ actions: [SwipeAction]) -> some View {
        actions.isEmpty ? AnyView(self) : AnyView(modifier(SwipeRowModifier(actions: actions)))
    }
}

/// Gesto de jalar para recargar: sincroniza con Plata Cloud (si hay sesión) y refresca.
private struct SyncRefresh: ViewModifier {
    @Environment(CloudModel.self) private var cloud
    func body(content: Content) -> some View {
        content.refreshable {
            if cloud.isIn && cloud.isCloud { await cloud.sync(.manual) } else { try? await Task.sleep(for: .milliseconds(500)) }
        }
    }
}
extension View { func syncRefresh() -> some View { modifier(SyncRefresh()) } }
