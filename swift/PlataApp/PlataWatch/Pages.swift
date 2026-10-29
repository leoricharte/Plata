import SwiftUI
import WatchKit
import UIKit

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
    var body: some View { Text(dim ? "●●●●" : text) }
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

extension Color {
    init(watchHex h: String?) {
        let t = (h ?? "").replacingOccurrences(of: "#", with: "")
        guard t.count == 6, let v = UInt32(t, radix: 16) else { self = WatchTheme.accent; return }
        self = Color(red: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255, blue: Double(v & 255) / 255)
    }
}

/// Texto pegado a un arco: termina justo arriba (a las 12) y se lee hacia ahí, como en un anillo de Actividad.
struct CurvedLabel: View {
    var text: String
    var radius: CGFloat
    var size: CGFloat
    var body: some View {
        let chars = Array(text.uppercased())
        let step = Double(size * 0.78 / radius) * 180 / .pi   // grados por letra
        ZStack {
            ForEach(Array(chars.enumerated()), id: \.offset) { i, ch in
                let angle = -Double(chars.count - i) * step - 3
                Text(String(ch))
                    .font(.system(size: size, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.45), radius: 0.6)
                    .offset(y: -radius)
                    .rotationEffect(.degrees(angle))
            }
        }
    }
}

struct BudgetPage: View {
    @Environment(WatchStore.self) private var store
    @State private var expanded = false

    var body: some View {
        if let s = store.snapshot {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 8) {
                        if !s.letter.isEmpty {
                            Text("\(s.letter) • \(s.adjective)").font(.system(size: 14, weight: .semibold)).foregroundStyle(WatchTheme.accent)
                        }
                        rings(s)
                            .onTapGesture {
                                withAnimation { expanded.toggle() }
                                WKInterfaceDevice.current().play(.click)
                                if !expanded { DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { withAnimation { proxy.scrollTo("lista", anchor: .top) } } }
                            }
                        if s.allowance > 0 {
                            let left = s.allowance - s.spentToday
                            VStack(spacing: 0) {
                                Amount(text: s.fmt(abs(left))).font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(left < 0 ? .red : .primary)
                                Text(left < 0 ? "pasado hoy" : "te quedan hoy").font(.system(size: 13)).foregroundStyle(.secondary)
                            }
                        } else {
                            Text(s.cats.isEmpty ? "Sin presupuesto este mes" : "Presupuesto del mes agotado").font(.system(size: 14)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                        if !s.cats.isEmpty && !expanded {
                            Text("Toca el círculo para ver todos").font(.system(size: 11)).foregroundStyle(.tertiary)
                        }
                        if expanded {
                            VStack(spacing: 8) {
                                ForEach(s.cats, id: \.name) { c in
                                    let r = c.limit > 0 ? c.spent / c.limit : 0
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack { Text(c.name).lineLimit(1); Spacer(); Amount(text: s.fmt(c.spent)) }.font(.system(size: 14, weight: .medium))
                                        ProgressView(value: min(1, r)).tint(r >= 1 ? .red : Color(watchHex: c.color))
                                    }
                                }
                            }
                            .id("lista")
                        }
                        SyncNote().padding(.top, 4)
                    }
                    .padding(.horizontal, 6)
                }
            }
        } else {
            VStack { SyncNote() }
        }
    }

    /// Hasta 4 anillos concéntricos (las categorías con más uso), cada uno de su color y con su nombre curvado.
    private func rings(_ s: WatchSnapshot) -> some View {
        let top = Array(s.cats.prefix(4))
        let width: CGFloat = 12, gap: CGFloat = 2, outer: CGFloat = 78
        let items: [(name: String, frac: Double, color: Color)] = top.isEmpty
            ? [("Hoy", s.allowance > 0 ? s.spentToday / s.allowance : 0, WatchTheme.accent)]
            : top.map { ($0.name, $0.limit > 0 ? $0.spent / $0.limit : 0, Color(watchHex: $0.color)) }
        return ZStack {
            ForEach(Array(items.enumerated()), id: \.offset) { i, it in
                let radius = outer - CGFloat(i) * (width + gap) - width / 2
                ZStack {
                    ActivityRing(frac: it.frac, color: it.color, width: width, radius: radius)
                    CurvedLabel(text: String(it.name.prefix(12)), radius: radius, size: 8.5)
                }
                .frame(width: radius * 2, height: radius * 2)
            }
            VStack(spacing: 0) {
                Amount(text: s.fmt(s.spentToday)).font(.system(size: 14, weight: .bold, design: .rounded)).minimumScaleFactor(0.5).lineLimit(1)
                Text("hoy").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            .frame(width: 46)
        }
        .frame(width: 160, height: 160)
        .contentShape(Circle())
    }
}

