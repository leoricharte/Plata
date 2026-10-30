import SwiftUI
import PlataCore

/// Simular un gasto o un pago de crédito (`FORMS.sim` de la web). El monto se escribe en la moneda principal y se guarda en USD.
struct PlannedSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let id: String?

    @State private var loaded = false
    @State private var kind = "out"
    @State private var name = ""
    @State private var amountText = ""
    @State private var date = Date()
    @State private var until: Date?
    @State private var card = ""
    @State private var category = "Otros"
    @State private var account = ""
    @State private var on = true
    @State private var original: JSONValue?
    @State private var errorText: String?
    @State private var confirmDelete = false
    @FocusState private var amountFocused: Bool

    var body: some View {
        let e = model.engine
        let f = model.fmt
        let pcur = e.primaryCurrency
        let isPay = kind == "pay"
        ScrollView {
            VStack(spacing: 0) {
                SheetHead(title: id == nil ? "Simular gasto" : "Gasto simulado", onClose: { dismiss() }, onSave: { save() })
                AmountField(symbol: f.symbol(pcur).trimmingCharacters(in: .whitespaces), text: $amountText,
                            placeholder: Money.decimals(pcur) > 0 ? "0.00" : "0", focus: $amountFocused,
                            label: isPay ? "Pago simulado" : "Gasto simulado")
                if !e.allCards.isEmpty {
                    PillSegmented(items: [("out", "Gasto"), ("pay", "Pago de crédito")], selection: $kind).padding(.bottom, 10)
                }
                SCard {
                    FieldRow(symbol: "pencil", label: "Nombre", placeholder: "Nombre", text: $name)
                    RowDivider()
                    DateRow(symbol: "calendar", label: isPay ? "Fecha del pago" : "Fecha de la compra", date: $date)
                    RowDivider()
                    OptionalDateRow(symbol: "calendar", label: "Ver impacto hasta (opcional)", date: $until)
                    if isPay {
                        RowDivider()
                        SRow(symbol: "creditcard", label: "Tarjeta o préstamo") {
                            menu($card, e.allCards.map { (Engine.text($0["id"]), label($0)) })
                        }
                    } else {
                        RowDivider()
                        SRow(symbol: "square.grid.2x2", label: "Categoría al ejecutarlo") {
                            menu($category, e.categoryNames.map { ($0, $0) })
                        }
                    }
                    RowDivider()
                    SRow(symbol: "creditcard", label: isPay ? "Pagar desde (monto en \(pcur))" : "Cuenta al ejecutarlo (monto en \(pcur))") {
                        menu($account, (isPay ? e.allAccounts : e.allAccounts + e.allCards).map { (Engine.text($0["id"]), label($0)) })
                    }
                }

                if let errorText { Text(errorText).font(.inter(14)).foregroundStyle(Brand.lossText).padding(.bottom, 10) }
                Button("Guardar") { save() }.buttonStyle(PrimaryPillStyle()).padding(.bottom, 8)
                if let original {
                    Button("Ejecutar") {
                        do { try model.executePlanned(merged(original)); dismiss() }
                        catch { errorText = "Escribe un monto." }
                    }.buttonStyle(SecondaryPillStyle()).padding(.bottom, 8)
                    Button("Eliminar") { confirmDelete = true }.buttonStyle(SecondaryPillStyle(destructive: true)).padding(.bottom, 8)
                }
            }
            .padding(.horizontal, 16).padding(.top, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .fitSheet()
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(38)
        .presentationBackground(Brand.sheetBg)
        .onAppear(perform: load)
        .alert("¿Eliminar este gasto simulado?", isPresented: $confirmDelete) {
            Button("Eliminar", role: .destructive) {
                if let original { try? model.deletePlanned(id: original["id"] ?? .null) }
                dismiss()
            }
            Button("Cancelar", role: .cancel) {}
        }
        .onChange(of: kind) { _, k in
            // un pago sale de una cuenta, no de una tarjeta
            if k == "pay", model.engine.allCards.contains(where: { Engine.text($0["id"]) == account }) {
                account = Engine.text(model.engine.allAccounts.first?["id"])
            }
        }
    }

    private func menu(_ sel: Binding<String>, _ items: [(String, String)]) -> some View {
        Menu {
            Picker("", selection: sel) { ForEach(Array(items.enumerated()), id: \.offset) { _, it in Text(it.1).tag(it.0) } }
        } label: {
            Text(items.first(where: { $0.0 == sel.wrappedValue })?.1 ?? "").foregroundStyle(.primary).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func label(_ a: JSONValue) -> String {
        var s = Engine.text(a["name"])
        let l4 = Engine.text(a["last4"])
        if !l4.isEmpty { s += " · ● " + l4 }
        return s + " · " + Engine.text(a["cur"])
    }

    private func num(_ t: String) -> Double { Double(t.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)) ?? 0 }
    private func isoOf(_ d: Date) -> String { LocalDate.today(now: d).iso }

    private func load() {
        guard !loaded else { return }
        loaded = true
        let e = model.engine
        if let id, let o = e.plannedList.first(where: { Engine.identifier($0["id"]) == id }) {
            original = o
            kind = Engine.text(o["kind"]) == "pay" ? "pay" : "out"
            name = Engine.text(o["name"])
            let a = e.fromUSD(abs(Engine.number(o["amount"])), e.primaryCurrency)
            amountText = a == a.rounded() ? String(Int64(a)) : String(Engine.roundCents(a))
            if let d = LocalDate(iso: Engine.text(o["date"])) { date = d.date() }
            if let d = LocalDate(iso: Engine.text(o["until"])) { until = d.date() }
            card = Engine.text(o["card"])
            category = e.categoryNames.contains(Engine.text(o["cat"])) ? Engine.text(o["cat"]) : "Otros"
            account = Engine.text(o["acc"])
            on = o["on"] != .bool(false)
        } else {
            date = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
            account = Engine.text(e.allAccounts.first?["id"])
            card = Engine.text(e.allCards.first?["id"])
            amountFocused = true
        }
    }

    private func merged(_ base: JSONValue) -> JSONValue {
        let e = model.engine
        var o = base
        o["kind"] = .string(kind)
        o["name"] = .string(name)
        o["amount"] = .number(Engine.roundCents(e.usd(num(amountText), e.primaryCurrency)))
        o["date"] = .string(isoOf(date))
        o["until"] = .string(until.map(isoOf) ?? "")
        o["on"] = .bool(on)
        o["acc"] = .string(account)
        if kind == "pay" { o["card"] = .string(card); o["cat"] = nil } else { o["cat"] = .string(category); o["card"] = nil }
        return o
    }

    private func save() {
        var o: JSONValue = original ?? .object(["id": .string(String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6)).lowercased())])
        o = merged(o)
        do {
            try model.savePlanned(o)
            dismiss()
        } catch ProfileEditor.FormError.missingName { errorText = "Escribe un nombre."
        } catch ProfileEditor.FormError.invalidAmount { errorText = "Escribe un monto."
        } catch ProfileEditor.FormError.missingCard { errorText = "Elige una tarjeta o préstamo."
        } catch { errorText = "No se pudo guardar." }
    }
}
