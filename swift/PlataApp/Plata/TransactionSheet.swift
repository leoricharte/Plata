import SwiftUI
import PlataCore

/// Hoja para añadir o editar un movimiento.
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
    @State private var confirmDelete = false
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
        NavigationStack {
            Form {
                if !isPayLike {
                    Section {
                        Picker("Tipo", selection: $isOut) {
                            Text("Gasto").tag(true)
                            Text("Ingreso").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                }
                Section("Monto") {
                    HStack(spacing: 6) {
                        Text(f.symbol(e.accountCurrency(JSONValue.string(account)))).font(.title2).foregroundStyle(.secondary)
                        TextField("0", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.title2.weight(.semibold))
                            .focused($amountFocused)
                    }
                }
                Section {
                    if !isPayLike && isOut {
                        Picker("Categoría", selection: $category) {
                            ForEach(e.categoryNames, id: \.self) { Text($0).tag($0) }
                        }
                    }
                    Picker("Cuenta", selection: $account) {
                        ForEach(Array(e.allAccounts.enumerated()), id: \.offset) { _, a in
                            Text(Engine.text(a["name"])).tag(Engine.text(a["id"]))
                        }
                        if isOut || isPayLike {
                            ForEach(Array(e.allCards.enumerated()), id: \.offset) { _, k in
                                Text(Engine.text(k["name"])).tag(Engine.text(k["id"]))
                            }
                        }
                    }
                    DatePicker("Fecha", selection: $date, in: ...Date(), displayedComponents: .date)
                    TextField("Nota", text: $note)
                }
                if let errorText {
                    Section { Text(errorText).foregroundStyle(Brand.loss) }
                }
                if editedTx != nil {
                    Section {
                        Button("Eliminar movimiento", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(editedTx == nil ? "Nuevo movimiento" : "Editar movimiento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar") { save() } }
            }
            .confirmationDialog("¿Eliminar este movimiento?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Eliminar", role: .destructive) { remove() }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("El saldo de la cuenta se corrige.")
            }
            .onAppear(perform: load)
            .onChange(of: isOut) { _, nowOut in
                // un ingreso no va en una tarjeta
                if !nowOut, model.engine.allCards.contains(where: { Engine.text($0["id"]) == account }), let first = model.engine.allAccounts.first {
                    account = Engine.text(first["id"])
                }
            }
        }
        .presentationDetents([.large])
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

    private func remove() {
        if let tx = editedTx { try? model.deleteTransaction(id: tx["id"] ?? .null) }
        dismiss()
    }
}
