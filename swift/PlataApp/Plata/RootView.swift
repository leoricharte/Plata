import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Resumen", systemImage: "chart.pie.fill") { ResumenView() }
            Tab("Movimientos", systemImage: "list.bullet") { MovimientosView() }
            Tab("Ajustes", systemImage: "gearshape.fill") { AjustesView() }
        }
        .tint(Brand.green)
    }
}
