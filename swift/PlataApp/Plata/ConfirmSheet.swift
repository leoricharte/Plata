import SwiftUI
import PlataCore

/// «¿Llegó tu ingreso?» / «¿Se cobró este gasto?» / «¿Pagaste tu tarjeta?» (`confirmHTML` de la web).
/// Sin `pick` va mostrando los pendientes uno a uno; con `pick` muestra solo el que se tocó.
struct ConfirmSheet: View {
    let kind: String
    let id: String
    let pick: Bool
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private struct Target { var kind: String; var id: String; var date: String; var count: Int }

    private func target() -> Target? {
        let e = model.engine
        if pick {
            if kind == "pay" {
                guard let c = e.allCards.first(where: { Engine.identifier($0["id"]) == id }), let auto = c["auto"], Engine.flag(auto) else { return nil }
                return Target(kind: kind, id: id, date: Engine.text(auto["next"]), count: 1)
            }
            let coll = kind == "out" ? e.allExpenseItems : e.allIncomeItems
            guard let x = coll.first(where: { Engine.identifier($0["id"]) == id }) else { return nil }
            return Target(kind: kind, id: id, date: Engine.text(x["date"]), count: 1)
        }
        let l = e.pendingItems()
        guard let f = l.first else { return nil }
        return Target(kind: f.kind, id: f.id, date: f.date, count: l.count)
    }

    var body: some View {
        if let t = target() {
            ConfirmBody(kind: t.kind, id: t.id, pick: pick, count: t.count)
                .id(t.kind + t.id + t.date)
        } else {
            Color.clear.onAppear { dismiss() }
        }
    }
}

private struct ConfirmBody: View {
    let kind: String
    let id: String
    let pick: Bool
    let count: Int
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var loaded = false
    @State private var amountText = ""
    @State private var hoursText = ""
    @State private var from = ""
    @State private var errorText: String?
    @State private var overpay: Double?
    @FocusState private var focus: Bool

