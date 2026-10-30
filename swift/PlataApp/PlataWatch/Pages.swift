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

extension Color {
    /// El mismo tono, muy oscuro: para el texto y el icono que van encima de un aro de ese color.
    init(watchDark h: String?) {
        let t = (h ?? "").replacingOccurrences(of: "#", with: "")
        guard t.count == 6, let v = UInt32(t, radix: 16) else { self = Color(white: 0.08); return }
        let k = 0.30
        self = Color(red: Double((v >> 16) & 255) / 255 * k, green: Double((v >> 8) & 255) / 255 * k, blue: Double(v & 255) / 255 * k)
    }
}

/// Texto pegado a un arco, en el sentido del reloj desde `start` (grados desde las 12), con letras espaciadas.
struct CurvedLabel: View {
    var text: String
    var radius: CGFloat
    var size: CGFloat
    var start: Double = 4
    var color: Color = .black

    private static func weight(_ ch: Character) -> Double {
        switch ch {
        case "I", "·", " ", "1", ".", ",": return 0.55
        case "M", "W", "%": return 1.2
        default: return 1
        }
    }
    private static func step(_ ch: Character, radius: CGFloat, size: CGFloat) -> Double { Double(size * 0.98) * weight(ch) / Double(radius) * 180 / .pi }
    /// Grados que ocupa un texto en un arco de ese radio.
    static func span(_ text: String, radius: CGFloat, size: CGFloat) -> Double { text.uppercased().reduce(0) { $0 + step($1, radius: radius, size: size) } }

    var body: some View {
        let chars = Array(text.uppercased())
        let angles: [Double] = {
            var a = start, out: [Double] = []
            for ch in chars { let st = Self.step(ch, radius: radius, size: size); out.append(a + st / 2); a += st }
            return out
        }()
        ZStack {
            ForEach(Array(chars.enumerated()), id: \.offset) { i, ch in
                Text(String(ch))
                    .font(.system(size: size, weight: .heavy, design: .rounded))
                    .foregroundStyle(color)
                    .offset(y: -radius)
                    .rotationEffect(.degrees(angles[i]))
            }
        }
    }
}

struct BudgetPage: View {
    @Environment(WatchStore.self) private var store
    @State private var expanded = false