/// Un anillo como los de Actividad: la pista tenue, el progreso con degradado y, si pasas del 100 %, una segunda vuelta con sombra.
struct ActivityRing: View {
    var frac: Double
    var color: Color
    var width: CGFloat
    var radius: CGFloat
    var body: some View {
        let lap = min(1, max(0.004, frac))
        let extra = min(1, max(0, frac - 1))
        ZStack {
            Circle().stroke(color.opacity(0.25), lineWidth: width)
            Circle().trim(from: 0, to: lap)
                .stroke(AngularGradient(colors: [color.opacity(0.65), color], center: .center, startAngle: .degrees(0), endAngle: .degrees(max(1, 360 * lap))),
                        style: StrokeStyle(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if extra > 0 {
                Circle().trim(from: 0, to: extra)
                    .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: .black.opacity(0.55), radius: 3)
            }
        }
    }
}

// MARK: añadir

struct AddPage: View {
    @Environment(WatchStore.self) private var store
    @State private var crown = 500.0
    @State private var lastCrown = 500.0
    @State private var lastTick = Date.distantPast
    @State private var streakStart = Date.distantPast
    @State private var value = 0.0
    @State private var isOut = true
    @State private var category = ""
    @State private var editing = false
    @State private var typedText = ""
    private enum Step: Hashable { case category, account }
    @State private var path: [Step] = []

    var body: some View {
        if let s = store.snapshot {
            if store.pending != nil { done(s) } else { form(s) }
        } else {
            VStack { SyncNote() }
        }
    }

    /// Corona con tres velocidades: lento = de a 0.01 (preciso); normal = de a 0.25; rápido y sostenido = acelera (1, 5, 25).
    private func turned(to new: Double) {
        let now = Date()
        let d0 = new - lastCrown
        lastCrown = new
        if abs(new - 500) > 400 { crown = 500; lastCrown = 500; return }   // recentra sin saltos
        guard d0 != 0 else { return }
        let dt = max(0.016, now.timeIntervalSince(lastTick))
        if dt > 0.35 { streakStart = now }
        lastTick = now
        let rate = abs(d0) / dt                       // vueltas por segundo
        let sustained = now.timeIntervalSince(streakStart)
        let unit: Double
        switch rate {
        case ..<0.45: unit = 0.01
        case ..<1.3: unit = 0.25
        case ..<2.6: unit = sustained > 0.8 ? 1 : 0.25
        default: unit = sustained > 1.6 ? 25 : sustained > 0.8 ? 5 : 1
        }
        let before = value
        value = max(0, ((value + (d0 < 0 ? -1 : 1) * abs(d0) * 24 * unit) * 100).rounded() / 100)
        let q = max(unit, 0.25)
        if (before / q).rounded(.down) != (value / q).rounded(.down) { WKInterfaceDevice.current().play(.click) }
    }

