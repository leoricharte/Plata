import SwiftUI
import PlataCore

/// Meta de ahorro nueva o existente (`FORMS.saving`), y aporte a una meta (`FORMS.contrib`).
struct SavingSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let id: String?

    @State private var loaded = false
    @State private var name = ""
    @State private var goalText = ""
    @State private var balanceText = ""
    @State private var monthlyText = ""
    @State private var cur = ""
    @State private var color = ""
    @State private var icon = ""
    @State private var iconUser = false
    @State private var colorUser = false
    @State private var original: JSONValue?
    @State private var errorText: String?
    @State private var confirmDelete = false
    @FocusState private var goalFocused: Bool

    var body: some View {
        let e = model.engine
        let f = model.fmt
        let curs = currencies(e)
        ScrollView {
            VStack(spacing: 0) {
                SheetHead(title: id == nil ? "Nueva meta" : "Meta de ahorro", onClose: { dismiss() }, onSave: { save() })
                AmountField(symbol: f.symbol(cur).trimmingCharacters(in: .whitespaces), text: $goalText,
                            placeholder: Money.decimals(cur) > 0 ? "0.00" : "0", focus: $goalFocused, label: "Meta")
                if curs.count > 1 {
                    PillSegmented(items: curs.map { ($0, LocalizedStringKey($0)) }, selection: $cur).padding(.bottom, 10)
                }
                SCard {
                    FieldRow(symbol: "pencil", label: "Nombre", placeholder: "Nombre", text: $name)
                    RowDivider()
                    FieldRow(symbol: "leaf", label: "Ahorrado hasta la fecha", placeholder: "0", text: $balanceText, numeric: true)
                    RowDivider()
                    FieldRow(symbol: "plus.circle", label: "Aporte mensual", placeholder: "0", text: $monthlyText, numeric: true)
                }
                StylePicker(color: $color, icon: $icon, iconUser: $iconUser, colorUser: $colorUser)
                if let errorText { Text(errorText).font(.inter(14)).foregroundStyle(Brand.lossText).padding(.bottom, 10) }
                Button("Guardar") { save() }.buttonStyle(PrimaryPillStyle()).padding(.bottom, 8)
                if id != nil {
                    Button("Eliminar") { confirmDelete = true }.buttonStyle(SecondaryPillStyle(destructive: true)).padding(.bottom, 8)
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
        .confirmationDialog("¿Eliminar esta meta?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) {
                if let original { try? model.deleteSaving(id: original["id"] ?? .null) }
                dismiss()
            }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private func currencies(_ e: Engine) -> [String] {
        var out: [String] = [e.primaryCurrency]
        for a in e.allAccounts + e.allCards { let c = Engine.text(a["cur"]); if !c.isEmpty && !out.contains(c) { out.append(c) } }
        if !cur.isEmpty && !out.contains(cur) { out.append(cur) }
        return out
    }

    private func num(_ t: String) -> Double { Double(t.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)) ?? 0 }
    private func clean(_ n: Double) -> String { n == 0 ? "" : (n == n.rounded() ? String(Int64(n)) : String(n)) }

    private func load() {
        guard !loaded else { return }
        loaded = true
        let e = model.engine
        if let id, let o = (e.data["savings"]?.arrayValue ?? []).first(where: { Engine.identifier($0["id"]) == id }) {
            original = o
            name = Engine.text(o["name"])
            goalText = clean(Engine.number(o["goal"]))
            balanceText = clean(Engine.number(o["balance"]))
            monthlyText = clean(Engine.number(o["monthly"]))
            cur = Engine.text(o["cur"])
            color = Engine.text(o["color"]); icon = Engine.text(o["icon"]); iconUser = Engine.flag(o["iconUser"]); colorUser = Engine.flag(o["colorUser"])
        } else {
            color = Engine.cardColorsForApp.randomElement() ?? "#6D8BEA"
            cur = e.primaryCurrency
            goalFocused = true
        }
    }

    private func save() {
        var o: JSONValue = original ?? .object([
            "id": .string(String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6)).lowercased()),
        ])
        o["name"] = .string(name)
        o["cur"] = .string(cur)
        o["goal"] = .number(num(goalText))
        o["balance"] = .number(num(balanceText))
        o["monthly"] = .number(num(monthlyText))
        o["color"] = .string(color); o["icon"] = .string(icon); o["iconUser"] = .bool(iconUser); o["colorUser"] = .bool(colorUser)
        do {
            try model.saveSaving(o)
            dismiss()
        } catch ProfileEditor.FormError.missingName { errorText = "Escribe un nombre."
        } catch ProfileEditor.FormError.invalidAmount { errorText = "Escribe un monto."
        } catch { errorText = "No se pudo guardar." }
    }
}

struct ContribSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var loaded = false
    @State private var amountText = ""
    @State private var savingId = ""
    @State private var errorText: String?
    @FocusState private var amountFocused: Bool

    var body: some View {
        let e = model.engine
        let f = model.fmt
        let savings = e.data["savings"]?.arrayValue ?? []
        let cur = Engine.text(savings.first(where: { Engine.identifier($0["id"]) == savingId })?["cur"])
        ScrollView {
            VStack(spacing: 0) {
                SheetHead(title: "Aportar", onClose: { dismiss() }, onSave: { save() })
                AmountField(symbol: f.symbol(cur.isEmpty ? e.primaryCurrency : cur).trimmingCharacters(in: .whitespaces), text: $amountText,
                            placeholder: "0", focus: $amountFocused, label: "Aporte")
                SCard {
                    SRow(symbol: "leaf", label: "A la meta") {
                        Menu {
                            Picker("", selection: $savingId) {
                                ForEach(Array(savings.enumerated()), id: \.offset) { _, s in
                                    Text(Engine.text(s["name"]) + " · " + Engine.text(s["cur"])).tag(Engine.identifier(s["id"]))
                                }
                            }
                        } label: {
                            Text(savings.first(where: { Engine.identifier($0["id"]) == savingId }).map { Engine.text($0["name"]) + " · " + Engine.text($0["cur"]) } ?? "")
                                .foregroundStyle(.primary).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                Text("La meta es una forma de contar parte de tu dinero: el saldo de tus cuentas no cambia.")
                    .font(.inter(13)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).padding(.bottom, 14)
                if let errorText { Text(errorText).font(.inter(14)).foregroundStyle(Brand.lossText).padding(.bottom, 10) }
                Button("Guardar") { save() }.buttonStyle(PrimaryPillStyle()).padding(.bottom, 8)
            }
            .padding(.horizontal, 16).padding(.top, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(38)
        .presentationBackground(Color(light: "#F4F4F8", dark: "#1C1C1E"))
        .onAppear {
            guard !loaded else { return }
            loaded = true
            savingId = Engine.identifier(savings.first?["id"])
            amountFocused = true
        }
    }

    private func save() {
        let e = model.engine
        guard !(e.data["savings"]?.arrayValue ?? []).isEmpty else { errorText = "Primero crea una meta de ahorro."; return }
        let amt = Double(amountText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)) ?? 0
        guard amt > 0 else { errorText = "Escribe un monto."; return }
        let sid = (e.data["savings"]?.arrayValue ?? []).first(where: { Engine.identifier($0["id"]) == savingId })?["id"] ?? .null
        do { try model.contribute(savingId: sid, amount: amt); dismiss() }
        catch { errorText = "No se pudo guardar." }
    }
}
