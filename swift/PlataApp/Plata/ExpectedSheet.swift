import SwiftUI
import PlataCore

/// Ingreso o gasto previsto (`FORMS.income` / `FORMS.expense` de la web).
struct ExpectedSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let kind: String          // "income" | "expense"
    let id: String?

    @State private var loaded = false
    @State private var name = ""
    @State private var amountText = ""
    @State private var repeatKey = "0"
    @State private var account = ""
    @State private var category = "Otros"
    @State private var date = Date()
    @State private var until: Date?
    @State private var q1 = ""
    @State private var q2 = ""
    @State private var original: JSONValue?
    @State private var errorText: String?
    @State private var confirmDelete = false
    @FocusState private var amountFocused: Bool

    private var isIncome: Bool { kind == "income" }
    private var collection: String { isIncome ? "expected_income" : "expected_expense" }

    var body: some View {
        let e = model.engine
        let f = model.fmt
        let cur = e.accountCurrency(.string(account))
        ScrollView {
            VStack(spacing: 0) {
                SheetHead(title: LocalizedStringKey(isIncome ? "Ingreso previsto" : "Gasto previsto"), onClose: { dismiss() }, onSave: { save() })
                AmountField(symbol: f.symbol(cur).trimmingCharacters(in: .whitespaces), text: $amountText,
                            placeholder: Money.decimals(cur) > 0 ? "0.00" : "0", focus: $amountFocused, label: "Monto previsto")
                PillSegmented(items: [("0", "Una vez"), ("7", "Semanal"), ("14", "14 días"), ("q", "Quincenal"), ("m", "Mensual")], selection: $repeatKey)
                    .padding(.bottom, 10)

                SCard {
                    FieldRow(symbol: "pencil", label: "Nombre", placeholder: "Nombre", text: $name)
                    RowDivider()
                    SRow(symbol: "creditcard", label: LocalizedStringKey(isIncome ? "Cuenta" : "Cuenta o tarjeta")) {
                        Menu {
                            Picker("", selection: $account) {
                                Section("Débito") {
                                    ForEach(Array(e.allAccounts.enumerated()), id: \.offset) { _, a in Text(label(a)).tag(Engine.text(a["id"])) }
                                }
                                if !isIncome && !e.allCards.isEmpty {
                                    Section("Crédito") {
                                        ForEach(Array(e.allCards.enumerated()), id: \.offset) { _, a in Text(label(a)).tag(Engine.text(a["id"])) }
                                    }
                                }
                            }
                        } label: {
                            Text(selectedLabel(e)).foregroundStyle(.primary).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    if !isIncome {
                        RowDivider()
                        SRow(symbol: "square.grid.2x2", label: "Categoría") {
                            Menu {
                                Picker("", selection: $category) { ForEach(e.categoryNames, id: \.self) { Text($0).tag($0) } }
                            } label: {
                                Text(category).foregroundStyle(.primary).frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    RowDivider()
                    DateRow(symbol: "calendar", label: "Fecha", date: $date)
                    if repeatKey == "q" {
                        RowDivider()
                        FieldRow(symbol: "1.circle", label: "Día del primer pago", placeholder: "0", text: $q1, numeric: true)
                        RowDivider()
                        FieldRow(symbol: "2.circle", label: "Día del segundo pago", placeholder: "0", text: $q2, numeric: true)
                    }
                    if repeatKey != "0" {
                        RowDivider()
                        OptionalDateRow(symbol: "calendar", label: "Termina el (opcional)", date: $until)
                    }
                }

                if let errorText { Text(errorText).font(.inter(14)).foregroundStyle(Brand.lossText).padding(.bottom, 10) }
                Button("Guardar") { save() }.buttonStyle(PrimaryPillStyle()).padding(.bottom, 8)
                if id != nil {
                    Button("Eliminar") { confirmDelete = true }
                        .buttonStyle(SecondaryPillStyle(destructive: true)).padding(.bottom, 8)
                }
            }
            .padding(.horizontal, 16).padding(.top, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(38)
        .presentationBackground(Color(light: "#F4F4F8", dark: "#1C1C1E"))
        .onAppear(perform: load)
        .confirmationDialog("¿Eliminar este \(isIncome ? "ingreso" : "gasto") previsto?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) {
                if let original { try? model.deleteExpected(collection: collection, id: original["id"] ?? .null) }
                dismiss()
            }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private func label(_ a: JSONValue) -> String {
        var s = Engine.text(a["name"])
        let l4 = Engine.text(a["last4"])
        if !l4.isEmpty { s += " · ● " + l4 }
        return s + " · " + Engine.text(a["cur"])
    }

    private func selectedLabel(_ e: Engine) -> String {
        for a in e.allAccounts + e.allCards where Engine.text(a["id"]) == account { return label(a) }
        return ""
    }

    private func num(_ t: String) -> Double { Double(t.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)) ?? 0 }
    private func isoOf(_ d: Date) -> String { LocalDate.today(now: d).iso }

    private func load() {
        guard !loaded else { return }
        loaded = true
        let e = model.engine
        if let id, let o = e.data[collection]?.arrayValue?.first(where: { Engine.identifier($0["id"]) == id }) {
            original = o
            name = Engine.text(o["name"])
            let a = Engine.number(o["amount"])
            amountText = a == a.rounded() ? String(Int64(a)) : String(a)
            account = Engine.text(o["acc"])
            category = e.categoryNames.contains(Engine.text(o["cat"])) ? Engine.text(o["cat"]) : "Otros"
            if let d = LocalDate(iso: Engine.text(o["date"])) { date = d.date() }
            if let u = LocalDate(iso: Engine.text(o["until"])) { until = u.date() }
            if let r = o["repeat"], Engine.isRepeatQuincenal(r) {
                repeatKey = "q"
                let d = Engine.quincenalDays(r)
                q1 = String(d.0); q2 = String(d.1)
            } else if o["repeat"] == .string("m") {
                repeatKey = "m"
            } else {
                let n = Int(Engine.number(o["repeat"]))
                repeatKey = n == 7 ? "7" : (n == 14 ? "14" : "0")
            }
        } else {
            account = Engine.text(e.allAccounts.first?["id"])
            category = "Otros"
            amountFocused = true
        }
    }

    private func save() {
        let amt = num(amountText)
        guard amt > 0 else { errorText = "Escribe un monto."; return }
        let e = model.engine
        var o: JSONValue = original ?? .object([:])
        if original == nil {
            o["id"] = .string(String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6)).lowercased())
        }
        o["name"] = .string(name)
        o["amount"] = .number(amt)
        o["acc"] = .string(account)
        o["date"] = .string(isoOf(date))
        o["repeat"] = .string(repeatKey)
        o["until"] = .string(until.map(isoOf) ?? "")
        if repeatKey == "q" { o["q1"] = .number(num(q1)); o["q2"] = .number(num(q2)) }
        if !isIncome { o["cat"] = .string(category) }
        _ = e
        do {
            try model.saveExpected(collection: collection, item: o)
            dismiss()
        } catch ProfileEditor.FormError.missingName { errorText = "Escribe un nombre."
        } catch ProfileEditor.FormError.invalidDays { errorText = "Escribe los días de pago (del 1 al 31)."
        } catch ProfileEditor.FormError.endBeforeStart { errorText = "El fin debe ser posterior a la fecha."
        } catch { errorText = "No se pudo guardar." }
    }
}
