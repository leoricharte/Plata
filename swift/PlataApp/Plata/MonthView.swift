import SwiftUI
import PlataCore

/// La pantalla del mes (`monthScreenHTML` de la web): banner de temporada, puntaje, ingresos/gastos/neto y los movimientos del mes por páginas.
struct MonthView: View {
    @Environment(AppModel.self) private var model
    @State private var mk: String = ""
    @State private var filter: Filter = .all
    @State private var page = 0
    @State private var editing: MovimientosView.TxRef?
    @State private var toDelete: MovimientosView.TxRef?
    @State private var postponing: MovimientosView.TxRef?

    enum Filter: String, Identifiable {
        case all, income, out, pay
        var id: String { rawValue }
    }

    private static let perPage = 10

    var body: some View {
        let e = model.engine
        let f = model.fmt
        let month = mk.isEmpty ? String(model.today.iso.prefix(7)) : mk
        let parts = month.split(separator: "-").compactMap { Int($0) }
        let year = parts.count == 2 ? parts[0] : model.today.year
        let month0 = parts.count == 2 ? parts[1] - 1 : model.today.month0
        let all = monthList(e, month)
        let pages = max(1, Int((Double(all.count) / Double(MonthView.perPage)).rounded(.up)))
        let current = min(max(page, 0), pages - 1)
        let slice = Array(all.dropFirst(current * MonthView.perPage).prefix(MonthView.perPage))
        let sums = e.monthSums(month)
        let net = sums.inc - sums.exp

        List {
            Section {
                MonthHeader(month0: month0, year: year, hemi: Engine.text(e.data["settings"]?["hemi"]))
                    .rowStyle(top: 0, bottom: 0)
                scoreRow(e, month)
                    .rowStyle(top: 6, bottom: 22)
            }

            Section {
                Text("Movimientos")
                    .font(.inter(22, .bold, relativeTo: .title2)).tracking(-0.4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .rowStyle(top: 4, bottom: 4)

                HStack(spacing: 6) {
                    stat("Ingresos", f.whole(sums.inc), Brand.gainText)
                    stat("Gastos", f.whole(sums.exp), .primary)
                    stat("Neto", (net < 0 ? "−" : "") + f.whole(abs(net)), net < 0 ? Brand.lossText : Brand.gainText)
                }
                .padding(18)
                .frame(maxWidth: .infinity)
                .plataGlass(in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .rowStyle(top: 6, bottom: 22)

                PillSegmented(items: filters(e).map { ($0, label($0, e)) }, selection: $filter)
                .rowStyle(top: 0, bottom: 14)
            }

            Section {
                if slice.isEmpty {
                    Text("Sin movimientos en este mes").font(.inter(15)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 18)
                        .listRowBackground(Brand.glassFill)
                }
                ForEach(Array(slice.enumerated()), id: \.offset) { _, tx in
                    Button { model.path.append(.tx(Engine.identifier(tx["id"]))) } label: {
                        TransactionRow(tx: tx, engine: e, fmt: f)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 18))
                    .listRowBackground(Brand.glassFill)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) { toDelete = MovimientosView.TxRef(id: Engine.identifier(tx["id"]), tx: tx) } label: {
                            Label("Eliminar", systemImage: "trash")
                        }
                        .tint(Color(hex: "#EB5757"))   // rojo explícito: sin esto toma el verde de la app
                        if Engine.text(tx["category"]) != "Transferencia" {
                            Button { editing = MovimientosView.TxRef(id: Engine.identifier(tx["id"]), tx: tx) } label: {
                                Label("Editar", systemImage: "pencil")
                            }
                            .tint(Color(hex: "#4F94F7"))
                            if Engine.text(tx["category"]) != "Pago de crédito" {
                                Button { postponing = MovimientosView.TxRef(id: Engine.identifier(tx["id"]), tx: tx) } label: {
                                Label("Posponer", systemImage: "calendar.badge.clock")
                            }
                            .tint(Color(hex: "#FF9F0A"))
                            }
                        }
                    }
                }
            }

            if pages > 1 {
                HStack {
                    pager("Anterior", disabled: current == 0) { page = current - 1 }
                    Spacer(minLength: 8)
                    Text("Página \(current + 1) de \(pages)").font(.inter(15)).foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    pager("Siguiente", disabled: current >= pages - 1) { page = current + 1 }
                }
                .rowStyle(top: 0, bottom: 14)
            }
        }
        .syncRefresh()
        .listStyle(.insetGrouped)
        .listSectionSpacing(0)
        .scrollContentBackground(.hidden)
        .plataBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { monthMenu(e, month, month0, year) }
        }
        .onAppear { if mk.isEmpty { mk = String(model.today.iso.prefix(7)) } }
        .onChange(of: filter) { _, _ in page = 0 }
        .onChange(of: mk) { _, _ in page = 0 }
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

    // MARK: puntaje

    @ViewBuilder
    private func scoreRow(_ e: Engine, _ month: String) -> some View {
        let currentMk = String(model.today.iso.prefix(7))
        if let sc = e.monthScore(month) {
            if month >= currentMk {
                Card {
                    HStack(spacing: 14) {
                        GhostScore(size: 52)
                        Text("Aún estamos trabajando en tu puntaje de este mes.")
                            .font(.inter(16, .semibold)).foregroundStyle(.primary.opacity(0.8))
                        Spacer(minLength: 0)
                    }
                }
            } else {
                Card {
                    HStack(spacing: 14) {
                        GradeTile(letter: sc.letter, level: sc.plus, size: 52)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Puntaje").font(.inter(13)).foregroundStyle(.secondary)
                            HStack(alignment: .firstTextBaseline, spacing: 0) {
                                Text("\(sc.score)").font(.inter(26, .heavy, relativeTo: .title)).tracking(-0.5)
                                Text(" / 100").font(.inter(15, .semibold)).foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    StreakRow(letter: sc.letter, streak: sc.streak, level: sc.plus)
                }
            }
        }
    }

    // MARK: filtros y lista

    private func hasPay(_ e: Engine) -> (any: Bool, xfer: Bool, pay: Bool) {
        var x = false, p = false
        for t in e.allTransactions {
            let c = Engine.text(t["category"])
            if c == "Transferencia" { x = true }
            if c == "Pago de crédito" { p = true }
        }
        return (x || p, x, p)
    }

    private func filters(_ e: Engine) -> [Filter] {
        hasPay(e).any ? [.all, .income, .out, .pay] : [.all, .income, .out]
    }

    private func label(_ f: Filter, _ e: Engine) -> String {
        switch f {
        case .all: return "Todos"
        case .income: return "Ingresos"
        case .out: return "Gastos"
        case .pay:
            let h = hasPay(e)
            return h.xfer ? (h.pay ? "Pagos y transf." : "Transferencias") : "Pagos"
        }
    }

    private func monthList(_ e: Engine, _ month: String) -> [JSONValue] {
        let items = e.allTransactions.enumerated().filter { _, t in
            guard Engine.text(t["date"]).hasPrefix(month) else { return false }
            let amount = Engine.number(t["amount"])
            let c = Engine.text(t["category"])
            let isPay = c == "Pago de crédito" || c == "Transferencia"
            switch filter {
            case .all: return true
            case .income: return amount > 0 && !isPay
            case .out: return amount < 0 && !isPay
            case .pay: return isPay
            }
        }
        // más nuevo primero; con la misma fecha, el id mayor primero (comparación numérica como `localeCompare`)
        let sorted = items.sorted { (a: (offset: Int, element: JSONValue), b: (offset: Int, element: JSONValue)) -> Bool in
            let da = Engine.text(a.element["date"]), db = Engine.text(b.element["date"])
            if da != db { return da > db }
            let ia = Engine.identifier(a.element["id"]), ib = Engine.identifier(b.element["id"])
            let c = ib.compare(ia, options: .numeric)
            if c != .orderedSame { return c == .orderedAscending }
            return a.offset < b.offset
        }
        return sorted.map { $0.element }
    }

    // MARK: piezas

    private func stat(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.inter(15)).foregroundStyle(.secondary)
            Text(value).font(.inter(17, .semibold)).monospacedDigit().foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    /// El `execbtn` de la web: píldora verde de 28 pt (la zona de toque es más alta).
    private func pager(_ title: String, disabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.inter(13, .semibold)).foregroundStyle(Brand.accent)
                .frame(minWidth: 104, minHeight: 28)
                .background(Brand.gainBg, in: Capsule())
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .opacity(disabled ? 0.35 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    /// Los meses con movimientos, del actual hacia atrás (como el selector de la web).
    private func monthKeys(_ e: Engine, selected: String) -> [String] {
        let cur = String(model.today.iso.prefix(7))
        var first = cur
        for t in e.allTransactions {
            let k = String(Engine.text(t["date"]).prefix(7))
            if k <= cur && k < first { first = k }
        }
        var keys: [String] = []
        var y = model.today.year, m0 = model.today.month0
        while keys.count < 60 {
            let k = String(format: "%04d-%02d", y, m0 + 1)
            if k < first { break }
            keys.append(k)
            m0 -= 1
            if m0 < 0 { m0 = 11; y -= 1 }
        }
        if !keys.contains(selected) { keys.append(selected) }
        return keys
    }

    private func monthTitle(_ k: String) -> String {
        let p = k.split(separator: "-").compactMap { Int($0) }
        guard p.count == 2, (1...12).contains(p[1]) else { return k }
        return Spanish.monthsFull[p[1] - 1].capitalized + " " + String(p[0])
    }

    private func monthMenu(_ e: Engine, _ month: String, _ month0: Int, _ year: Int) -> some View {
        Menu {
            ForEach(monthKeys(e, selected: month), id: \.self) { k in
                Button { mk = k } label: {
                    if k == month { Label(monthTitle(k), systemImage: "checkmark") } else { Text(monthTitle(k)) }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text("\(Spanish.monthsFull[month0].capitalized.prefix(3)) \(String(year))").font(.inter(16, .bold))
                Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.primary)
        }
        .accessibilityLabel("Cambiar mes")
    }
}

extension View {
    /// Una fila de `List` sin fondo ni separador, para dibujar tarjetas propias (como en la web).
    func rowStyle(top: CGFloat, bottom: CGFloat) -> some View {
        self
            .listRowInsets(EdgeInsets(top: top, leading: 0, bottom: bottom, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
