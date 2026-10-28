import SwiftUI
import PlataCore

/// Hoja para añadir o editar un movimiento, con el diseño de la web (`sheetHTML` / `txEditHTML`).
struct TransactionSheet: View {
    enum Mode {
        case new
        case edit(JSONValue)
    }

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let mode: Mode

    @State private var loaded = false
    @State private var isOut = true
    @State private var amountText = ""
    @State private var category = ""
    @State private var account = ""
    @State private var date = Date()
    @State private var note = ""
    @State private var errorText: String?
    @FocusState private var amountFocused: Bool

    private var editedTx: JSONValue? {
        if case .edit(let tx) = mode { return tx }
        return nil
    }

    /// Pagos de tarjeta y transferencias conservan su signo y categoría: solo se editan monto, cuenta, fecha y nota.
    private var isPayLike: Bool {
        guard let tx = editedTx else { return false }
        let c = Engine.text(tx["category"])
        return c == "Pago de crédito" || c == "Transferencia"
    }

    var body: some View {
        let e = model.engine
        let f = model.fmt
        ScrollView {
            VStack(spacing: 0) {
                SheetHead(title: editedTx == nil ? "Nuevo movimiento" : "Editar movimiento", onClose: { dismiss() }, onSave: { save() })

                AmountField(symbol: f.symbol(e.accountCurrency(JSONValue.string(account))), text: $amountText,
                            placeholder: Money.decimals(e.accountCurrency(JSONValue.string(account))) > 0 ? "0.00" : "0", focus: $amountFocused)

                if !isPayLike {
                    PillSegmented(items: [(true, "Gasto"), (false, "Ingreso")], selection: $isOut)
                        .padding(.bottom, 4)
                    Text(isOut ? "Dinero que sale. Cuenta en tu presupuesto." : "Dinero que entra. Suma a tus ingresos.")
                        .font(.inter(13)).foregroundStyle(.secondary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .padding(.top, 8).padding(.bottom, 14).padding(.horizontal, 12)
                    if isOut { ChipRow(items: e.categoryNames, selection: $category) }
                }

                SCard {
                    SRow(symbol: "creditcard", label: "Cuenta") {
                        Picker("Cuenta", selection: $account) {
                            Section("Débito") {
                                ForEach(Array(e.allAccounts.enumerated()), id: \.offset) { _, a in
                                    Text(accountLabel(a)).tag(Engine.text(a["id"]))
                                }
                            }
                            if (isOut || isPayLike) && !e.allCards.isEmpty {
                                Section("Crédito") {
                                    ForEach(Array(e.allCards.enumerated()), id: \.offset) { _, k in
                                        Text(accountLabel(k)).tag(Engine.text(k["id"]))
                                    }
                                }
                            }
                        }
                        .labelsHidden()
                        .tint(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    RowDivider()
                    SRow(symbol: "pencil", label: "Nota") {
                        TextField(editedTx == nil ? "Opcional" : "", text: $note)
                    }
                    if editedTx == nil {
                        let list = suggestions(e)
                        if !list.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(list, id: \.name) { s in
                                        Button { pick(s) } label: {
                                            Text(s.name).font(.inter(14, .medium)).foregroundStyle(.primary)
                                                .lineLimit(1)
                                                .padding(.horizontal, 12).padding(.vertical, 6)
                                                .background(Color(light: "#E5E5EA", dark: "#2C2C2E"), in: Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.leading, 40)
                            }
                            .padding(.bottom, 4)
                        }
                    }
                    RowDivider()
                    SRow(symbol: "calendar", label: "Fecha") {
                        HStack {
                            DatePicker("Fecha", selection: $date, in: ...Date(), displayedComponents: .date).labelsHidden()
                            Spacer(minLength: 0)
                        }
                    }
                }

                if let errorText {
                    Text(errorText).font(.inter(14)).foregroundStyle(Brand.lossText).padding(.bottom, 10)
                }

                Button(editedTx == nil ? "Añadir" : "Guardar") { save() }
                    .buttonStyle(PrimaryPillStyle())
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(38)
        .presentationBackground(Color(light: "#F4F4F8", dark: "#1C1C1E"))
        .onAppear(perform: load)
        .onChange(of: isOut) { _, nowOut in
            // un ingreso no va en una tarjeta
            if !nowOut, model.engine.allCards.contains(where: { Engine.text($0["id"]) == account }), let first = model.engine.allAccounts.first {
                account = Engine.text(first["id"])
            }
        }
    }

    // MARK: sugerencias de nota (lo que ya escribiste antes)

    private struct Suggestion {
        let name: String
        var count: Int
        let category: String
        let out: Bool
    }

    private func suggestions(_ e: Engine) -> [Suggestion] {
        var order: [String] = []
        var map: [String: Suggestion] = [:]
        for t in e.allTransactions.reversed() {
            let n = Engine.text(t["note"]).trimmingCharacters(in: .whitespacesAndNewlines)
            if n.isEmpty || n.count > 40 || n.hasPrefix("Pago de ") { continue }
            let k = n.lowercased()
            if var s = map[k] { s.count += 1; map[k] = s }
            else { map[k] = Suggestion(name: n, count: 1, category: Engine.text(t["category"]), out: Engine.number(t["amount"]) < 0); order.append(k) }
        }
        let q = note.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = order.compactMap { map[$0] }.filter { q.isEmpty || ($0.name.lowercased().contains(q) && $0.name.lowercased() != q) }
        let ranked = filtered.enumerated().sorted { a, b in
            let ap = !q.isEmpty && a.element.name.lowercased().hasPrefix(q) ? 1 : 0
            let bp = !q.isEmpty && b.element.name.lowercased().hasPrefix(q) ? 1 : 0
            if ap != bp { return ap > bp }
            if a.element.count != b.element.count { return a.element.count > b.element.count }
            return a.offset < b.offset
        }
        return Array(ranked.prefix(4).map { $0.element })
    }

    private func pick(_ s: Suggestion) {
        note = s.name
        if isOut, s.out, model.engine.categoryNames.contains(s.category) { category = s.category }
    }

    private func accountLabel(_ a: JSONValue) -> String {
        var s = Engine.text(a["name"])
        let l4 = Engine.text(a["last4"])
        if !l4.isEmpty { s += " · ● " + l4 }
        return s + " · " + Engine.text(a["cur"])
    }

    // MARK: acciones

    private func load() {
        guard !loaded else { return }
        loaded = true
        let e = model.engine
        if let tx = editedTx {
            let amount = Engine.number(tx["amount"])
            isOut = amount < 0
            amountText = trimmed(abs(amount))
            category = e.categoryNames.contains(Engine.text(tx["category"])) ? Engine.text(tx["category"]) : "Otros"
            account = Engine.text(tx["acc"])
            if let d = LocalDate(iso: Engine.text(tx["date"])) { date = d.date() }
            note = Engine.text(tx["note"])
        } else {
            category = e.categoryNames.first ?? "Otros"
            account = Engine.text(e.allAccounts.first?["id"])
            amountFocused = true
        }
    }

    private func trimmed(_ n: Double) -> String {
        n == n.rounded() ? String(Int64(n)) : String(n)
    }

    private func save() {
        let text = amountText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        guard let amount = Double(text), amount > 0 else { errorText = "Escribe un monto."; return }
        let day = LocalDate.today(now: date)
        do {
            if let tx = editedTx {
                try model.updateTransaction(id: tx["id"] ?? .null, amount: amount, isOut: isOut, category: category, account: account, date: day, note: note)
            } else {
                let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
                let cat = isOut ? category : "Ingreso"
                try model.addTransaction(date: day, amount: isOut ? -amount : amount, category: cat,
                                         note: trimmedNote.isEmpty ? (isOut ? category : "Ingreso") : trimmedNote, account: account)
            }
            dismiss()
        } catch ProfileEditor.EditError.incomeOnCard {
            errorText = "Un ingreso no va en una tarjeta. Para pagarla usa Pago."
        } catch {
            errorText = "No se pudo guardar el movimiento."
        }
    }
}
