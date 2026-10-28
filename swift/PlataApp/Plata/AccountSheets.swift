import SwiftUI
import PlataCore

private func num(_ t: String) -> Double { Double(t.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)) ?? 0 }
private func clean(_ n: Double) -> String { n == 0 ? "" : (n == n.rounded() ? String(Int64(n)) : String(n)) }
private func newId() -> String { String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6)).lowercased() }

/// Cuenta de débito (`FORMS.account`).
struct AccountSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let id: String?

    @State private var loaded = false
    @State private var name = ""
    @State private var last4 = ""
    @State private var type = "checking"
    @State private var apy = ""
    @State private var cur = ""
    @State private var balance = ""
    @State private var color = ""
    @State private var icon = ""
    @State private var iconUser = false
    @State private var colorUser = false
    @State private var original: JSONValue?
    @State private var errorText: String?
    @State private var askDelete = false
    @State private var askLinked = false
    @State private var linkF = 1.0
    @FocusState private var focus: Bool

    var body: some View {
        let e = model.engine
        let f = model.fmt
        let curs = profileCurrencies(e, including: cur)
        let info = original.map { ProfileEditor.accountLinks(model.profile.raw, id: $0["id"] ?? .null) }
        ScrollView {
            VStack(spacing: 0) {
                SheetHead(title: id == nil ? "Nueva cuenta de débito" : "Cuenta de débito", onClose: { dismiss() }, onSave: { save() })
                StylePreview(kind: .account, name: name, color: color, icon: icon, iconUser: iconUser, colorUser: colorUser)
                AmountField(symbol: f.symbol(cur).trimmingCharacters(in: .whitespaces), text: $balance,
                            placeholder: Money.decimals(cur) > 0 ? "0.00" : "0", focus: $focus, label: "Saldo")
                PillSegmented(items: [("checking", "Corriente"), ("savings", "Ahorros"), ("cash", "Efectivo")], selection: $type).padding(.bottom, 10)
                if curs.count > 1 {
                    CurrencyPills(curs: curs, cur: $cur, hasMoney: num(balance) > 0, linked: (info?.transactions ?? 0) > 0) { factor, new in
                        guard factor != 1 else { return }
                        linkF *= factor
                        balance = clean(CurrencyChange.scaled(num(balance), factor: factor, cur: new))
                    }.padding(.bottom, 10)
                }
                SCard {
                    FieldRow(symbol: "pencil", label: "Nombre", placeholder: "Nombre", text: $name)
                    if type != "cash" {
                        RowDivider()
                        FieldRow(symbol: "number", label: "Últimos 4 dígitos (opcional)", placeholder: "1234", text: $last4, numeric: true)
                        RowDivider()
                        FieldRow(symbol: "percent", label: "Rendimiento anual (%) — opcional", placeholder: "0", text: $apy, numeric: true)
                    }
                }
                StylePicker(color: $color, icon: $icon, iconUser: $iconUser, colorUser: $colorUser)
                if let errorText { Text(errorText).font(.inter(14)).foregroundStyle(Brand.lossText).padding(.bottom, 10) }
                Button("Guardar") { save() }.buttonStyle(PrimaryPillStyle()).padding(.bottom, 8)
                if id != nil {
                    Button("Eliminar") {
                        if (info?.transactions ?? 0) > 0 || !(info?.links.isEmpty ?? true) { askLinked = true } else { askDelete = true }
                    }.buttonStyle(SecondaryPillStyle(destructive: true)).padding(.bottom, 8)
                }
            }
            .padding(.horizontal, 16).padding(.top, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .fitSheet().presentationDragIndicator(.visible).presentationCornerRadius(38)
        .presentationBackground(Color(light: "#F4F4F8", dark: "#1C1C1E"))
        .onAppear(perform: load)
        .confirmationDialog("¿Eliminar esto?", isPresented: $askDelete, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) { remove() }
            Button("Cancelar", role: .cancel) {}
        } message: { Text("Esta acción no se puede deshacer.") }
        .confirmationDialog("Tiene datos ligados", isPresented: $askLinked, titleVisibility: .visible) {
            Button("Ocultar (recomendado)") {
                if let id { model.setAccountHidden(id: id, hidden: true) }
                dismiss()
            }
            Button("Eliminar todo", role: .destructive) { remove() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(linkedMessage(info))
        }
    }

    private func linkedMessage(_ info: (transactions: Int, links: [String])?) -> String {
        let n = info?.transactions ?? 0
        let links = info?.links ?? []
        return Tr.t("Tiene \(n) \(n == 1 ? "movimiento" : "movimientos")") + (links.isEmpty ? "" : " " + Tr.t("y está ligada a") + " " + links.joined(separator: ", "))
            + ". " + Tr.t("Si la eliminas, se borran esos movimientos. Para conservar el historial, mejor ocúltala.")
    }

    private func remove() {
        do { try model.deleteAccountCascade(id: original?["id"] ?? .null); dismiss() }
        catch { errorText = "Debes tener al menos una cuenta." }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        let e = model.engine
        if let id, let o = e.allAccounts.first(where: { Engine.identifier($0["id"]) == id }) {
            original = o
            name = Engine.text(o["name"]); last4 = Engine.text(o["last4"]); type = Engine.text(o["type"]).isEmpty ? "checking" : Engine.text(o["type"])
            apy = clean(Engine.number(o["apy"])); cur = Engine.text(o["cur"]); balance = clean(Engine.number(o["balance"])); color = Engine.text(o["color"]); icon = Engine.text(o["icon"]); iconUser = Engine.flag(o["iconUser"]); colorUser = Engine.flag(o["colorUser"])
        } else { cur = e.primaryCurrency; focus = true }
    }

    private func save() {
        var o: JSONValue = original ?? .object(["id": .string(newId()), "icon": .string("")])
        o["name"] = .string(name); o["last4"] = .string(last4); o["type"] = .string(type)
        o["apy"] = .number(num(apy)); o["cur"] = .string(cur); o["balance"] = .number(num(balance)); o["color"] = .string(color); o["icon"] = .string(icon); o["iconUser"] = .bool(iconUser); o["colorUser"] = .bool(colorUser)
        do { try model.saveAccount(o, linkFactor: original.map { Engine.text($0["cur"]) == cur ? 1 : linkF } ?? 1); dismiss() }
        catch ProfileEditor.FormError.missingName { errorText = "Escribe un nombre." }
        catch { errorText = "No se pudo guardar." }
    }
}

/// Tarjeta de crédito o préstamo (`FORMS.debt`).
struct DebtSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let id: String?

    @State private var loaded = false
    @State private var kind = "card"
    @State private var name = ""
    @State private var last4 = ""
    @State private var limit = ""
    @State private var apr = "20"
    @State private var payment = ""
    @State private var dueDay = "1"
    @State private var cur = ""
    @State private var balance = ""
    @State private var color = ""
    @State private var icon = ""
    @State private var iconUser = false
    @State private var colorUser = false
    @State private var original: JSONValue?
    @State private var errorText: String?
    @State private var askDelete = false
    @State private var askLinked = false
    @State private var linkF = 1.0
    @FocusState private var focus: Bool

    var body: some View {
        let e = model.engine
        let f = model.fmt
        let curs = profileCurrencies(e, including: cur)
        let info = original.map { ProfileEditor.accountLinks(model.profile.raw, id: $0["id"] ?? .null) }
        ScrollView {
            VStack(spacing: 0) {
                SheetHead(title: id == nil ? "Nueva tarjeta o préstamo" : "Tarjeta o préstamo", onClose: { dismiss() }, onSave: { save() })
                StylePreview(kind: .debt, name: name, color: color, icon: icon, iconUser: iconUser, colorUser: colorUser)
                AmountField(symbol: f.symbol(cur).trimmingCharacters(in: .whitespaces), text: $balance,
                            placeholder: Money.decimals(cur) > 0 ? "0.00" : "0", focus: $focus, label: "Saldo adeudado (lo que debes)")
                PillSegmented(items: [("card", "Tarjeta"), ("loan", "Préstamo")], selection: $kind).padding(.bottom, 10)
                if curs.count > 1 {
                    CurrencyPills(curs: curs, cur: $cur, hasMoney: num(balance) + num(limit) + num(payment) > 0, linked: original != nil) { factor, new in
                        guard factor != 1 else { return }
                        linkF *= factor
                        balance = clean(CurrencyChange.scaled(num(balance), factor: factor, cur: new))
                        limit = clean(CurrencyChange.scaled(num(limit), factor: factor, cur: new))
                        payment = clean(CurrencyChange.scaled(num(payment), factor: factor, cur: new))
                    }.padding(.bottom, 10)
                }
                SCard {
                    FieldRow(symbol: "pencil", label: "Nombre", placeholder: "Nombre", text: $name)
                    RowDivider()
                    FieldRow(symbol: "number", label: "Últimos 4 dígitos (opcional)", placeholder: "1234", text: $last4, numeric: true)
                    if kind == "card" {
                        RowDivider()
                        FieldRow(symbol: "creditcard", label: "Límite de la tarjeta", placeholder: "0", text: $limit, numeric: true)
                    }
                    RowDivider()
                    FieldRow(symbol: "percent", label: "Interés anual (%)", placeholder: "0", text: $apr, numeric: true)
                    RowDivider()
                    FieldRow(symbol: "dollarsign.circle", label: "Pago mensual", placeholder: "0", text: $payment, numeric: true)
                    RowDivider()
                    FieldRow(symbol: "calendar", label: "Día de pago", placeholder: "0", text: $dueDay, numeric: true)
                }
                StylePicker(color: $color, icon: $icon, iconUser: $iconUser, colorUser: $colorUser, debt: true)
                if let errorText { Text(errorText).font(.inter(14)).foregroundStyle(Brand.lossText).padding(.bottom, 10) }
                Button("Guardar") { save() }.buttonStyle(PrimaryPillStyle()).padding(.bottom, 8)
                if id != nil {
                    Button("Eliminar") {
                        if (info?.transactions ?? 0) > 0 || !(info?.links.isEmpty ?? true) { askLinked = true } else { askDelete = true }
                    }.buttonStyle(SecondaryPillStyle(destructive: true)).padding(.bottom, 8)
                }
            }
            .padding(.horizontal, 16).padding(.top, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .fitSheet().presentationDragIndicator(.visible).presentationCornerRadius(38)
        .presentationBackground(Color(light: "#F4F4F8", dark: "#1C1C1E"))
        .onAppear(perform: load)
        .confirmationDialog("¿Eliminar esto?", isPresented: $askDelete, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) { remove() }
            Button("Cancelar", role: .cancel) {}
        } message: { Text("Esta acción no se puede deshacer.") }
        .confirmationDialog("Tiene datos ligados", isPresented: $askLinked, titleVisibility: .visible) {
            Button("Ocultar (recomendado)") {
                if let id { model.setAccountHidden(id: id, hidden: true) }
                dismiss()
            }
            Button("Eliminar todo", role: .destructive) { remove() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            let n = info?.transactions ?? 0
            let links = info?.links ?? []
            Text(verbatim: Tr.t("Tiene \(n) \(n == 1 ? "movimiento" : "movimientos")") + (links.isEmpty ? "" : " " + Tr.t("y está ligada a") + " " + links.joined(separator: ", "))
                 + ". " + Tr.t("Si la eliminas, se borran esos movimientos. Para conservar el historial, mejor ocúltala."))
        }
    }

    private func remove() {
        do { try model.deleteAccountCascade(id: original?["id"] ?? .null); dismiss() }
        catch { errorText = "No se pudo eliminar." }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        let e = model.engine
        if let id, let o = e.allCards.first(where: { Engine.identifier($0["id"]) == id }) {
            original = o
            kind = Engine.text(o["kind"]) == "loan" ? "loan" : "card"
            name = Engine.text(o["name"]); last4 = Engine.text(o["last4"]); limit = clean(Engine.number(o["limit"]))
            apr = clean(Engine.number(o["apr"])); payment = clean(Engine.number(o["payment"])); dueDay = clean(Engine.number(o["due_day"]))
            cur = Engine.text(o["cur"]); balance = clean(Engine.number(o["balance"])); color = Engine.text(o["color"]); icon = Engine.text(o["icon"]); iconUser = Engine.flag(o["iconUser"]); colorUser = Engine.flag(o["colorUser"])
        } else { cur = e.primaryCurrency; focus = true }
    }

    private func save() {
        var o: JSONValue = original ?? .object(["id": .string(newId()), "icon": .string("")])
        o["kind"] = .string(kind); o["name"] = .string(name); o["last4"] = .string(last4)
        o["limit"] = .number(num(limit)); o["apr"] = .number(num(apr)); o["payment"] = .number(num(payment))
        o["due_day"] = .number(num(dueDay)); o["cur"] = .string(cur); o["balance"] = .number(num(balance)); o["color"] = .string(color); o["icon"] = .string(icon); o["iconUser"] = .bool(iconUser); o["colorUser"] = .bool(colorUser)
        do { try model.saveDebt(o, linkFactor: original.map { Engine.text($0["cur"]) == cur ? 1 : linkF } ?? 1); dismiss() }
        catch ProfileEditor.FormError.missingName { errorText = "Escribe un nombre." }
        catch ProfileEditor.FormError.invalidDueDay { errorText = "El día de pago va del 1 al 31." }
        catch ProfileEditor.FormError.negativeInterest { errorText = "El interés no puede ser negativo." }
        catch ProfileEditor.FormError.overLimit { errorText = "La deuda supera el límite de la tarjeta. Revisa el saldo o el límite." }
        catch { errorText = "No se pudo guardar." }
    }
}

/// Servicio o suscripción (`FORMS.sub`).
struct SubSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let id: String?

    @State private var loaded = false
    @State private var name = ""
    @State private var amount = ""
    @State private var day = "1"
    @State private var account = ""
    @State private var cur = ""
    @State private var original: JSONValue?
    @State private var errorText: String?
    @State private var askDelete = false
    @FocusState private var focus: Bool

    var body: some View {
        let e = model.engine
        let f = model.fmt
        let curs = profileCurrencies(e, including: cur)
        ScrollView {
            VStack(spacing: 0) {
                SheetHead(title: id == nil ? "Nuevo servicio o suscripción" : "Servicio o suscripción", onClose: { dismiss() }, onSave: { save() })
                AmountField(symbol: f.symbol(cur).trimmingCharacters(in: .whitespaces), text: $amount,
                            placeholder: Money.decimals(cur) > 0 ? "0.00" : "0", focus: $focus, label: "Por mes")
                if curs.count > 1 {
                    CurrencyPills(curs: curs, cur: $cur, hasMoney: num(amount) > 0) { factor, new in
                        if factor != 1 { amount = clean(CurrencyChange.scaled(num(amount), factor: factor, cur: new)) }
                    }.padding(.bottom, 10)
                }
                SCard {
                    FieldRow(symbol: "pencil", label: "Nombre", placeholder: "Nombre", text: $name)
                    RowDivider()
                    FieldRow(symbol: "calendar", label: "Día de cobro", placeholder: "0", text: $day, numeric: true)
                    RowDivider()
                    SRow(symbol: "creditcard", label: "Se cobra de") {
                        Menu {
                            Picker("", selection: $account) {
                                Text("Sin especificar").tag("")
                                Section("Débito") {
                                    ForEach(Array(e.allAccounts.enumerated()), id: \.offset) { _, a in Text(label(a)).tag(Engine.text(a["id"])) }
                                }
                                if !e.allCards.isEmpty {
                                    Section("Crédito") {
                                        ForEach(Array(e.allCards.enumerated()), id: \.offset) { _, a in Text(label(a)).tag(Engine.text(a["id"])) }
                                    }
                                }
                            }
                        } label: {
                            Text(selected(e)).foregroundStyle(.primary).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                if let errorText { Text(errorText).font(.inter(14)).foregroundStyle(Brand.lossText).padding(.bottom, 10) }
                Button("Guardar") { save() }.buttonStyle(PrimaryPillStyle()).padding(.bottom, 8)
                if id != nil {
                    Button("Eliminar") { askDelete = true }.buttonStyle(SecondaryPillStyle(destructive: true)).padding(.bottom, 8)
                }
            }
            .padding(.horizontal, 16).padding(.top, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .fitSheet().presentationDragIndicator(.visible).presentationCornerRadius(38)
        .presentationBackground(Color(light: "#F4F4F8", dark: "#1C1C1E"))
        .onAppear(perform: load)
        .confirmationDialog("¿Eliminar esto?", isPresented: $askDelete, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) {
                if let original { try? model.deleteSub(id: original["id"] ?? .null) }
                dismiss()
            }
            Button("Cancelar", role: .cancel) {}
        } message: { Text("Dejará de aparecer en tus pagos futuros. Tu historial no cambia.") }
    }

    private func label(_ a: JSONValue) -> String {
        var s = Engine.text(a["name"])
        let l4 = Engine.text(a["last4"])
        if !l4.isEmpty { s += " · ● " + l4 }
        return s + " · " + Engine.text(a["cur"])
    }

    private func selected(_ e: Engine) -> String {
        for a in e.allAccounts + e.allCards where Engine.text(a["id"]) == account { return label(a) }
        return "Sin especificar"
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        let e = model.engine
        if let id, let o = e.subscriptionList.first(where: { Engine.identifier($0["id"]) == id }) {
            original = o
            name = Engine.text(o["name"]); amount = clean(Engine.number(o["amount"])); day = clean(Engine.number(o["day"]))
            account = Engine.text(o["acc"]); cur = Engine.text(o["cur"])
        } else {
            cur = e.primaryCurrency
            day = String(min(28, model.today.day))
            focus = true
        }
    }

    private func save() {
        var o: JSONValue = original ?? .object(["id": .string(newId()), "since": .string(model.today.iso)])
        o["name"] = .string(name); o["amount"] = .number(num(amount)); o["day"] = .number(num(day))
        o["acc"] = .string(account); o["cur"] = .string(cur)
        do { try model.saveSub(o); dismiss() }
        catch ProfileEditor.FormError.missingName { errorText = "Escribe un nombre." }
        catch ProfileEditor.FormError.invalidAmount { errorText = "Escribe un monto." }
        catch { errorText = "No se pudo guardar." }
    }
}