    var body: some View {
        if let s = store.snapshot {
            GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 8) {
                        rings(s)
                        if s.allowance > 0 {
                            let left = s.allowance - s.spentToday
                            VStack(spacing: 0) {
                                Amount(text: s.fmt(abs(left))).font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(left < 0 ? .red : .primary)
                                Text(left < 0 ? "pasado hoy" : "te quedan hoy").font(.system(size: 13)).foregroundStyle(.secondary)
                            }
                        } else if !hidden {
                            if !s.cats.isEmpty && (s.monthBudget ?? 0) > 0 {
                                Amount(text: s.fmt(max(0, -(s.monthLeft ?? 0)))).font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(.red)
                                    .minimumScaleFactor(0.6).lineLimit(1)
                            }
                            Text(s.cats.isEmpty ? "Sin presupuesto este mes" : "Presupuesto del mes agotado").font(.system(size: 14)).foregroundStyle(.secondary).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                        }
                        if !s.cats.isEmpty && !expanded && !hidden {
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
                        if !hidden { SyncNote().padding(.top, 4) }
                    }
                    .padding(.horizontal, 6)
                    .frame(maxWidth: .infinity, minHeight: geo.size.height)   // sin lo demás, el aro queda centrado en la pantalla
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation { expanded.toggle() }
                        WKInterfaceDevice.current().play(.click)
                        if !expanded { DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { withAnimation { proxy.scrollTo("lista", anchor: .top) } } }
                    }
                }
            }
            }
        } else {
            VStack { SyncNote() }
        }
    }

    /// Con el presupuesto del mes agotado solo se ven los aros y «Presupuesto del mes agotado»; el resto aparece al tocar la pantalla.
    private var hidden: Bool {
        guard let s = store.snapshot else { return false }
        return s.allowance <= 0 && (s.monthBudget ?? 0) > 0 && !s.cats.isEmpty && !expanded
    }

    /// Con categorías que tienen tope: hasta 3 aros concéntricos (los de más gasto), cada uno con el icono de su categoría en la punta
    /// y su nombre curvado. Sin categorías: un solo aro grande (lo gastado hoy contra el tope del día).
    /// Si ya te pasaste del presupuesto del mes, el centro dice cuánto en rojo (igual que el iPhone).
    @ViewBuilder private func rings(_ s: WatchSnapshot) -> some View {
        let top = Array(s.cats.prefix(3))
        // el dibujo se compone en 160 pt y se escala para llenar el ancho del reloj
        let d = min(WKInterfaceDevice.current().screenBounds.width * 0.84, 180)
        let k = d / 160
        Group { if top.isEmpty { singleRing(s) } else { multiRing(s, top) } }
            .scaleEffect(k)
            .frame(width: 160 * k, height: 160 * k)
    }

    private func multiRing(_ s: WatchSnapshot, _ top: [WatchCat]) -> some View {
        let width: CGFloat = 16, gap: CGFloat = 3, outer: CGFloat = 80
        return ZStack {
            ForEach(Array(top.enumerated()), id: \.offset) { i, c in
                let radius = outer - width / 2 - CGFloat(i) * (width + gap)
                CategoryRing(cat: c, symbol: s.catInfo?.first { $0.label == c.name }?.symbol ?? "circle.fill", width: width, radius: radius)
                    .frame(width: radius * 2, height: radius * 2)
            }
        }
        .frame(width: 160, height: 160)
        .contentShape(Circle())
    }

    /// Un solo aro grande y grueso, como el de Actividad: lo gastado hoy al centro y, debajo, de cuánto es el tope del día.
    private func singleRing(_ s: WatchSnapshot) -> some View {
        let exhausted = s.allowance <= 0 && (s.monthBudget ?? 0) > 0
        let over = max(0, -(s.monthLeft ?? 0))
        let frac = exhausted ? 1 : (s.allowance > 0 ? s.spentToday / s.allowance : 0)
        let color: Color = (exhausted || frac > 1) ? .red : WatchTheme.accent
        return ZStack {
            ActivityRing(frac: frac, color: color, width: 20, radius: 68, arrow: !exhausted)
                .frame(width: 136, height: 136)
            VStack(spacing: 0) {
                Amount(text: s.fmt(exhausted ? over : s.spentToday)).font(.system(size: 32, weight: .semibold, design: .rounded)).minimumScaleFactor(0.5).lineLimit(1)
                    .foregroundStyle(exhausted ? .red : .primary)
                Text(exhausted ? "te pasaste" : (s.allowance > 0 ? "de \(s.fmt(s.allowance))" : "hoy")).textCase(.uppercase)
                    .font(.system(size: 11, weight: .semibold)).tracking(0.4).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.6)
            }
            .frame(width: 96)
        }
        .frame(width: 160, height: 160)
        .contentShape(Circle())
    }
}

/// Un aro de categoría: su avance (como mucho una vuelta), el icono en la punta y, sobre el color, el nombre y el porcentaje curvados en un tono oscuro.
struct CategoryRing: View {
    var cat: WatchCat
    var symbol: String
    var width: CGFloat
    var radius: CGFloat

    var body: some View {
        let frac = cat.limit > 0 ? cat.spent / cat.limit : 0
        let size: CGFloat = 9.5
        let iconSize = width * 0.62
        let dark = Color(watchDark: cat.color)
        let toDeg = 180 / Double.pi
        let iconHalf = Double((iconSize / 2 + 1) / radius) * toDeg
        let tip = 360 * min(1, max(0, frac))
        let start = Double(width * 0.35 / radius) * toDeg + 3          // pasada la tapa redonda del arranque
        let end = (frac >= 1 ? 360 : tip) - iconHalf - 3               // antes del icono
        let avail = end - (frac >= 1 ? max(start, iconHalf + 3) : start)
        let begin = frac >= 1 ? max(start, iconHalf + 3) : start
        let pct = " · " + String(Int((frac * 100).rounded())) + "%"
        let label = Self.fit(cat.name, pct, avail: avail, radius: radius, size: size)
        return ZStack {
            ActivityRing(frac: frac, color: Color(watchHex: cat.color), width: width, radius: radius, symbol: symbol, iconSize: iconSize, iconColor: dark)
            if let label { CurvedLabel(text: label, radius: radius, size: size, start: begin, color: dark) }
        }
    }

