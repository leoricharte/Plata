import SwiftUI
import PlataCore

/// «Editar este evento»: cambia el monto o la fecha de un solo evento de la serie, lo omite o lo restaura (`openEv` de la web).
struct EventSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let key: String

    @State private var loaded = false
    @State private var amount = ""
    @State private var date = Date()
    @State private var errorText: String?
    @FocusState private var focus: Bool

    private static let seriesTitle = ["income": "serie del ingreso", "expense": "serie del gasto", "cardpay": "serie del pago", "sub": "suscripción", "debt": "tarjeta o préstamo"]

    private var entry: TimelineEntry? { model.engine.projection().timeline.first { $0.key == key } }
    private var d0: String { String(key.split(separator: ":").last ?? "") }
    private var stored: JSONValue? { model.profile.raw["ovr"]?[key] }

    var body: some View {
        let f = model.fmt
        let cur = entry?.cur ?? model.engine.primaryCurrency
        let skipped = Engine.flag(stored?["skip"])
        let had = stored.map { Engine.flag($0) } ?? false
        ScrollView {
            VStack(spacing: 0) {
                SheetHead(title: "Editar este evento", onClose: { dismiss() }, onSave: { save() })
                AmountField(symbol: f.symbol(cur).trimmingCharacters(in: .whitespaces), text: $amount,
                            placeholder: Money.decimals(cur) > 0 ? "0.00" : "0", focus: $focus, label: (entry?.name ?? ""))
                SCard { DateRow(symbol: "calendar", label: "Fecha de este evento", date: $date) }
                Text("Solo cambia este evento; el resto de la serie sigue igual.")
                    .font(.inter(13)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8).padding(.bottom, 10)
                if let errorText { Text(errorText).font(.inter(14)).foregroundStyle(Brand.lossText).padding(.bottom, 10) }
                Button("Guardar") { save() }.buttonStyle(PrimaryPillStyle()).padding(.bottom, 8)
                if !skipped {
                    Button("Omitir este evento") { model.setEventOverride(key: key, entry: .object(["skip": .bool(true)])); dismiss() }
                        .buttonStyle(SecondaryPillStyle()).padding(.bottom, 8)
                }
                if had {
                    Button("Restaurar el original") { model.setEventOverride(key: key, entry: nil); dismiss() }
                        .buttonStyle(SecondaryPillStyle()).padding(.bottom, 8)
                }
                if let form = entry?.form, let title = Self.seriesTitle[form] {
                    Button("Editar toda la \(title)") { openSeries(form) }.buttonStyle(SecondaryPillStyle()).padding(.bottom, 8)
                }
            }
            .padding(.horizontal, 16).padding(.top, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .presentationDetents([.large]).presentationDragIndicator(.visible).presentationCornerRadius(38)
        .presentationBackground(Color(light: "#F4F4F8", dark: "#1C1C1E"))
        .onAppear(perform: load)
    }

    private func num(_ t: String) -> Double { Double(t.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)) ?? 0 }

    private func load() {
        guard !loaded, let entry else { return }
        loaded = true
        let a0 = abs(entry.a0)
        let x = stored
        let amt = x?["amt"].flatMap { $0.isNull ? nil : Engine.number($0) } ?? a0
        amount = amt == amt.rounded() ? String(Int64(amt)) : String(amt)
        let iso = Engine.text(x?["date"]).isEmpty ? d0 : Engine.text(x?["date"])
        date = (LocalDate(iso: iso) ?? model.today).date()
    }

    private func save() {
        let a0 = abs(entry?.a0 ?? 0)
        let amt = num(amount)
        guard amt > 0 else { errorText = "Escribe un monto."; return }
        let iso = LocalDate.today(now: date).iso
        guard iso > model.today.iso else { errorText = "Elige una fecha futura."; return }
        var e: [String: JSONValue] = [:]
        if abs(amt - a0) > 0.0049 { e["amt"] = .number(Engine.roundCents(amt)) }
        if iso != d0 { e["date"] = .string(iso) }
        model.setEventOverride(key: key, entry: e.isEmpty ? nil : .object(e))
        dismiss()
    }

    private func openSeries(_ form: String) {
        guard let id = entry?.srcId else { return }
        let sheet: ActiveSheet
        switch form {
        case "income", "expense", "cardpay": sheet = .expected(kind: form, id: id)
        case "sub": sheet = .sub(id: id)
        default: sheet = .debt(id: id)
        }
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { model.activeSheet = sheet }
    }
}
