import SwiftUI
import Charts
import PlataCore

/// Cuatro números del Resumen, en cuadrícula de dos columnas.
struct KPIGrid: View {
    struct Item: Identifiable {
        let id: String
        let title: LocalizedStringKey
        let value: String
        let detail: String
    }
    let items: [Item]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    Text(item.value).font(.title2.weight(.bold)).minimumScaleFactor(0.6).lineLimit(1)
                    Text(item.detail).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
    }
}

/// Barras de ingresos y gastos de los últimos meses.
struct MonthsChart: View {
    let months: [MonthBar]

    private struct Point: Identifiable {
        let id: String
        let label: String
        let kind: String
        let value: Double
    }

    var body: some View {
        let points: [Point] = months.enumerated().flatMap { (pair: EnumeratedSequence<[MonthBar]>.Element) -> [Point] in
            let i = pair.offset, m = pair.element
            return [Point(id: "g\(i)", label: m.label, kind: "Gastos", value: m.expense),
                    Point(id: "i\(i)", label: m.label, kind: "Ingresos", value: m.income)]
        }
        Chart(points) { p in
            BarMark(x: .value("Mes", p.label), y: .value("Monto", p.value))
                .position(by: .value("Tipo", p.kind))
                .foregroundStyle(by: .value("Tipo", p.kind))
                .cornerRadius(4)
        }
        .chartForegroundStyleScale(["Gastos": Brand.expenseBar, "Ingresos": Brand.incomeBar])
        .chartLegend(position: .bottom, alignment: .leading)
        .frame(height: 200)
    }
}

/// Gasto del mes por categoría: anillo con el total al centro y la lista al lado.
struct CategoryDonut: View {
    let cats: [CatSlice]
    let total: String

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Chart(cats, id: \.name) { k in
                SectorMark(angle: .value("Gasto", k.v), innerRadius: .ratio(0.62), angularInset: 1.5)
                    .cornerRadius(4)
                    .foregroundStyle(Color(hex: k.color))
            }
            .frame(width: 132, height: 132)
            .overlay {
                VStack(spacing: 0) {
                    Text("Total").font(.caption).foregroundStyle(.secondary)
                    Text(total).font(.subheadline.weight(.bold)).minimumScaleFactor(0.5).lineLimit(1)
                }
                .padding(.horizontal, 28)
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(cats, id: \.name) { k in
                    HStack(spacing: 8) {
                        Circle().fill(Color(hex: k.color)).frame(width: 9, height: 9)
                        Text(k.name).font(.subheadline).lineLimit(1)
                        Spacer(minLength: 4)
                    }
                }
            }
        }
    }
}

/// La letra de la nota del mes (S, A, B, C, D, F).
struct GradeBadge: View {
    let letter: String
    var size: CGFloat = 56

    static func color(_ letter: String) -> Color {
        switch letter {
        case "S": return Color(hex: "#C9A227")
        case "A": return Color(hex: "#1A9D63")
        case "B": return Color(hex: "#2AA6A0")
        case "C": return Color(hex: "#E5A100")
        case "D": return Color(hex: "#F07A28")
        default: return Color(hex: "#E5322D")
        }
    }

    var body: some View {
        Text(letter)
            .font(.system(size: size * 0.55, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(GradeBadge.color(letter).gradient, in: RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
            .accessibilityLabel("Nota \(letter)")
    }
}
