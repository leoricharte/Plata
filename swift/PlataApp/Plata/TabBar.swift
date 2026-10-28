import SwiftUI

/// El «+» de la barra superior (convención de iOS: las acciones van en la barra de herramientas, no en la de pestañas).
/// Abre el mismo menú de la web: movimiento, ingreso o gasto previsto, transferir y trabajo.
struct AddMenuButton: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Menu {
            Button { model.showAddTransaction = true } label: {
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
        }
        .accessibilityLabel("Añadir")
    }
}