    private func num(_ t: String) -> Double { Double(t.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)) ?? 0 }
    private func input(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(v) }

    private func when(_ iso: String) -> String {
        guard let d = LocalDate(iso: iso) else { return iso }
        let late = model.today.days - d.days
        if late < 0 { return "para " + Spanish.dateShort(d) }
        return late == 0 ? "hoy" : late == 1 ? "ayer" : "hace \(late) días"
    }

    var body: some View {
        let e = model.engine
        let f = model.fmt
        ScrollView {
            VStack(spacing: 0) {
                if kind == "pay", let c = card(e) { payContent(e, f, c) } else if let x = item(e) { itemContent(e, f, x) }
            }
            .padding(.horizontal, 16).padding(.top, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .fitSheet().presentationDragIndicator(.visible).presentationCornerRadius(38)
        .presentationBackground(Color(light: "#F4F4F8", dark: "#1C1C1E"))
        .onAppear { load(e) }
        .alert("Estás pagando más de lo que debes", isPresented: Binding(get: { overpay != nil }, set: { if !$0 { overpay = nil } })) {
            if let owed = overpay, let c = card(e) {
                if owed > 0.005 { Button("Pagar solo " + f.exact(owed, Engine.text(c["cur"]))) { payCard(owed) } }
                Button(owed > 0.005 ? "Registrar el pago completo" : "Registrar de todos modos") { payCard(num(amountText)) }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            if let owed = overpay, let c = card(e) {
                let cur = Engine.text(c["cur"])
                Text(verbatim: owed > 0.005
                     ? Tr.f("En Plata debes {0} en {1} y estás pagando {2}. Si es por intereses, registra el pago completo.", f.exact(owed, cur), Engine.text(c["name"]), f.exact(num(amountText), cur))
                     : Tr.f("{0} ya está en 0. ¿Seguro que quieres registrar este pago?", Engine.text(c["name"])))
            }
        }
    }

    // MARK: datos

    private func card(_ e: Engine) -> JSONValue? { e.allCards.first(where: { Engine.identifier($0["id"]) == id }) }
    private func item(_ e: Engine) -> JSONValue? {
        (kind == "out" ? e.allExpenseItems : e.allIncomeItems).first(where: { Engine.identifier($0["id"]) == id })
    }
    private func isFinal(_ c: JSONValue) -> Bool {
        let p = Engine.number(c["payment"]), b = Engine.number(c["balance"])
        return p > 0 && b > 0.005 && b <= p + 0.005
    }

    private func load(_ e: Engine) {
        guard !loaded else { return }
        loaded = true
        if kind == "pay", let c = card(e) {
            let cur = Engine.text(c["cur"])
            amountText = isFinal(c) ? String(format: "%.\(Money.decimals(cur))f", Engine.number(c["balance"])) : ""
            from = Engine.text(c["auto"]?["from"])
        } else if let x = item(e) {
            amountText = input(Engine.number(e.effectiveItem(kind == "out" ? "exp" : "in", x)["amount"]))
            if let j = e.jobOf(x), Engine.text(j["mode"]) != "s" { hoursText = input(Engine.jobHours(j)) }
        }
    }

    // MARK: contenido

    @ViewBuilder
    private func payContent(_ e: Engine, _ f: Fmt, _ c: JSONValue) -> some View {
        let cur = Engine.text(c["cur"])
        let loan = Engine.text(c["kind"]) == "loan"
        SheetHead(title: loan ? "¿Pagaste tu préstamo?" : "¿Pagaste tu tarjeta?", onClose: { dismiss() }, onSave: { tapPay(c) })
        AmountField(symbol: f.symbol(cur).trimmingCharacters(in: .whitespaces), text: $amountText,
                    placeholder: Money.decimals(cur) > 0 ? "0.00" : "0", focus: $focus, label: (header(Engine.text(c["name"]) + " · día de pago " + when(Engine.text(c["auto"]?["next"])))))
        Text(isFinal(c) ? "Última cuota · es lo que te queda" : "¿Cuánto pagaste?")
            .font(.inter(13, .semibold)).foregroundStyle(.secondary).padding(.bottom, 14)
        SCard {
            SRow(symbol: "creditcard", label: "Pagar desde") {
                Menu {
                    Picker("", selection: $from) {
                        Text("Sin descontar de una cuenta").tag("")
                        ForEach(Array(e.allAccounts.enumerated()), id: \.offset) { _, a in Text(accLabel(a)).tag(Engine.text(a["id"])) }
                    }
                } label: {
                    Text(from.isEmpty ? "Sin descontar de una cuenta" : e.allAccounts.first(where: { Engine.text($0["id"]) == from }).map(accLabel) ?? "")
                        .foregroundStyle(.primary).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        footer(confirm: { tapPay(c) }, later: "Aún no pagué")
    }

    @ViewBuilder
    private func itemContent(_ e: Engine, _ f: Fmt, _ x: JSONValue) -> some View {
        let out = kind == "out"
        let cur = e.accountCurrency(x["acc"])
        let pcd = out ? e.paymentCard(x) : nil
        let eff = Engine.number(e.effectiveItem(out ? "exp" : "in", x)["amount"])
        let job = out ? nil : e.jobOf(x)
        let title = pcd != nil ? (Engine.text(pcd?["kind"]) == "loan" ? "¿Pagaste tu préstamo?" : "¿Pagaste tu tarjeta?") : (out ? "¿Se cobró este gasto?" : "¿Llegó tu ingreso?")
        let label = Engine.text(x["name"]) + " · " + (out ? "previsto " : "esperado ") + when(Engine.text(x["date"]))
        SheetHead(title: (title), onClose: { dismiss() }, onSave: { tapItem(e) })
        AmountField(symbol: f.symbol(cur).trimmingCharacters(in: .whitespaces), text: $amountText,
                    placeholder: "0", focus: $focus, label: (header(label)))
        deltaChip(f, cur, amount: num(amountText), expected: eff, out: out)
        if let job, Engine.text(job["mode"]) != "s" {
            let hrs = num(hoursText)
            SCard {
                FieldRow(symbol: "clock", label: "Horas trabajadas", placeholder: "0", text: $hoursText, numeric: true)
                RowDivider()
                SRow(symbol: "percent", label: "Impuestos descontados") {
                    Text(taxText(Engine.taxPercent(amount: num(amountText), rate: Engine.number(job["rate"]), hours: hrs))).font(.inter(17))
                }
            }
        }
        SCard {
            SRow(symbol: "calendar", label: "Previsto") {
                HStack {
                    Text(f.exact(eff, cur)).font(.inter(17))
                    Spacer(minLength: 8)
                    Text(Engine.flag(x["repeat"]) ? "Se repite " + Engine.repeatLabel(x["repeat"]) + untilText(x) : "Una sola vez")
                        .font(.inter(13, .semibold)).foregroundStyle(.secondary)
                }
            }
        }
        footer(confirm: { tapItem(e) }, later: pcd != nil ? "Aún no pagué" : out ? "Aún no se cobró" : "Aún no llegó")
    }

    private func header(_ s: String) -> String { count > 1 && !pick ? s + " · 1 de \(count)" : s }

    private func untilText(_ x: JSONValue) -> String {
        guard let u = LocalDate(iso: Engine.text(x["until"])) else { return "" }
        return " · hasta \(u.day) \(Spanish.monthsShort[u.month0])"
    }

    private func taxText(_ v: Double) -> String { (v == v.rounded() ? String(Int(v)) : String(v)) + "%" }

    private func accLabel(_ a: JSONValue) -> String {
        var s = Engine.text(a["name"])
        let l4 = Engine.text(a["last4"])
        if !l4.isEmpty { s += " · ● " + l4 }
        return s + " · " + Engine.text(a["cur"])
    }

    @ViewBuilder
    private func deltaChip(_ f: Fmt, _ cur: String, amount: Double, expected: Double, out: Bool) -> some View {
        let d = Engine.roundCents(amount - expected)
        if abs(d) < 0.005 {
            Text("Igual a lo previsto").font(.inter(13, .semibold)).foregroundStyle(.secondary).padding(.bottom, 14)
        } else {
            Text((d > 0 ? "+" : "−") + f.exact(abs(d), cur) + " vs. previsto").font(.inter(13, .semibold))
                .foregroundStyle((d > 0) != out ? Brand.gainText : Brand.lossText).padding(.bottom, 14)
        }
    }

    @ViewBuilder
    private func footer(confirm: @escaping () -> Void, later: String) -> some View {
        if let errorText { Text(errorText).font(.inter(14)).foregroundStyle(Brand.lossText).padding(.bottom, 10) }
        Button("Confirmar", action: confirm).buttonStyle(PrimaryPillStyle()).padding(.bottom, 8)
        Button(pick ? "Cancelar" : later) {
            if pick { dismiss() } else { model.snoozePending(kind: kind, id: id) }
        }
        .buttonStyle(SecondaryPillStyle()).padding(.bottom, 8)
    }

    // MARK: acciones

    private func tapItem(_ e: Engine) {
        let amt = num(amountText)
        guard amt > 0 else { errorText = "Escribe el monto."; return }
        do {
            try model.confirmExpected(kind: kind, id: id, amount: amt, hours: num(hoursText))
            if pick { dismiss() }
        } catch { errorText = "No se pudo confirmar." }
    }

    private func tapPay(_ c: JSONValue) {
        let amt = num(amountText)
        guard amt > 0 else { errorText = "Escribe cuánto pagaste."; return }
        let owed = max(0, Engine.number(c["balance"]))
        if amt > owed + 0.005 { overpay = owed } else { payCard(amt) }
    }

    private func payCard(_ amt: Double) {
        do {
            try model.confirmCardPay(id: id, amount: amt, from: from)
            if pick { dismiss() }
        } catch { errorText = "No se pudo registrar el pago." }
    }
}