    /// El texto más completo que cabe: «Nombre · 12 %», luego el nombre recortado con «…», luego solo el nombre.
    private static func fit(_ name: String, _ pct: String, avail: Double, radius: CGFloat, size: CGFloat) -> String? {
        guard avail > 0 else { return nil }
        func ok(_ t: String) -> Bool { CurvedLabel.span(t, radius: radius, size: size) <= avail }
        var n = name.count
        while n >= 3 {
            let nm = n == name.count ? name : String(name.prefix(n - 1)) + "…"
            if ok(nm + pct) { return nm + pct }
            n -= 1
        }
        n = name.count
        while n >= 3 {
            let nm = n == name.count ? name : String(name.prefix(n - 1)) + "…"
            if ok(nm) { return nm }
            n -= 1
        }
        return nil
    }
}

/// Un anillo como los de Actividad: la pista tenue y el progreso con degradado. Se queda en una sola vuelta aunque te pases.
struct ActivityRing: View {
    var frac: Double
    var color: Color
    var width: CGFloat
    var radius: CGFloat
    var arrow = false
    var symbol: String? = nil          // icono de la categoría en la punta (en vez de la flecha)
    var iconSize: CGFloat = 9
    var iconColor: Color = .black.opacity(0.75)
    var body: some View {
        let lap = min(1, max(0.004, frac))
        ZStack {
            Circle().stroke(color.opacity(0.25), lineWidth: width)
            Circle().trim(from: 0, to: lap)
                .stroke(AngularGradient(colors: [color.opacity(0.65), color], center: .center, startAngle: .degrees(0), endAngle: .degrees(max(1, 360 * lap))),
                        style: StrokeStyle(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if let symbol {
                let deg = frac > 0.02 ? 360 * lap : 0
                Image(systemName: symbol).font(.system(size: iconSize, weight: .heavy)).foregroundStyle(iconColor)
                    .offset(x: radius * CGFloat(sin(deg * .pi / 180)), y: -radius * CGFloat(cos(deg * .pi / 180)))
            } else if arrow && frac > 0.02 {
                let deg = 360 * lap
                Image(systemName: "arrow.right").font(.system(size: width * 0.6, weight: .heavy)).foregroundStyle(.black.opacity(0.7))
                    .rotationEffect(.degrees(deg))
                    .offset(x: radius * CGFloat(sin(deg * .pi / 180)), y: -radius * CGFloat(cos(deg * .pi / 180)))
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
    @State private var lastDir = 1.0
    @State private var crownAcc = 0.0
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

    /// Corona estable: cada muesca suma o resta de a 0.25. Si el usuario sigue girando sin pausa en el mismo sentido,
    /// el paso crece poco a poco (0.25 → 0.5 → 1 → 2 → 5 → 10 → 25); al pausar o cambiar de sentido vuelve a 0.25.
    private static let ladder: [Double] = [0.25, 0.5, 1, 2, 5, 10, 25]
    private func turned(to new: Double) {
        let now = Date()
        let d0 = new - lastCrown
        lastCrown = new
        if abs(new - 500) > 400 { crown = 500; lastCrown = 500; return }   // recentra sin saltos
        guard d0 != 0 else { return }
        let dir: Double = d0 < 0 ? -1 : 1
        if now.timeIntervalSince(lastTick) > 0.35 || dir != lastDir { streakStart = now; crownAcc = 0 }   // pausa o giro inverso: otra vez a 0.25
        lastTick = now
        lastDir = dir
        crownAcc += abs(d0) * 24                       // 24 muescas por vuelta
        let sustained = now.timeIntervalSince(streakStart)
        let rung = min(Self.ladder.count - 1, Int(sustained / 0.9))   // un escalón cada ~0.9 s seguidos
        let unit = Self.ladder[rung]
        var moved = false
        while crownAcc >= 1 {
            crownAcc -= 1
            var v = value
            if v.truncatingRemainder(dividingBy: 0.25) != 0 { v = dir > 0 ? (v / 0.25).rounded(.up) * 0.25 : (v / 0.25).rounded(.down) * 0.25 }
            else { v += dir * unit }
            value = max(0, (v * 100).rounded() / 100)
            moved = true
        }
        if moved { WKInterfaceDevice.current().play(.click) }
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
            Image(uiImage: img).renderingMode(.template).resizable().scaledToFit().frame(width: 26, height: 26).foregroundStyle(WatchTheme.accent)
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
