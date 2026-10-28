import SwiftUI
import PlataCore

/// «Posponer» un movimiento (`postponeHTML` de la web): sale de la lista y pasa a previstos en la fecha elegida.
struct PostponeSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let tx: JSONValue
    var onDone: () -> Void

    @State private var date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var errorText: String?

    var body: some View {
        let e = model.engine
        let f = model.fmt
        let amount = Engine.number(tx["amount"])
        let note = Engine.text(tx["note"])
        let label = note.isEmpty ? Engine.text(tx["category"]) : note
        ScrollView {
            VStack(spacing: 0) {
                SheetHead(title: "Posponer", onClose: { dismiss() })
                VStack(spacing: 0) {
                    Text(label).font(.inter(17)).foregroundStyle(.secondary)
                    Text(f.signed(amount, e.accountCurrency(tx["acc"]))).font(AmountField.font).tracking(-2).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                }
                .padding(.vertical, 12)
                HStack(spacing: 8) {
                    chip("Mañana", days: 1); chip("En 1 semana", days: 7); chip("En 1 mes", days: 30)
                }
                .padding(.bottom, 10)
                SCard {
                    SRow(symbol: "calendar", label: "Nueva fecha") {
                        Text(DateRow.text(date)).frame(maxWidth: .infinity, alignment: .leading)
                            .overlay {
                                DatePicker("", selection: $date, in: tomorrow..., displayedComponents: .date)
                                    .labelsHidden().colorMultiply(.clear).frame(maxWidth: .infinity, alignment: .leading)
                            }
                    }
                }
                Text(amount < 0 ? "Se quita de tus movimientos y pasa a gastos previstos en esa fecha. El saldo de la cuenta se corrige."
                                : "Se quita de tus movimientos y pasa a ingresos previstos en esa fecha. El saldo de la cuenta se corrige.")
                    .font(.inter(13)).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 8).padding(.bottom, 8)
                if let errorText { Text(errorText).font(.inter(14)).foregroundStyle(Brand.lossText).padding(.bottom, 10) }
                Button("Posponer") { go() }.buttonStyle(PrimaryPillStyle()).padding(.bottom, 8)
            }
            .padding(.horizontal, 16).padding(.top, 16)
        }
        .fitSheet().presentationDragIndicator(.visible).presentationCornerRadius(38)
        .presentationBackground(Color(light: "#F4F4F8", dark: "#1C1C1E"))
    }

    private var tomorrow: Date {
        Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
    }

    private func chip(_ title: String, days: Int) -> some View {
        Button {
            date = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? date
        } label: {
            Text(title).font(.inter(14, .medium)).foregroundStyle(.primary)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color(light: "#E5E5EA", dark: "#2C2C2E"), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func go() {
        let d = LocalDate.today(now: date)
        guard d.days > model.today.days else { errorText = "Elige una fecha futura."; return }
        do {
            try model.postponeTransaction(id: tx["id"] ?? .null, date: d)
            dismiss()
            onDone()
        } catch { errorText = "No se pudo posponer." }
    }
}
