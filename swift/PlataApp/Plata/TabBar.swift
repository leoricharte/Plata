import SwiftUI

/// El «+» de la barra superior (convención de iOS: las acciones van en la barra de herramientas, no en la de pestañas).
/// Registrar (movimiento, transferir, importar movimientos) y planear (ingreso o gasto previsto). El trabajo vive en Proyección y en Cuentas.
struct AddMenuButton: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Menu {
            Section("Registrar") {
                Button { model.showAddTransaction = true } label: {
                    Label("Movimiento", systemImage: "plus.circle")
                    Text("Algo que ya pasó")
                }
                Button { model.activeSheet = .transfer } label: {
                    Label("Transferir", systemImage: "arrow.left.arrow.right")
                    Text("Entre tus cuentas")
                }
                Button { model.importAtCapture = false; model.showImport = true } label: {
                    Label("Importar", systemImage: "square.and.arrow.down")
                    Text("Archivo o captura")
                }
            }
            Section("Planear") {
                Button { model.activeSheet = .expected(kind: "income", id: nil) } label: {
                    Label("Ingreso previsto", systemImage: "building.columns")
                    Text("Sueldo o pago")
                }
                Button { model.activeSheet = .expected(kind: "expense", id: nil) } label: {
                    Label("Gasto previsto", systemImage: "creditcard")
                    Text("Recibo o compra")
                }
            }
        } label: {
            Image(systemName: "plus").tourAnchor("plus")
        }
        .accessibilityLabel("Añadir")
    }
}
