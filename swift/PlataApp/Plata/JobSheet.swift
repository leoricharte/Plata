import SwiftUI
import PlataCore

/// Trabajo (`FORMS.job` de la web): pago por hora (EE.UU.) o sueldo mensual (Perú).
struct JobSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let id: String?

    @State private var loaded = false
    @State private var mode = "h"
    @State private var name = ""
    @State private var rateText = ""
    @State private var freq = "b"
    @State private var q1 = ""
    @State private var q2 = ""
    @State private var hours = "40"
    @State private var tax = "15"
    @State private var account = ""
    @State private var start = Date()
    @State private var until: Date?
    @State private var sim = "0"
    @State private var original: JSONValue?
    @State private var errorText: String?
    @State private var confirmDelete = false
    @FocusState private var amountFocused: Bool

    var body: some View {
        let e = model.engine
        let f = model.fmt
        let cur = e.accountCurrency(.string(account))
        ScrollView {
            VStack(spacing: 0) {
                SheetHead(title: id == nil ? "Nuevo trabajo" : "Trabajo", onClose: { dismiss() }, onSave: { save() })
                AmountField(symbol: f.symbol(cur).trimmingCharacters(in: .whitespaces), text: $rateText,
                            placeholder: Money.decimals(cur) > 0 ? "0.00" : "0", focus: $amountFocused,
                            label: mode == "s" ? "Ingreso mensual estimado" : "Pago por hora")
                PillSegmented(items: [("h", "EE.UU."), ("s", "Perú")], selection: $mode).padding(.bottom, 10)
                PillSegmented(items: [("w", "Semanal"), ("b", "14 días"), ("q", "Quincenal"), ("m", "Mensual")], selection: $freq).padding(.bottom, 10)

                SCard {
                    FieldRow(symbol: "pencil", label: "Nombre del trabajo", placeholder: "Nombre", text: $name)
                    if freq == "q" {
                        RowDivider()
                        FieldRow(symbol: "1.circle", label: "Día del primer pago", placeholder: "0", text: $q1, numeric: true)
                        RowDivider()
                        FieldRow(symbol: "2.circle", label: "Día del segundo pago", placeholder: "0", text: $q2, numeric: true)
                    }
                    if mode != "s" {
                        RowDivider()
                        FieldRow(symbol: "clock", label: "Horas por semana", placeholder: "0", text: $hours, numeric: true)
                        RowDivider()
                        FieldRow(symbol: "percent", label: "Impuestos retenidos (%)", placeholder: "0", text: $tax, numeric: true)
                    }
                    RowDivider()
                    SRow(symbol: "creditcard", label: "Cuenta donde cae el pago") {
                        Menu {
                            Picker("", selection: $account) {
                                ForEach(Array(e.allAccounts.enumerated()), id: \.offset) { _, a in Text(label(a)).tag(Engine.text(a["id"])) }
                            }
                        } label: {
                            Text(e.allAccounts.first(where: { Engine.text($0["id"]) == account }).map(label) ?? "")
                                .foregroundStyle(.primary).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    RowDivider()
                    DateRow(symbol: "calendar", label: "Primer pago", date: $start)
                    RowDivider()
                    OptionalDateRow(symbol: "calendar", label: "Último pago (opcional)", date: $until)
                }
                PillSegmented(items: [("0", "Real"), ("1", "Solo simular")], selection: $sim).padding(.bottom, 14)

                if let errorText { Text(errorText).font(.inter(14)).foregroundStyle(Brand.lossText).padding(.bottom, 10) }
                Button("Guardar") { save() }.buttonStyle(PrimaryPillStyle()).padding(.bottom, 8)
                if id != nil {
                    Button("Eliminar") { confirmDelete = true }.buttonStyle(SecondaryPillStyle(destructive: true)).padding(.bottom, 8)
                }
            }
            .padding(.horizontal, 16).padding(.top, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .fitSheet()
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(38)
        .presentationBackground(Color(light: "#F4F4F8", dark: "#1C1C1E"))
        .onAppear(perform: load)
        .onChange(of: mode) { _, m in if id == nil { freq = m == "s" ? "m" : "b" } }
        .alert("¿Eliminar este trabajo?", isPresented: $confirmDelete) {
            Button("Eliminar", role: .destructive) {
                if let original { try? model.deleteJob(id: original["id"] ?? .null) }
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

    private func num(_ t: String) -> Double { Double(t.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)) ?? 0 }
    private func isoOf(_ d: Date) -> String { LocalDate.today(now: d).iso }
    private func clean(_ n: Double) -> String { n == n.rounded() ? String(Int64(n)) : String(n) }

    private func load() {
        guard !loaded else { return }
        loaded = true
        let e = model.engine
        if let id, let o = e.jobList.first(where: { Engine.identifier($0["id"]) == id }) {
            original = o
            mode = Engine.text(o["mode"]) == "s" ? "s" : "h"
            name = Engine.text(o["name"])
            rateText = clean(Engine.number(o["rate"]))
            freq = Engine.text(o["freq"]).isEmpty ? "b" : Engine.text(o["freq"])
            q1 = o["q1"] == nil ? "" : clean(Engine.number(o["q1"]))
            q2 = o["q2"] == nil ? "" : clean(Engine.number(o["q2"]))
            hours = clean(Engine.number(o["hours"]))
            tax = clean(Engine.number(o["tax"]))
            account = Engine.text(o["acc"])
            if let d = LocalDate(iso: Engine.text(o["start"])) { start = d.date() }
            if let d = LocalDate(iso: Engine.text(o["until"])) { until = d.date() }
            sim = Engine.flag(o["sim"]) ? "1" : "0"
        } else {
            account = Engine.text(e.allAccounts.first?["id"])
            if e.accountCurrency(.string(account)) == "PEN" { mode = "s"; freq = "m" }
            start = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
            amountFocused = true
        }
    }

    private func save() {
        var o: JSONValue = original ?? .object([:])
        o["mode"] = .string(mode)
        o["name"] = .string(name)
        o["rate"] = .number(num(rateText))
        o["freq"] = .string(freq)
        o["q1"] = .number(num(q1)); o["q2"] = .number(num(q2))
        o["hours"] = .number(num(hours)); o["tax"] = .number(num(tax))
        o["acc"] = .string(account)
        o["start"] = .string(isoOf(start))
        o["until"] = .string(until.map(isoOf) ?? "")
        o["sim"] = .number(sim == "1" ? 1 : 0)
        do {
            try model.saveJob(o)
            dismiss()
        } catch ProfileEditor.FormError.missingName { errorText = "Escribe un nombre."
        } catch ProfileEditor.FormError.invalidAmount { errorText = "Escribe un monto."
        } catch ProfileEditor.FormError.invalidDays { errorText = "Escribe los días de pago (del 1 al 31)."
        } catch ProfileEditor.FormError.invalidHours { errorText = "Escribe las horas por semana."
        } catch ProfileEditor.FormError.endBeforeStart { errorText = "El fin debe ser posterior al inicio."
        } catch { errorText = "No se pudo guardar." }
    }
}
