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
    /// Cuenta o tarjeta con la que se abre un movimiento nuevo (desde su detalle).
    var presetAccount: String? = nil

    @State private var loaded = false
    @State private var isOut = true
    @State private var amountText = ""
    @State private var category = ""
    @State private var account = ""
    @State private var date = Date()
    @State private var note = ""
    @State private var errorText: String?
    @State private var isPay = false
    @State private var card = ""
    @State private var from = ""
    @State private var autoOn = false
    @State private var overpay: Double?
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
        let accCur = e.accountCurrency(JSONValue.string(isPay ? card : account))
        ScrollView {
            VStack(spacing: 0) {
                SheetHead(title: editedTx == nil ? "Nuevo movimiento" : "Editar movimiento", onClose: { dismiss() }, onSave: { save(e) })

                AmountField(symbol: f.symbol(accCur), text: $amountText,
                            placeholder: Money.decimals(accCur) > 0 ? "0.00" : "0", focus: $amountFocused)

                if !isPayLike {
                    PillSegmented(items: typeItems(e), selection: typeBinding)
                        .padding(.bottom, 4)
                    Text(isPay ? "Pagas lo que debes. No es un gasto." : (isOut ? "Dinero que sale. Cuenta en tu presupuesto." : "Dinero que entra. Suma a tus ingresos."))
                        .font(.inter(13)).foregroundStyle(.secondary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .padding(.top, 8).padding(.bottom, 14).padding(.horizontal, 12)
                    if isOut && !isPay { ChipRow(items: e.categoryNames, selection: $category) }
                }

                SCard {
                    if isPay { payRows(e) }
                    if !isPay { SRow(symbol: "creditcard", label: "Cuenta") {
                        Menu {
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
                        } label: {
                            Text(selectedAccountLabel(e)).foregroundStyle(.primary).lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } }
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
                                                .background(Color(light: "#E5E5EA", dark: "#12301F"), in: Capsule())
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
                        Text(Self.dateText(date))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .overlay {
                                DatePicker(selection: $date, in: ...Date(), displayedComponents: .date) { Text("Fecha") }
                                    .labelsHidden()
                                    .colorMultiply(.clear)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                    }
                }

                if let tx = editedTx, Engine.text(tx["src"]) == "watch" {
                    Label("Anotado desde el Apple Watch", systemImage: "applewatch")
                        .font(.inter(13)).foregroundStyle(.secondary).padding(.bottom, 10)
                }

                if let errorText {
                    Text(errorText).font(.inter(14)).foregroundStyle(Brand.lossText).padding(.bottom, 10)
                }

                Button(editedTx == nil ? "Añadir" : "Guardar") { save(e) }
                    .buttonStyle(PrimaryPillStyle())
                    .padding(.bottom, 8)
                if editedTx == nil {
                    Button {
                        dismiss()
                        Task { try? await Task.sleep(for: .milliseconds(400)); model.importAtCapture = false; model.showImport = true }
                    } label: {
                        Label(Tr.t("Importar datos"), systemImage: "square.and.arrow.down")
                            .font(.inter(17)).foregroundStyle(Brand.green).frame(maxWidth: .infinity).padding(.vertical, 10)
                    }
                    .buttonStyle(.plain).padding(.bottom, 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .fitSheet()
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(38)
        .presentationBackground(Brand.sheetBg)
        .onAppear(perform: load)
        .tourSheetTip(active: editedTx == nil)
        .alert("Estás pagando más de lo que debes", isPresented: Binding(get: { overpay != nil }, set: { if !$0 { overpay = nil } })) {
            if let owed = overpay {
                if owed > 0.005 { Button("Pagar solo " + f.exact(owed, e.accountCurrency(.string(card)))) { finishPay(owed) } }
                Button(owed > 0.005 ? "Registrar el pago completo" : "Registrar de todos modos") { finishPay(parsedAmount() ?? 0) }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            if let owed = overpay {
                let cur = e.accountCurrency(.string(card))
                let name = e.allCards.first(where: { Engine.text($0["id"]) == card }).map { Engine.text($0["name"]) } ?? ""
                Text(verbatim: owed > 0.005
                     ? Tr.f("En Plata debes {0} en {1} y estás pagando {2}. Si es por intereses, registra el pago completo.", f.exact(owed, cur), name, f.exact(parsedAmount() ?? 0, cur))
                     : Tr.f("{0} ya está en 0. ¿Seguro que quieres registrar este pago?", name))
            }
        }
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

    private func selectedAccountLabel(_ e: Engine) -> String {
        for a in e.allAccounts + e.allCards where Engine.text(a["id"]) == account { return accountLabel(a) }
        return ""
    }

    private static func dateText(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return "\(c.day ?? 1) \(Spanish.monthsShort[(c.month ?? 1) - 1]) \(c.year ?? 2000)"
    }

    private func accountLabel(_ a: JSONValue) -> String {
        var s = Engine.text(a["name"])
        let l4 = Engine.text(a["last4"])
        if !l4.isEmpty { s += " · ● " + l4 }
        return s + " · " + Engine.text(a["cur"])
    }

    // MARK: pago de crédito

    private func typeItems(_ e: Engine) -> [(String, String)] {
        var items: [(String, String)] = [("out", "Gasto"), ("in", "Ingreso")]
        if editedTx == nil && !e.allCards.isEmpty { items.append(("pay", "Pago de crédito")) }
        return items
    }

    private var typeBinding: Binding<String> {
        Binding(get: { isPay ? "pay" : (isOut ? "out" : "in") }, set: { t in
            isPay = t == "pay"
            if !isPay { isOut = t == "out" }
            if isPay, card.isEmpty { card = Engine.text(model.engine.allCards.first?["id"]) }
            if isPay { autoOn = false }
        })
    }

    @ViewBuilder
    private func payRows(_ e: Engine) -> some View {
        let k = e.allCards.first(where: { Engine.text($0["id"]) == card })
        let ok = Engine.number(k?["due_day"]) > 0
        SRow(symbol: "creditcard", label: "Tarjeta o préstamo") {
            Menu {
                Picker("Tarjeta", selection: $card) {
                    ForEach(Array(e.allCards.enumerated()), id: \.offset) { _, a in Text(accountLabel(a)).tag(Engine.text(a["id"])) }
                }
            } label: {
                Text(k.map(accountLabel) ?? "").foregroundStyle(.primary).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        RowDivider()
        SRow(symbol: "creditcard", label: "Pagar desde") {
            Menu {
                Picker("Desde", selection: $from) {
                    Text("Sin descontar de una cuenta").tag("")
                    ForEach(Array(e.allAccounts.enumerated()), id: \.offset) { _, a in Text(accountLabel(a)).tag(Engine.text(a["id"])) }
                }
            } label: {
                Text(from.isEmpty ? "Sin descontar de una cuenta" : (e.allAccounts.first(where: { Engine.text($0["id"]) == from }).map(accountLabel) ?? ""))
                    .foregroundStyle(.primary).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        RowDivider()
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Pago esperado").font(.inter(17))
                Text(ok ? "El día \(Int(Engine.number(k?["due_day"]))) de cada mes te preguntamos cuánto pagaste." : "Disponible si la tarjeta tiene día de pago.")
                    .font(.inter(13)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: Binding(get: { autoOn && ok }, set: { autoOn = $0 })).labelsHidden().tint(Brand.accent).disabled(!ok)
        }
        .padding(.vertical, 12)
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
            account = presetAccount ?? Engine.text(e.allAccounts.first?["id"])
            amountFocused = true
        }
    }

    private func trimmed(_ n: Double) -> String {
        n == n.rounded() ? String(Int64(n)) : String(n)
    }

    private func parsedAmount() -> Double? {
        Double(amountText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
    }

    private func finishPay(_ amount: Double) {
        do {
            try model.registerCardPayment(card: card, amount: amount, from: from, date: LocalDate.today(now: date), note: note, auto: autoOn)
            dismiss()
        } catch { errorText = "No se pudo registrar el pago." }
    }

    private func save(_ e: Engine) {
        guard let amount = parsedAmount(), amount > 0 else { errorText = "Escribe un monto."; return }
        if isPay && editedTx == nil {
            guard let k = e.allCards.first(where: { Engine.text($0["id"]) == card }) else { errorText = "Elige una tarjeta o préstamo."; return }
            let owed = max(0, Engine.number(k["balance"]))
            if amount <= owed + 0.005 { finishPay(amount) } else { overpay = owed }
            return
        }
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
