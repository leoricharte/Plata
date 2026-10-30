import SwiftUI
import PlataCore

/// Movimientos: igual que la pantalla de la web (título, filtro Todos/Ingresos/Gastos, «Añadir movimiento» y la lista).
struct MovimientosView: View {
    @Environment(AppModel.self) private var model
    @State private var filter: Filter = .all
    @State private var editing: TxRef?
    @State private var toDelete: TxRef?
    @State private var postponing: TxRef?

    enum Filter: String, CaseIterable, Identifiable {
        case all, income, out
        var id: String { rawValue }
        var title: String {
            switch self {
            case .all: return "Todos"
            case .income: return "Ingresos"
            case .out: return "Gastos"
            }
        }
    }

    /// Un movimiento para abrir su hoja de edición o confirmar su borrado.
    struct TxRef: Identifiable {
        let id: String
        let tx: JSONValue
    }

    /// Como la web, la lista muestra los 40 más recientes.
    private static let limit = 40

    var body: some View {
        let e = model.engine
        let f = model.fmt
        let rows = visibleRows(e)
        List {
            Section {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Últimos movimientos").font(.inter(15)).foregroundStyle(.secondary)
                    Text("Movimientos").font(.inter(34, .bold, relativeTo: .largeTitle)).tracking(-1.2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 8, trailing: 4))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                PillSegmented(items: Filter.allCases.map { ($0, $0.title) }, selection: $filter)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 14, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                Button { model.showAddTransaction = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundStyle(Brand.accent).frame(width: 26)
                        Text("Añadir movimiento").font(.inter(17)).foregroundStyle(Brand.accent)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 18))
                .listRowBackground(Brand.glassFill)
                Button { model.showImport = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "folder.badge.plus").font(.system(size: 22)).foregroundStyle(Brand.accent).frame(width: 26)
                        Text("Importar datos de banco").font(.inter(17)).foregroundStyle(Brand.accent)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 18))
                .listRowBackground(Brand.glassFill)
            }

            Section {
                if rows.isEmpty {
                    Text("Sin movimientos todavía").font(.inter(15)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 18)
                        .listRowBackground(Brand.glassFill)
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { _, tx in
                    Button { model.path.append(.tx(Engine.identifier(tx["id"]))) } label: {
                        TransactionRow(tx: tx, engine: e, fmt: f)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 18))
                    .listRowBackground(Brand.glassFill)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) { toDelete = TxRef(id: Engine.identifier(tx["id"]), tx: tx) } label: {
                            Label("Eliminar", systemImage: "trash")
                        }
                        if !isTransfer(tx) {
                            Button { editing = TxRef(id: Engine.identifier(tx["id"]), tx: tx) } label: {
                                Label("Editar", systemImage: "pencil")
                            }
                            .tint(Color(hex: "#4F94F7"))
                            if Engine.text(tx["category"]) != "Pago de crédito" {
                                Button { postponing = TxRef(id: Engine.identifier(tx["id"]), tx: tx) } label: {
                                Label("Posponer", systemImage: "calendar.badge.clock")
                            }
                            .tint(Color(hex: "#FF9F0A"))
                            }
                        }
                    }
                }
            }
        }
        .syncRefresh()
        .listStyle(.insetGrouped)
        .listSectionSpacing(12)
        .scrollContentBackground(.hidden)
        .plataBackground()
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { ref in TransactionSheet(mode: .edit(ref.tx)) }
        .sheet(item: $postponing) { ref in PostponeSheet(tx: ref.tx) { postponing = nil } }
        .alert("¿Eliminar este movimiento?", isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } })) {
            Button("Eliminar", role: .destructive) {
                if let t = toDelete { try? model.deleteTransaction(id: t.tx["id"] ?? .null) }
                toDelete = nil
            }
            Button("Cancelar", role: .cancel) { toDelete = nil }
        } message: {
            Text("El saldo de la cuenta se corrige.")
        }
    }

    // MARK: datos

    private func isTransfer(_ tx: JSONValue) -> Bool { Engine.text(tx["category"]) == "Transferencia" }

    private func visibleRows(_ e: Engine) -> [JSONValue] {
        let byId: [String: JSONValue] = Dictionary(e.allTransactions.map { (Engine.identifier($0["id"]), $0) }, uniquingKeysWith: { a, _ in a })
        var out: [JSONValue] = []
        for id in e.calc().txIds {
            guard let tx = byId[id] else { continue }
            let amount = Engine.number(tx["amount"])
            let category = Engine.text(tx["category"])
            let isPay = category == "Pago de crédito" || category == "Transferencia"
            switch filter {
            case .all: break
            case .income: if !(amount > 0) || isPay { continue }
            case .out: if !(amount < 0) || isPay { continue }
            }
            out.append(tx)
            if out.count >= MovimientosView.limit { break }
        }
        return out
    }
}
