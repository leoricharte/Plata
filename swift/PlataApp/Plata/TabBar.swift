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
                    Text("Registra algo que ya pasó")
                }
                Button { model.activeSheet = .transfer } label: {
                    Label("Transferir", systemImage: "arrow.left.arrow.right")
                    Text("Entre tus cuentas")
                }
                Button { model.importAtCapture = false; model.showImport = true } label: {
                    Label("Importar movimientos", systemImage: "square.and.arrow.down")
                    Text("Archivo o captura de tu banco o app")
                }
            }
            Section("Planear") {
                Button { model.activeSheet = .expected(kind: "income", id: nil) } label: {
                    Label("Ingreso previsto", systemImage: "building.columns")
                    Text("Sueldo, proyecto, pago esperado")
                }
                Button { model.activeSheet = .expected(kind: "expense", id: nil) } label: {
                    Label("Gasto previsto", systemImage: "creditcard")
                    Text("Alquiler, recibo, compra futura")
                }
            }
        } label: {
            Image(systemName: "plus").tourAnchor("plus")
        }
        .accessibilityLabel("Añadir")
    }
}
