import SwiftUI
import PlataCore

struct MovimientosView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var filter: Filter = .all
    @State private var adding = false
    @State private var editing: TxRef?
    @State private var toDelete: TxRef?

    enum Filter: String, CaseIterable, Identifiable {
        case all, out, income
        var id: String { rawValue }
        var title: LocalizedStringKey {
            switch self {
            case .all: return "Todos"
            case .out: return "Gastos"
            case .income: return "Ingresos"
            }
        }
    }

    /// Un movimiento para abrir su hoja de edición o confirmar su borrado.
    struct TxRef: Identifiable {
        let id: String
        let tx: JSONValue
    }

    struct DayGroup: Identifiable {
        let id: String
        let date: LocalDate?
        let items: [JSONValue]
    }

    var body: some View {
        let e = model.engine
        let f = model.fmt
        let groups = dayGroups(e)
        Group {
            List {
                Section {
                    Picker("Filtro", selection: $filter) {
                        ForEach(Filter.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                if groups.isEmpty {
                    Section {
                        ContentUnavailableView(query.isEmpty ? "Sin movimientos" : "Sin resultados",
                                               systemImage: "list.bullet.rectangle",
                                               description: Text(query.isEmpty ? "Añade tu primer movimiento con el botón +." : "Prueba con otra búsqueda."))
                            .listRowBackground(Color.clear)
                    }
                }
                ForEach(groups) { g in
                    Section {
                        ForEach(Array(g.items.enumerated()), id: \.offset) { _, tx in
                            Button { editing = TxRef(id: Engine.identifier(tx["id"]), tx: tx) } label: { TransactionRow(tx: tx, engine: e, fmt: f) }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) { toDelete = TxRef(id: Engine.identifier(tx["id"]), tx: tx) } label: { Label("Borrar", systemImage: "trash") }
                                }
                        }
                    } header: {
                        Text(dayTitle(g.date))
                    }
                }
            }
            .navigationTitle("Movimientos")
            .searchable(text: $query, prompt: "Buscar")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { adding = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Añadir movimiento")
                }
            }
            .sheet(isPresented: $adding) { TransactionSheet(mode: .new) }
            .sheet(item: $editing) { ref in TransactionSheet(mode: .edit(ref.tx)) }
            .confirmationDialog("¿Borrar este movimiento?", isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } }), titleVisibility: .visible) {
                Button("Borrar", role: .destructive) {
                    if let t = toDelete { try? model.deleteTransaction(id: t.tx["id"] ?? .null) }
                    toDelete = nil
                }
                Button("Cancelar", role: .cancel) { toDelete = nil }
            } message: {
                Text("El saldo de la cuenta se corrige.")
            }
        }
    }

    // MARK: datos

    private func dayGroups(_ e: Engine) -> [DayGroup] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let items = e.allTransactions.filter { tx in
            let amount = Engine.number(tx["amount"])
            let category = Engine.text(tx["category"])
            let isPay = category == "Pago de crédito" || category == "Transferencia"
            switch filter {
            case .all: break
            case .out: if !(amount < 0) || isPay { return false }
            case .income: if !(amount > 0) || isPay { return false }
            }
            if q.isEmpty { return true }
            let hay = (Engine.text(tx["note"]) + " " + category + " " + e.accountName(tx["acc"]) + " " + String(abs(amount))).lowercased()
            return hay.contains(q)
        }
        // más nuevo primero; con la misma fecha, el de id mayor primero (lo último que anotaste)
        let sorted = items.enumerated().sorted { (a: (offset: Int, element: JSONValue), b: (offset: Int, element: JSONValue)) -> Bool in
            let da = Engine.text(a.element["date"]), db = Engine.text(b.element["date"])
            if da != db { return da > db }
            let ia = Engine.number(a.element["id"]), ib = Engine.number(b.element["id"])
            if ia != ib { return ia > ib }
            return a.offset < b.offset
        }.map { $0.element }
        var groups: [DayGroup] = []
        var currentKey = ""
        var bucket: [JSONValue] = []
        for tx in sorted {
            let d = Engine.text(tx["date"])
            if d != currentKey {
                if !bucket.isEmpty { groups.append(DayGroup(id: currentKey, date: LocalDate(iso: currentKey), items: bucket)) }
                currentKey = d
                bucket = []
            }
            bucket.append(tx)
        }
        if !bucket.isEmpty { groups.append(DayGroup(id: currentKey, date: LocalDate(iso: currentKey), items: bucket)) }
        return groups
    }

    private func dayTitle(_ d: LocalDate?) -> String {
        guard let d else { return "Sin fecha" }
        let diff = model.today.days - d.days
        if diff == 0 { return "Hoy" }
        if diff == 1 { return "Ayer" }
        return d.date().formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    private func row(_ tx: JSONValue, _ e: Engine, _ f: Fmt) -> some View {
        let category = Engine.text(tx["category"])
        let amount = Engine.number(tx["amount"])
        let cur = e.accountCurrency(tx["acc"])
        let isTransfer = category == "Transferencia"
        let color: Color = category == "Pago de crédito" ? Color(hex: "#B98AE6") : (isTransfer ? .gray : Color(hex: e.categoryColor(amount > 0 ? "Ingreso" : category)))
        let note = Engine.text(tx["note"])
        return HStack(spacing: 12) {
            Tile(symbol: categorySymbol(amount > 0 && !isTransfer && category != "Pago de crédito" ? "Ingreso" : category), color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(note.isEmpty ? category : note).font(.body).lineLimit(1)
                Text("\(category) · \(e.accountName(tx["acc"]))").font(.footnote).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(f.signed(amount, cur)).font(.body.weight(.semibold)).foregroundStyle(amount > 0 && !isTransfer ? Brand.gain : Color.primary)
        }
        .contentShape(Rectangle())
    }
}
