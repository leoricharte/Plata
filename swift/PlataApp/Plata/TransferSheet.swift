import SwiftUI
import PlataCore

/// Transferir entre cuentas (`xferHTML` de la web). No cuenta como gasto ni ingreso.
struct TransferSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var loaded = false
    @State private var from = ""
    @State private var to = ""
    @State private var amountText = ""
    @State private var recvText = ""
    @State private var recvEdited = false
    @State private var commText = ""
    @State private var note = ""
    @State private var date = Date()
    @State private var errorText: String?
    @FocusState private var amountFocused: Bool

    var body: some View {
        let e = model.engine
        let f = model.fmt
        let accounts = e.allAccounts
        let fromCur = e.accountCurrency(.string(from)), toCur = e.accountCurrency(.string(to))
        let diff = fromCur != toCur
        ScrollView {
            VStack(spacing: 0) {
                SheetHead(title: "Transferir", onClose: { dismiss() }, onSave: { save() })
                AmountField(symbol: f.symbol(fromCur).trimmingCharacters(in: .whitespaces), text: $amountText,
                            placeholder: Money.decimals(fromCur) > 0 ? "0.00" : "0", focus: $amountFocused)
                Text("No cuenta como gasto ni ingreso.").font(.inter(13)).foregroundStyle(.secondary)
                    .padding(.horizontal, 12).padding(.bottom, 14)

                SCard {
                    SRow(symbol: "creditcard", label: "Desde") { picker($from, accounts.filter { Engine.text($0["id"]) != to }) }
                    RowDivider()
                    SRow(symbol: "creditcard", label: "A") { picker($to, accounts.filter { Engine.text($0["id"]) != from }) }
                    if diff {
                        RowDivider()
                        SRow(symbol: "dollarsign.circle", label: "Recibes") {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(f.symbol(toCur).trimmingCharacters(in: .whitespaces)).font(.inter(17, .medium))
                                    TextField(Money.decimals(toCur) > 0 ? "0.00" : "0", text: Binding(get: { recvText }, set: { recvText = $0; recvEdited = true }))
                                        .keyboardType(.decimalPad)
                                }
                                Text(rateHint(e, fromCur, toCur)).font(.inter(13)).foregroundStyle(.secondary)
                            }
                        }
                    }
                    RowDivider()
                    FieldRow(symbol: "dollarsign.circle", label: "Comisión (opcional)", placeholder: "0", text: $commText, numeric: true,
                             prefix: f.symbol(fromCur).trimmingCharacters(in: .whitespaces))
                    RowDivider()
                    FieldRow(symbol: "pencil", label: "Nota", placeholder: "Opcional", text: $note)
                    RowDivider()
                    DateRow(symbol: "calendar", label: "Fecha", date: $date, maxToday: true)
                }

                if let errorText { Text(errorText).font(.inter(14)).foregroundStyle(Brand.lossText).padding(.bottom, 10) }
                Button("Transferir") { save() }.buttonStyle(PrimaryPillStyle()).padding(.bottom, 8)
            }
            .padding(.horizontal, 16).padding(.top, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(38)
        .presentationBackground(Color(light: "#F4F4F8", dark: "#1C1C1E"))
        .onAppear(perform: load)
        .onChange(of: amountText) { _, _ in syncRecv() }
        .onChange(of: from) { _, new in
            if to == new { to = Engine.text(model.engine.allAccounts.first(where: { Engine.text($0["id"]) != new })?["id"]) }
            recvEdited = false; syncRecv()
        }
        .onChange(of: to) { _, new in
            if from == new { from = Engine.text(model.engine.allAccounts.first(where: { Engine.text($0["id"]) != new })?["id"]) }
            recvEdited = false; syncRecv()
        }
    }

    private func picker(_ selection: Binding<String>, _ list: [JSONValue]) -> some View {
        Menu {
            Picker("", selection: selection) {
                ForEach(Array(list.enumerated()), id: \.offset) { _, a in Text(label(a)).tag(Engine.text(a["id"])) }
            }
        } label: {
            Text(list.first(where: { Engine.text($0["id"]) == selection.wrappedValue }).map(label) ?? "")
                .foregroundStyle(.primary).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func label(_ a: JSONValue) -> String {
        var s = Engine.text(a["name"])
        let l4 = Engine.text(a["last4"])
        if !l4.isEmpty { s += " · ● " + l4 }
        return s + " · " + Engine.text(a["cur"])
    }

    private func num(_ t: String) -> Double { Double(t.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)) ?? 0 }

    private func rateHint(_ e: Engine, _ f: String, _ t: String) -> String {
        let amt = num(amountText), rc = num(recvText)
        if amt > 0, rc > 0, recvEdited {
            let rt = rc / amt
            func rn(_ v: Double) -> String { (round(v * 10000) / 10000).formatted() }
            return "Tipo de cambio: " + (rt >= 1 ? "1 \(f) = \(rn(rt)) \(t)" : "1 \(t) = \(rn(1 / rt)) \(f)")
        }
        return "Estimado con el cambio de la app. Corrígelo si recibiste otro monto."
    }

    private func syncRecv() {
        let e = model.engine
        let fromCur = e.accountCurrency(.string(from)), toCur = e.accountCurrency(.string(to))
        guard fromCur != toCur, !recvEdited else { return }
        let amt = num(amountText)
        recvText = amt > 0 ? String(format: "%.\(Money.decimals(toCur))f", e.convert(amt, from: fromCur, to: toCur)) : ""
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        let a = model.engine.allAccounts
        from = Engine.text(a.first?["id"])
        to = Engine.text(a.dropFirst().first?["id"])
        amountFocused = true
    }

    private func save() {
        let e = model.engine
        let amt = num(amountText)
        guard amt > 0 else { errorText = "Escribe un monto."; return }
        let fromCur = e.accountCurrency(.string(from)), toCur = e.accountCurrency(.string(to))
        var recv = amt
        if fromCur != toCur { recv = num(recvText); if !(recv > 0) { recv = e.convert(amt, from: fromCur, to: toCur) } }
        do {
            try model.addTransfer(from: from, to: to, amount: amt, received: recv, commission: num(commText), note: note, date: LocalDate.today(now: date))
            dismiss()
        } catch ProfileEditor.FormError.sameAccount {
            errorText = "Elige dos cuentas distintas."
        } catch {
            errorText = "No se pudo registrar la transferencia."
        }
    }
}
