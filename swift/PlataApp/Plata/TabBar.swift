import SwiftUI

/// El «+» de la barra superior (convención de iOS: las acciones van en la barra de herramientas, no en la de pestañas).
/// Registrar (movimiento, transferir, importar movimientos) y planear (ingreso o gasto previsto). El trabajo vive en Proyección y en Cuentas.
/// Es un popover propio (no el `Menu` del sistema) para controlar el espacio: el menú nativo no deja igualar el aire arriba y abajo ni poner descripciones.
struct AddMenuButton: View {
    @Environment(AppModel.self) private var model
    @State private var open = false

    var body: some View {
        Button { open = true } label: {
            Image(systemName: "plus").tourAnchor("plus")
        }
        .accessibilityLabel("Añadir")
        .popover(isPresented: $open, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
            content.presentationCompactAdaptation(.popover)
        }
    }

    private func go(_ action: @escaping () -> Void) {
        open = false
        Task { try? await Task.sleep(for: .milliseconds(260)); action() }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            header("Registrar")
            row("plus", "Movimiento", "Algo que ya pasó") { model.showAddTransaction = true }
            row("arrow.left.arrow.right", "Transferir", "Entre tus cuentas") { model.activeSheet = .transfer }
            row("square.and.arrow.down", "Importar", "Archivo o captura") { model.importAtCapture = false; model.showImport = true }
            Divider().padding(.horizontal, 20).padding(.vertical, 10)
            header("Planear")
            row("arrow.down.circle", "Ingreso previsto", "Sueldo o pago") { model.activeSheet = .expected(kind: "income", id: nil) }
            row("arrow.up.circle", "Gasto previsto", "Recibo o compra") { model.activeSheet = .expected(kind: "expense", id: nil) }
        }
        .padding(.vertical, 16)
        .frame(width: 288)
    }

    private func header(_ t: String) -> some View {
        Text(verbatim: Tr.t(t)).font(.inter(13, .semibold)).foregroundStyle(.secondary)
            .padding(.horizontal, 20).padding(.bottom, 4)
    }

    private func row(_ icon: String, _ title: String, _ sub: String, _ action: @escaping () -> Void) -> some View {
        Button { go(action) } label: {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.system(size: 19, weight: .regular)).foregroundStyle(Brand.accent).frame(width: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: Tr.t(title)).font(.inter(17)).foregroundStyle(.primary)
                    Text(verbatim: Tr.t(sub)).font(.inter(13)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20).padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
