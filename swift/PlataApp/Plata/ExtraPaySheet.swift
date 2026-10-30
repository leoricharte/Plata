import SwiftUI
import PlataCore

/// «Simular pago extra»: cuánto cambia la deuda pagando un poco más cada mes (`simHTML` de la web).
struct ExtraPaySheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var extra: Double = 0

    private func span(_ m: Int) -> String {
        let y = m / 12, r = m % 12
        var s = ""
        if y > 0 { s = Spanish.plural(y, "año", "años") + (r > 0 ? " y " : "") }
        if r > 0 || y == 0 { s += Spanish.plural(r, "mes", "meses") }
        return s
    }

    var body: some View {
        let e = model.engine
        let f = model.fmt
        let k = max(1, e.fromUSD(1, e.primaryCurrency).rounded())
        let base = e.payoff(extra: 0), me = e.payoff(extra: extra)
        ScrollView {
            VStack(spacing: 0) {
                SheetHead(title: "Simular pago extra", onClose: { dismiss() })
                VStack(spacing: 0) {
                    Text("Pago extra cada mes").font(.inter(17)).foregroundStyle(.secondary)
                    Text("+" + f.whole(extra)).font(AmountField.font).tracking(-2).monospacedDigit()
                }
                .padding(.vertical, 12)
                SCard {
                    Slider(value: $extra, in: 0...(600 * k), step: 10 * k).tint(Brand.accent).padding(.horizontal, 16).padding(.vertical, 12)
                }
                SCard {
                    if !me.ok {
                        row("Libre de deuda", "No se liquida")
                        RowDivider()
                        row("Sugerencia", "Sube el pago")
                    } else {
                        row("Libre de deuda", date(me.months))
                        RowDivider()
                        row("Tiempo", span(me.months))
                        RowDivider()
                        row("Intereses totales", f.whole(me.interest))
                        if extra > 0 && base.ok {
                            RowDivider()
                            row("Ahorras en intereses", f.whole(base.interest - me.interest), green: true)
                            RowDivider()
                            row("Te libras antes", span(max(0, base.months - me.months)), green: true)
                        }
                    }
                }
                Text("El extra se aplica primero a la deuda con mayor interés.")
                    .font(.inter(13)).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 8).padding(.bottom, 4)
            }
            .padding(.horizontal, 16).padding(.top, 16)
        }
        .fitSheet().presentationDragIndicator(.visible).presentationCornerRadius(38)
        .presentationBackground(Brand.sheetBg)
    }

    private func date(_ months: Int) -> String {
        let d = Calendar.current.date(byAdding: .month, value: months, to: model.today.date()) ?? Date()
        let c = Calendar.current.dateComponents([.year, .month], from: d)
        return "\(Spanish.monthsShort[(c.month ?? 1) - 1]) \(c.year ?? 2000)"
    }

    private func row(_ a: String, _ b: String, green: Bool = false) -> some View {
        HStack {
            Text(a).font(.inter(16))
            Spacer(minLength: 8)
            Text(b).font(.inter(16, .bold)).foregroundStyle(green ? Brand.gainText : Color.primary)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }
}
