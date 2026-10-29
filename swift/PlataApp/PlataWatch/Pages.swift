import SwiftUI
import WatchKit

/// Tres páginas en horizontal: presupuesto del día · añadir (centro) · proyección.
struct RootPages: View {
    @Environment(WatchStore.self) private var store
    @State private var page = 1

    var body: some View {
        TabView(selection: $page) {
            BudgetPage().tag(0)
            AddPage().tag(1)
            ProjectionPage().tag(2)
        }
        .tabViewStyle(.page)
    }
}

// MARK: piezas comunes

/// Montos: con la muñeca baja (pantalla atenuada) se ocultan.
struct Amount: View {
    @Environment(\.isLuminanceReduced) private var dim
    var text: String
    var body: some View { Text(dim ? "———" : text) }
}

/// «hace 3 min» chiquito, como el del iPhone.
struct SyncNote: View {
    @Environment(WatchStore.self) private var store
    var body: some View {
        if let s = store.snapshot {
            let m = max(0, Int((Date().timeIntervalSince1970 * 1000 - s.stamp) / 60000))
            HStack(spacing: 3) {
                Image(systemName: m > 60 * 6 ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                Text(m < 1 ? "ahora" : m < 60 ? "hace \(m) min" : "hace \(m / 60) h")
            }
            .font(.system(size: 10, weight: .medium)).foregroundStyle(m > 60 * 6 ? .orange : .secondary)
        } else {
            Text("Abre Plata en tu iPhone").font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }
}

extension WatchSnapshot {
    func fmt(_ n: Double, signed: Bool = false) -> String { WatchFormat.money(n, sym: sym, dec: dec, signed: signed) }
}

// MARK: presupuesto del día

struct BudgetPage: View {
    @Environment(WatchStore.self) private var store

    var body: some View {
        if let s = store.snapshot {
            ScrollView {
                VStack(spacing: 6) {
                    if !s.letter.isEmpty {
                        Text("\(s.letter) • \(s.adjective)").font(.system(size: 12, weight: .semibold)).foregroundStyle(WatchTheme.accent)
                    }
                    ring(s)
                    if s.allowance > 0 {
                        let left = s.allowance - s.spentToday
                        VStack(spacing: 0) {
                            Amount(text: s.fmt(abs(left))).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(left < 0 ? .red : .primary)
                            Text(left < 0 ? "pasado hoy" : "te quedan hoy").font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Sin presupuesto este mes").font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    ForEach(s.cats, id: \.name) { c in
                        let r = c.spent / c.limit
                        VStack(alignment: .leading, spacing: 2) {
                            HStack { Text(c.name).lineLimit(1); Spacer(); Amount(text: s.fmt(c.spent)) }.font(.system(size: 11))
                            ProgressView(value: min(1, r)).tint(r >= 1 ? .red : r >= 0.8 ? .orange : WatchTheme.accent)
                        }
                        .padding(.top, 2)
                    }
                    SyncNote().padding(.top, 4)
                }
                .padding(.horizontal, 6)
            }
        } else {
            VStack { SyncNote() }
        }
    }

    private func ring(_ s: WatchSnapshot) -> some View {
        let r = s.allowance > 0 ? min(1.0, s.spentToday / s.allowance) : 0
        return ZStack {
            Circle().stroke(Color.secondary.opacity(0.25), lineWidth: 9)
            Circle().trim(from: 0, to: max(0.001, r)).stroke(r >= 1 ? Color.red : WatchTheme.accent, style: StrokeStyle(lineWidth: 9, lineCap: .round)).rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Amount(text: s.fmt(s.spentToday)).font(.system(size: 15, weight: .bold, design: .rounded))
                Text("hoy").font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
        .frame(width: 92, height: 92)
    }
}

// MARK: añadir

struct AddPage: View {
    @Environment(WatchStore.self) private var store
    @State private var crown = 0.0
    @State private var typed: Double?
    @State private var isOut = true
    @State private var account = ""
    @State private var category = ""
    @State private var editing = false
    @State private var typedText = ""

    /// La corona acelera: los primeros pasos van de 1 en 1, luego de 5 y luego de 25.
    static func mapped(_ v: Double) -> Double { v <= 60 ? v : v <= 120 ? 60 + (v - 60) * 5 : 360 + (v - 120) * 25 }
    private var amount: Double { typed ?? Self.mapped(crown) }

    var body: some View {
        if let s = store.snapshot {
            if store.pending != nil { done(s) } else { form(s) }
        } else {
            VStack { SyncNote() }
        }
    }

    private func done(_ s: WatchSnapshot) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 34)).foregroundStyle(WatchTheme.accent)
            Text("Anotado").font(.system(size: 15, weight: .semibold))
            Button("Deshacer") { store.undo() }.buttonStyle(.bordered)
        }
    }

