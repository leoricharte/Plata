import SwiftUI
import PlataCore

/// El detalle de un movimiento (`renderTx` de la web): cuadrito, nombre, categoría, monto grande y sus datos.
struct TransactionDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let id: String
    @State private var editing: JSONValue?
    @State private var confirmDelete = false
    @State private var postponing: JSONValue?

    var body: some View {
        let e = model.engine
        let f = model.fmt
        if let tx = e.allTransactions.first(where: { Engine.identifier($0["id"]) == id }) {
            content(tx, e, f)
        } else {
            Color.clear.onAppear { dismiss() }
        }
    }

    private func content(_ tx: JSONValue, _ e: Engine, _ f: Fmt) -> some View {
        let category = Engine.text(tx["category"])
        let amount = Engine.number(tx["amount"])
        let cur = e.accountCurrency(tx["acc"])
        let isTransfer = category == "Transferencia"
        let isPay = category == "Pago de crédito"
        let isIncome = amount > 0 && !isTransfer && !isPay
        let known = e.categoryNames.contains(category)
        let shown = isIncome ? "Ingreso" : (known || isPay || isTransfer ? category : "Otros")
        let color: Color = isPay ? Color(hex: "#B98AE6") : (isTransfer ? Color(.systemGray) : Color(hex: e.categoryColor(shown)))
        let note = Engine.text(tx["note"])
        let kind = isTransfer ? "Transferencia" : (isPay ? "Pago de crédito" : (amount > 0 ? "Ingreso" : "Gasto"))
        let date = LocalDate(iso: Engine.text(tx["date"]))
        let dateText = date.map { Spanish.dateShort($0) + " " + String($0.year) } ?? Engine.text(tx["date"])
        let est = Engine.number(tx["est"])
        let diff = ((amount - est) * 100).rounded() / 100
        let pairID = Engine.text(tx["pair"])
        let pair = pairID.isEmpty ? nil : e.allTransactions.first(where: { Engine.text($0["pair"]) == pairID && Engine.identifier($0["id"]) != id })

        return ScrollView {
            VStack(spacing: 0) {
                Tile(symbol: e.catSymbol(shown), color: color, size: 64)
                    .padding(.top, 4).padding(.bottom, 8)
                Text(note.isEmpty ? shown : note)
                    .font(.inter(28, .bold, relativeTo: .title)).tracking(-0.8)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
                Text(shown).font(.inter(15)).foregroundStyle(.secondary).padding(.top, 2)
                Text(f.signed(amount, cur))
                    .font(.inter(40, .bold, relativeTo: .largeTitle)).tracking(-1.4).monospacedDigit()
                    .foregroundStyle(isIncome ? Brand.gainText : Color.primary)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .padding(.top, 12)
                    .padding(.bottom, 16)

                VStack(spacing: 0) {
                    statsRow(first: true, ("Cuenta", e.accountName(tx["acc"]), nil), ("Fecha", dateText, nil))
                    statsRow(first: false, ("Tipo", kind, nil), ("Categoría", shown, nil))
                    if est > 0 && amount > 0 {
                        statsRow(first: false, ("Previsto", f.exact(est, cur), nil),
                                 ("Diferencia", (diff >= 0 ? "+" : "−") + f.exact(abs(diff), cur), diff >= 0 ? Brand.gainText : Brand.lossText))
                    }
                    if Engine.flag(tx["job"]), Engine.number(tx["hrs"]) > 0 {
                        let hrs = Engine.number(tx["hrs"]), rate = Engine.number(tx["rate"])
                        statsRow(first: false, ("Horas trabajadas", Engine.hoursText(hrs), nil), ("Monto pagado", f.exact(amount, cur), nil))
                        statsRow(first: false, ("Bruto (\(f.exact(rate, cur))/h)", f.exact(rate * hrs, cur), nil),
                                 ("Impuestos descontados", Engine.taxText(amount: amount, rate: rate, hours: hrs), nil))
                    }
                    if let pair {
                        statsRow(first: false, (Engine.number(pair["amount"]) < 0 ? "Salió de" : "Entró a", e.accountName(pair["acc"]), nil), nil)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 26, style: .continuous))

                if !isTransfer {
                    Button("Editar") { editing = tx }
                        .buttonStyle(SecondaryPillStyle())
                        .padding(.top, 10)
                }
                if !isTransfer && !isPay {
                    Button("Posponer") { postponing = tx }
                        .buttonStyle(SecondaryPillStyle())
                        .padding(.top, 10)
                }
                Button("Eliminar") { confirmDelete = true }
                    .buttonStyle(SecondaryPillStyle(destructive: true))
                    .padding(.top, 10)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isTransfer {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { editing = tx } label: { Image(systemName: "pencil") }
                        .accessibilityLabel("Editar")
                }
            }
        }
        .sheet(item: Binding(get: { editing.map { Wrapper(tx: $0) } }, set: { editing = $0?.tx })) { w in
            TransactionSheet(mode: .edit(w.tx))
        }
        .sheet(item: Binding(get: { postponing.map { Wrapper(tx: $0) } }, set: { postponing = $0?.tx })) { w in
            PostponeSheet(tx: w.tx) {}
        }
        .confirmationDialog("¿Eliminar este movimiento?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) {
                try? model.deleteTransaction(id: tx["id"] ?? .null)
                dismiss()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("El saldo de la cuenta se corrige.")
        }
    }

    private struct Wrapper: Identifiable {
        let tx: JSONValue
        var id: String { Engine.identifier(tx["id"]) }
    }

    /// Una fila de datos de la tarjeta (`.stats`): dos columnas con etiqueta pequeña y valor en negrita; desde la segunda lleva una línea arriba.
    @ViewBuilder
    private func statsRow(first: Bool, _ a: (String, String, Color?), _ b: (String, String, Color?)?) -> some View {
        VStack(spacing: 0) {
            if !first { RowDivider().padding(.top, 14) }
            HStack(alignment: .top, spacing: 20) {
                stat(a.0, a.1, a.2)
                if let b { stat(b.0, b.1, b.2) } else { Spacer(minLength: 0).frame(maxWidth: .infinity) }
            }
            .padding(.top, first ? 0 : 12)
        }
    }

    private func stat(_ label: String, _ value: String, _ color: Color?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.inter(15)).foregroundStyle(.secondary)
            Text(value).font(.inter(20, .bold)).tracking(-0.4).foregroundStyle(color ?? Color.primary)
                .lineLimit(2).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
