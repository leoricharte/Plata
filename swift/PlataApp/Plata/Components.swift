import SwiftUI
import Charts
import PlataCore

/// Cuatro números del Resumen, en cuadrícula de dos columnas (como `.kpi` de la web).
struct KPIGrid: View {
    struct Item: Identifiable {
        let id: String
        let title: String
        let value: String
        let detail: String
        var link: String = ""
        var action: () -> Void = {}
    }
    let items: [Item]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(items) { item in
                Button(action: item.action) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title).font(.inter(15)).foregroundStyle(.secondary)
                        Text(item.value)
                            .font(.inter(26, .bold, relativeTo: .title))
                            .tracking(-0.9)
                            .foregroundStyle(.primary)
                            .minimumScaleFactor(0.6).lineLimit(1)
                        Text(item.detail).font(.inter(15)).foregroundStyle(.secondary).lineLimit(1)
                        if !item.link.isEmpty {
                            Text(item.link).font(.inter(15, .medium)).foregroundStyle(Brand.green).padding(.top, 6)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Leyenda de dos colores (Gastos / Ingresos).
struct ChartLegend: View {
    var body: some View {
        HStack(spacing: 14) {
            item(Brand.expenseBar, "Gastos")
            item(Brand.incomeBar, "Ingresos")
        }
        .font(.inter(13))
        .foregroundStyle(.secondary)
    }

    private func item(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3, style: .continuous).fill(color).frame(width: 10, height: 10)
            Text(title)
        }
    }
}

/// Barras de ingresos y gastos de los últimos meses: dos barras por mes, eje a la derecha, mes actual en negrita.
struct MonthsChart: View {
    let months: [MonthBar]
    let symbol: String

    private struct Point: Identifiable {
        let id: String
        let label: String
        let kind: String
        let value: Double
    }

    private var yMax: Double {
        var m = 1.0
        for x in months { m = max(m, x.income, x.expense) }
        return max(500, (m / 500).rounded(.up) * 500)
    }

    private func axisText(_ v: Double) -> String {
        let a = abs(v)
        if a >= 1000 {
            let k = a / 1000
            let t = k == k.rounded() ? String(Int(k)) : String(format: "%g", k)
            return symbol + t + "k"
        }
        return symbol + String(Int(a))
    }

    var body: some View {
        let top = yMax
        let points: [Point] = months.enumerated().flatMap { (pair: EnumeratedSequence<[MonthBar]>.Element) -> [Point] in
            let i = pair.offset, m = pair.element
            return [Point(id: "g\(i)", label: m.label, kind: "Gastos", value: m.expense),
                    Point(id: "i\(i)", label: m.label, kind: "Ingresos", value: m.income)]
        }
        let current = months.first(where: { $0.cur })?.label ?? ""
        Chart(points) { p in
            BarMark(x: .value("Mes", p.label), y: .value("Monto", p.value))
                .position(by: .value("Tipo", p.kind))
                .foregroundStyle(by: .value("Tipo", p.kind))
                .cornerRadius(4)
        }
        .chartForegroundStyleScale(["Gastos": Brand.expenseBar, "Ingresos": Brand.incomeBar])
        .chartLegend(.hidden)
        .chartYScale(domain: 0...top)
        .chartYAxis {
            AxisMarks(position: .trailing, values: [0, top / 2, top]) { value in
                AxisGridLine().foregroundStyle(Color(.separator).opacity(value.index == 0 ? 0.9 : 0.4))
                AxisValueLabel {
                    if let v = value.as(Double.self) { Text(axisText(v)).font(.inter(13)).foregroundStyle(.secondary) }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let s = value.as(String.self) {
                        Text(verbatim: Tr.monthAbbr(s)).font(.inter(13, s == current ? .semibold : .regular)).foregroundStyle(s == current ? Color.primary : Color.secondary)
                    }
                }
            }
        }
        .frame(height: 200)
    }
}

/// Gasto del mes por categoría: anillo con el total al centro y la lista al lado (como `ringrow` de la web).
struct CategoryDonut: View {
    let cats: [CatSlice]
    let total: String
    let format: (Double) -> String

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Chart(cats, id: \.name) { k in
                SectorMark(angle: .value("Gasto", k.v), innerRadius: .ratio(0.78), angularInset: 1.5)
                    .cornerRadius(5)
                    .foregroundStyle(Color(hex: k.color))
            }
            .chartLegend(.hidden)
            .frame(width: 140, height: 140)
            .overlay {
                VStack(spacing: 0) {
                    Text("Total").font(.inter(12)).foregroundStyle(.secondary)
                    Text(total).font(.inter(17, .bold)).tracking(-0.5).minimumScaleFactor(0.5).lineLimit(1)
                }
                .padding(.horizontal, 26)
            }
            VStack(spacing: 0) {
                ForEach(Array(cats.enumerated()), id: \.offset) { i, k in
                    if i > 0 { RowDivider() }
                    HStack(spacing: 8) {
                        Circle().fill(Color(hex: k.color)).frame(width: 10, height: 10)
                        Text(k.name).font(.inter(15)).lineLimit(1)
                        Spacer(minLength: 4)
                        Text(format(k.v)).font(.inter(15, .semibold)).lineLimit(1)
                    }
                    .frame(minHeight: 36)
                }
            }
        }
    }
}