    private func form(_ s: WatchSnapshot) -> some View {
        ScrollView {
            VStack(spacing: 6) {
                Button { editing = true; typedText = "" } label: {
                    Amount(text: (isOut ? "-" : "+") + s.fmt(amount))
                        .font(.system(size: 30, weight: .bold, design: .rounded)).minimumScaleFactor(0.6).lineLimit(1)
                        .foregroundStyle(isOut ? Color.primary : WatchTheme.accent)
                }
                .buttonStyle(.plain)
                .focusable()
                .digitalCrownRotation($crown, from: 0, through: 200, by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                .onChange(of: crown) { _, _ in typed = nil }
                Text("Gira la corona o toca el monto").font(.system(size: 10)).foregroundStyle(.secondary)
                Picker("", selection: $isOut) { Text("Gasto").tag(true); Text("Ingreso").tag(false) }.frame(height: 40)
                if isOut {
                    Picker("Categoría", selection: $category) { ForEach(s.categories, id: \.self) { Text($0).tag($0) } }
                }
                Picker("Cuenta", selection: $account) { ForEach(s.accounts, id: \.id) { Text($0.name).tag($0.id) } }
                Button {
                    save(s)
                } label: { Text("Añadir").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).tint(WatchTheme.accent).disabled(amount <= 0 || account.isEmpty)
                SyncNote()
            }
            .padding(.horizontal, 4)
        }
        .onAppear {
            if account.isEmpty { account = s.accounts.first?.id ?? "" }
            if category.isEmpty { category = s.categories.first ?? "" }
        }
        .sheet(isPresented: $editing) {
            VStack {
                TextField("Monto", text: $typedText)
                Button("Listo") { typed = Double(typedText.replacingOccurrences(of: ",", with: ".")); editing = false }
            }
        }
    }

    private func save(_ s: WatchSnapshot) {
        let iso = DateFormatter.iso.string(from: Date())
        store.add(WatchEntry(id: UUID().uuidString, amount: isOut ? -amount : amount, category: isOut ? category : "Ingreso", account: account, note: "", date: iso))
        crown = 0; typed = nil
    }
}

extension DateFormatter {
    static let iso: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

// MARK: proyección: semanas → días

struct ProjectionPage: View {
    @Environment(WatchStore.self) private var store
    @State private var week = 0.0
    @State private var day = 0.0
    @State private var byDay = false

    var body: some View {
        if let s = store.snapshot, s.days.count >= 7 {
            if byDay { dayView(s) } else { weekView(s) }
        } else {
            VStack { SyncNote() }
        }
    }

    private func weekView(_ s: WatchSnapshot) -> some View {
        let w = min(3, max(0, Int(week)))
        let range = (w * 7)..<min(s.days.count, w * 7 + 7)
        let days = Array(s.days[range])
        let last = days.last!
        let inc = days.flatMap(\.events).filter { $0.amt > 0 }.reduce(0) { $0 + $1.amt }
        let out = days.flatMap(\.events).filter { $0.amt < 0 }.reduce(0) { $0 + $1.amt }
        return VStack(spacing: 4) {
            Text(w == 0 ? "Esta semana" : "Semana \(w + 1)").font(.system(size: 13, weight: .semibold)).foregroundStyle(WatchTheme.accent)
            Text(rangeLabel(days.first!.iso, last.iso)).font(.system(size: 10)).foregroundStyle(.secondary)
            Amount(text: s.fmt(last.cash)).font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(last.cash < 0 ? .red : .primary)
            Text("en caja").font(.system(size: 10)).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                VStack(spacing: 0) { Amount(text: s.fmt(inc, signed: true)).foregroundStyle(WatchTheme.accent); Text("entra") .foregroundStyle(.secondary) }
                VStack(spacing: 0) { Amount(text: s.fmt(out)); Text("sale").foregroundStyle(.secondary) }
            }
            .font(.system(size: 11))
            HStack(spacing: 3) { Text("Crédito"); Amount(text: s.fmt(last.debt)) }.font(.system(size: 11)).foregroundStyle(.secondary)
            Text("toca para ver los días").font(.system(size: 9)).foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture { day = Double(w * 7); byDay = true; WKInterfaceDevice.current().play(.click) }
        .focusable()
        .digitalCrownRotation($week, from: 0, through: 3, by: 1, sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
    }

    private func dayView(_ s: WatchSnapshot) -> some View {
        let i = min(s.days.count - 1, max(0, Int(day)))
        let d = s.days[i]
        return ScrollView {
            VStack(spacing: 4) {
                Button { byDay = false } label: { Label("Semanas", systemImage: "chevron.left").font(.system(size: 11)) }.buttonStyle(.plain).foregroundStyle(WatchTheme.accent)
                Text(dayLabel(d.iso)).font(.system(size: 13, weight: .semibold))
                HStack(spacing: 12) {
                    VStack(spacing: 0) { Amount(text: s.fmt(d.cash)).font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(d.cash < 0 ? .red : .primary); Text("caja").font(.system(size: 9)).foregroundStyle(.secondary) }
                    VStack(spacing: 0) { Amount(text: s.fmt(d.debt)).font(.system(size: 17, weight: .bold, design: .rounded)); Text("crédito").font(.system(size: 9)).foregroundStyle(.secondary) }
                }
                if d.events.isEmpty {
                    Text("Sin cobros ni ingresos").font(.system(size: 11)).foregroundStyle(.secondary).padding(.top, 4)
                }
                ForEach(Array(d.events.enumerated()), id: \.offset) { _, ev in
                    HStack { Text(ev.name).lineLimit(1); Spacer(); Amount(text: s.fmt(ev.amt, signed: true)).foregroundStyle(ev.amt > 0 ? WatchTheme.accent : .primary) }.font(.system(size: 11))
                }
            }
            .padding(.horizontal, 4)
        }
        .focusable()
        .digitalCrownRotation($day, from: 0, through: Double(s.days.count - 1), by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
    }

    private func short(_ iso: String) -> String {
        guard let d = DateFormatter.iso.date(from: iso) else { return iso }
        let f = DateFormatter(); f.dateFormat = "d MMM"; f.locale = Locale(identifier: "es")
        return f.string(from: d)
    }
    private func rangeLabel(_ a: String, _ b: String) -> String { short(a) + " – " + short(b) }
    private func dayLabel(_ iso: String) -> String {
        guard let d = DateFormatter.iso.date(from: iso) else { return iso }
        let f = DateFormatter(); f.dateFormat = "EEE d MMM"; f.locale = Locale(identifier: "es")
        return f.string(from: d).capitalized
    }
}