    private func done(_ s: WatchSnapshot) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 34)).foregroundStyle(WatchTheme.accent)
            Text("Anotado").font(.system(size: 15, weight: .semibold))
            Button("Deshacer") { store.undo() }.buttonStyle(.bordered)
        }
    }

    private func form(_ s: WatchSnapshot) -> some View {
        NavigationStack(path: $path) {
            amountView(s)
                .navigationDestination(for: Step.self) { st in
                    switch st {
                    case .category: categoryView(s).navigationTitle("Categoría")
                    case .account: accountView(s).navigationTitle("Cuenta")
                    }
                }
        }
        .sheet(isPresented: $editing) {
            VStack {
                TextField("Monto", text: $typedText)
                Button("Listo") { if let v = Double(typedText.replacingOccurrences(of: ",", with: ".")) { value = max(0, v) }; editing = false }
            }
        }
    }

    /// Paso 1: solo el monto, sin scroll, para que la corona sea del monto.
    private func amountView(_ s: WatchSnapshot) -> some View {
        VStack(spacing: 6) {
            Button { isOut.toggle() } label: {
                Text(isOut ? "Gasto" : "Ingreso").font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isOut ? Color.secondary : WatchTheme.accent)
            }.buttonStyle(.plain)
            Button { editing = true; typedText = "" } label: {
                Amount(text: (isOut ? "-" : "+") + WatchFormat.money(value, sym: s.sym, dec: 2))
                    .font(.system(size: 34, weight: .bold, design: .rounded)).minimumScaleFactor(0.5).lineLimit(1)
                    .foregroundStyle(isOut ? Color.primary : WatchTheme.accent)
            }
            .buttonStyle(.plain)
            Text("Gira la corona · toca el monto para escribirlo").font(.system(size: 11)).foregroundStyle(.secondary).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Button { path = [isOut ? .category : .account] } label: { Text("Siguiente").font(.system(size: 13, weight: .semibold)).frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).controlSize(.small).tint(WatchTheme.accent).disabled(value <= 0)
            SyncNote()
        }
        .padding(.horizontal, 6)
        .focusable()
        .digitalCrownRotation($crown, from: 0, through: 1000, by: nil, sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: false)
        .onChange(of: crown) { _, n in turned(to: n) }
    }

    /// Paso 2 (gastos): categoría en una cuadrícula de iconos grandes, como el Centro de Control.
    private func categoryView(_ s: WatchSnapshot) -> some View {
        let cats = s.catInfo ?? s.categories.map { WatchCategory(name: $0, label: $0, symbol: "tag.fill", color: "") }
        return ScrollView {
            VStack(spacing: 8) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(cats, id: \.name) { c in
                        Button { category = c.name; path.append(.account); WKInterfaceDevice.current().play(.click) } label: {
                            VStack(spacing: 4) {
                                Image(systemName: c.symbol).font(.system(size: 26, weight: .semibold)).foregroundStyle(Color(watchHex: c.color))
                                    .frame(width: 52, height: 52).background(Color(watchHex: c.color).opacity(0.22), in: Circle())
                                Text(c.label).font(.system(size: 12, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    /// Paso 3: cuenta o tarjeta, en una lista como la de apps del reloj.
    private func accountView(_ s: WatchSnapshot) -> some View {
        List {
            ForEach(s.accounts, id: \.id) { a in
                Button { save(account: a.id) } label: {
                    HStack(spacing: 10) {
                        accountIcon(a)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(a.name).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                            if let l4 = a.last4 { Text((a.credit == true ? "Crédito " : "") + "•••• " + l4).font(.system(size: 12)).foregroundStyle(.secondary) }
                            else if a.credit == true { Text("Crédito").font(.system(size: 12)).foregroundStyle(.secondary) }
                        }
                    }
                }
            }
        }
        .listStyle(.carousel)
    }

    /// Solo el glifo del logo real (sin fondo); si no hay uno, el símbolo de siempre.
    @ViewBuilder private func accountIcon(_ a: WatchAccount) -> some View {
        if let d = a.logo, let img = UIImage(data: d) {
            Image(uiImage: img).renderingMode(.template).resizable().scaledToFit().frame(width: 26, height: 26).foregroundStyle(.white)
        } else {
            Image(systemName: a.symbol ?? "creditcard.fill").font(.system(size: 20)).foregroundStyle(.white).frame(width: 26, height: 26)
        }
    }

    private func save(account: String) {
        let iso = DateFormatter.iso.string(from: Date())
        store.add(WatchEntry(id: UUID().uuidString, amount: isOut ? -value : value, category: isOut ? category : "Ingreso", account: account, note: "", date: iso))
        value = 0; path = []
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
            NavigationStack {
                weekView(s)
                    .navigationDestination(isPresented: $byDay) { dayView(s).navigationTitle(dayLabel(s.days[min(s.days.count - 1, max(0, Int(day)))].iso)) }
            }
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
            Text(w == 0 ? "Esta semana" : "Semana \(w + 1)").font(.system(size: 17, weight: .semibold)).foregroundStyle(WatchTheme.accent)
            Text(rangeLabel(days.first!.iso, last.iso)).font(.system(size: 13)).foregroundStyle(.secondary)
            Amount(text: s.fmt(last.cash)).font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(last.cash < 0 ? .red : .primary)
            Text("en caja").font(.system(size: 13)).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                VStack(spacing: 0) { Amount(text: s.fmt(inc, signed: true)).foregroundStyle(WatchTheme.accent); Text("entra") .foregroundStyle(.secondary) }
                VStack(spacing: 0) { Amount(text: s.fmt(out)); Text("sale").foregroundStyle(.secondary) }
            }
            .font(.system(size: 14, weight: .medium))
            if s.hasCredit { HStack(spacing: 3) { Text("Crédito disp."); Amount(text: s.fmt(last.credit)) }.font(.system(size: 13)).foregroundStyle(.secondary) }
            Text("toca para ver los días").font(.system(size: 11)).foregroundStyle(.tertiary)
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
                HStack(spacing: 12) {
                    VStack(spacing: 0) { Amount(text: s.fmt(d.cash)).font(.system(size: 21, weight: .bold, design: .rounded)).foregroundStyle(d.cash < 0 ? .red : .primary); Text("caja").font(.system(size: 12)).foregroundStyle(.secondary) }
                    if s.hasCredit { VStack(spacing: 0) { Amount(text: s.fmt(d.credit)).font(.system(size: 21, weight: .bold, design: .rounded)); Text("crédito disp.").font(.system(size: 12)).foregroundStyle(.secondary) } }
                }
                if d.events.isEmpty {
                    Text("Sin cobros ni ingresos").font(.system(size: 14)).foregroundStyle(.secondary).padding(.top, 4)
                }
                ForEach(Array(d.events.enumerated()), id: \.offset) { _, ev in
                    HStack { Text(ev.name).lineLimit(1); Spacer(); Amount(text: s.fmt(ev.amt, signed: true)).foregroundStyle(ev.amt > 0 ? WatchTheme.accent : .primary) }.font(.system(size: 14))
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
