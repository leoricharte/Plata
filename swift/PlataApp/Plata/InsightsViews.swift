import SwiftUI
import PlataCore

private func grad(_ m: InsightsModel, scoreOn: Bool) -> [Color] {
    if !m.hasPrev { return ["#B9B9C6", "#7B7B93", "#3A3A52", "#D8D8E6"].map { Color(hex: $0) } }
    return scoreOn && m.plus != .none ? GradePalette.tier(m.letter, m.plus) : GradePalette.letter(scoreOn ? m.letter : "B")
}

private func nickOf(_ e: Engine) -> String {
    let s = e.data["settings"]
    let n = Engine.text(s?["nick"]).trimmingCharacters(in: .whitespaces)
    return n.isEmpty ? Engine.text(s?["first"]).trimmingCharacters(in: .whitespaces) : n
}

/// Los banners de Insights en Resumen (`insightsBanner`): half‑time, cierre del mes o «¿Buscas tus insights?».
struct InsightsBanner: View {
    @Environment(AppModel.self) private var model
    let bottom: Bool

    var body: some View {
        let e = model.engine
        if e.insightsEnabled {
            let cm = e.insightsModel()
            let lk = e.insightsLocked(cm)
            let pm = e.insightsModel(month: Engine.previousMonthKey(cm.mk))
            let pOK = e.insightsLocked(pm) == nil
            let hOK = (e.isHalfTime(cm) && lk == nil) || e.firstHalfOn(cm)
            if bottom {
                if !(pOK || hOK || lk == nil), let lk { locked(lk, nickOf(e)) }
            } else {
                VStack(spacing: 14) {
                    if hOK { halfBanner(e, cm) }
                    if pOK { closeBanner(e, pm, "Cierre de") }
                    else if lk == nil { closeBanner(e, cm, "Insights de") }
                }
            }
        }
    }

    private func locked(_ left: String, _ nick: String) -> some View {
        VStack(spacing: 0) {
            Image(systemName: "questionmark.circle.fill").font(.system(size: 32)).foregroundStyle(Color(hex: "#8E8E93"))
            Text("¿Buscas tus insights?").font(.inter(20, .bold)).tracking(-0.3).padding(.top, 10).padding(.bottom, 4)
            Text("Aún no tenemos suficientes datos tuyos\(nick.isEmpty ? "" : ", \(nick)"). Necesitamos un mes de movimientos para aconsejarte.")
                .font(.inter(15)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Text("Vuelve a revisar en \(left).").font(.inter(15, .semibold)).padding(.top, 10)
        }
        .frame(maxWidth: .infinity).padding(18)
        .plataGlass(in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func closeBanner(_ e: Engine, _ m: InsightsModel, _ label: String) -> some View {
        let scoreOn = e.scoreEnabled
        let g = grad(m, scoreOn: scoreOn)
        let mes = Spanish.monthsFull[InsightsText.monthIndex(m.mk)]
        let title = !scoreOn ? "Tus tendencias de \(mes)." : m.hasPrev ? "Tu evaluación fue \(InsightsText.label(m.letter, m.plus))." : "Aún sin evaluación."
        return Button { model.path.append(.insights(mk: m.mk, half: false)) } label: {
            VStack(spacing: 0) {
                Text("\(label) \(mes)").font(.inter(15, .medium)).opacity(0.92)
                Text(title).font(.inter(26, .heavy)).tracking(-0.6).padding(.top, 2).padding(.bottom, 6).multilineTextAlignment(.center)
                if scoreOn {
                    Text(InsightsText.phrase(m, nick: nickOf(e), gender: Engine.text(e.data["settings"]?["gender"])))
                        .font(.inter(15)).opacity(0.95).multilineTextAlignment(.center).padding(.horizontal, 6).padding(.bottom, 14)
                } else { Spacer().frame(height: 8) }
                Text("Ver informe").font(.inter(17, .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(.white.opacity(0.14), in: Capsule())
            }
            .foregroundStyle(.white)
            .padding(18).frame(maxWidth: .infinity)
            .background(LinearGradient(colors: [Color(hex: "#2C2C2E"), Color(hex: "#0B0B0C")], startPoint: .top, endPoint: .bottom))
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.1), lineWidth: 1))
            .shadow(color: .black.opacity(0.12), radius: 12, y: 8)
        }
        .buttonStyle(.plain)
    }

    private func halfBanner(_ e: Engine, _ m: InsightsModel) -> some View {
        let first = e.firstHalfOn(m)
        let list = first ? InsightsText.halfFirst : InsightsText.half
        let y = Int(m.mk.prefix(4)) ?? 0
        let v = list[(y * 12 + InsightsText.monthIndex(m.mk)) % 3]
        let hl = m.hasPrev ? (e.halfSnap(m.mk)?.letter ?? e.insightsModel(month: m.mk, upTo: 15).letter) : "B"
        let hg = GradePalette.letter(hl)
        return Button { model.path.append(.insights(mk: m.mk, half: true)) } label: {
            VStack(spacing: 12) {
                HStack(spacing: 14) {
                    GhostScore(size: 56, letter: m.hasPrev ? hl : "?")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(v[0]).font(.inter(20, .heavy)).tracking(-0.4)
                            .foregroundStyle(LinearGradient(colors: [hg[0], hg[1], hg[2]], startPoint: .topLeading, endPoint: .bottomTrailing))
                        Text(v[1]).font(.inter(14, .medium)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                Text("Ver informe hasta ahora").font(.inter(16, .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 42)
                    .background(Brand.ink, in: Capsule())
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .plataGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct CatChange { let name: String; let now: Double; let before: Double }

/// El informe de Insights: nota, comparativa con el mes anterior, categorías, ritmo, lo más grande y lo comprometido.
struct InsightsView: View {
    @Environment(AppModel.self) private var model
    let mk: String
    let half: Bool

    private let good = Color(hex: "#138A55"), bad = Color(hex: "#D92D20"), mute = Color(hex: "#6C6C70")

    var body: some View {
        let e = model.engine
        let f = model.fmt
        let cm = e.insightsModel()
        let isHalf = half && (e.isHalfTime(cm) || e.firstHalfOn(cm))
        let pickMk = mk.isEmpty ? Engine.previousMonthKey(cm.mk) : mk
        let m0 = isHalf ? e.insightsModel(month: cm.mk, upTo: 15) : e.insightsModel(month: pickMk)
        let m = (!isHalf && !m0.hasPrev && mk.isEmpty) ? cm : m0
        let mesIdx = InsightsText.monthIndex(m.mk)
        let mes = Spanish.monthsFull[mesIdx]
        let pm = Spanish.monthsFull[InsightsText.monthIndex(m.pmk)]
        let eyebrow: String = isHalf ? "Hasta el día 15" : m.isCur ? ("\(mes.prefix(1).uppercased() + mes.dropFirst()) · día \(m.day)") : ("Cierre de \(mes)")
        ScrollView {
            VStack(spacing: 14) {
                PageHead(eyebrow: eyebrow, title: isHalf ? "Half‑time" : "Insights")
                if e.firstHalfOn(m) { firstHalfCard }
                if e.scoreEnabled { evaluation(e, m, isHalf, pm) }
                comparison(e, f, m, isHalf, pm)
                changedCategories(e, f, m, isHalf)
                if !(!m.isCur && !isHalf) { pace(e, f, m) }
                biggest(e, f, m, isHalf)
                committed(e, f, m, isHalf, pm)
            }
            .padding(.horizontal, 16).padding(.bottom, 24)
        }
        .syncRefresh()
        .plataBackground()
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: piezas

    private var firstHalfCard: some View {
        Card {
            Text("Tu primer cierre de mes se acerca").font(.inter(17, .semibold)).foregroundStyle(.primary)
            Text("Este es tu primer half‑time: una mirada a cómo vas a mitad de mes. Cuando el mes termine recibirás tu primera evaluación, de la F a la S.")
                .font(.inter(14)).foregroundStyle(.secondary)
        }
    }

    /// `--ink2` de la web (#3A3A3C claro, #D1D1D6 oscuro): el gris oscuro de los textos largos de una tarjeta.
    private static let ink2 = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.82, green: 0.82, blue: 0.84, alpha: 1) : UIColor(red: 0.227, green: 0.227, blue: 0.235, alpha: 1) })

    private func whyDot(_ hollow: Bool, _ color: Color) -> some View {
        Group {
            if hollow { Circle().strokeBorder(color, lineWidth: 1.5) } else { Circle().fill(color) }
        }
        .frame(width: 11, height: 11)
        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
    }

    private func tri(_ dir: Int, _ color: Color, _ size: CGFloat = 12) -> some View {
        Image(systemName: dir > 0 ? "arrowtriangle.up.fill" : dir < 0 ? "arrowtriangle.down.fill" : "minus").font(.system(size: size)).foregroundStyle(color)
    }

    private func chip(_ p: Double?, upIsBad: Bool) -> some View {
        Group {
            if let p {
                let up = p > 0.005, dn = p < -0.005
                if !up && !dn {
                    HStack(spacing: 4) { tri(0, mute); Text("igual").font(.inter(15, .semibold)).foregroundStyle(.secondary) }
                } else {
                    let ok = upIsBad ? dn : up
                    HStack(spacing: 4) {
                        tri(up ? 1 : -1, ok ? good : bad)
                        Text("\(Int((abs(p) * 100).rounded()))%").font(.inter(15, .semibold)).foregroundStyle(ok ? good : bad)
                    }
                }
            } else { Text("—").font(.inter(15)).foregroundStyle(.secondary) }
        }
    }

    private func pct(_ a: Double, _ b: Double) -> Double? { b > 0 ? (a - b) / b : nil }

    private func statRow<T: View>(_ label: String, _ value: String, sub: String, @ViewBuilder trailing: () -> T) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 0) {
                Text(label).font(.inter(14)).foregroundStyle(.secondary)
                Text(value).font(.inter(24, .bold)).tracking(-0.5)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                trailing()
                Text(sub).font(.inter(12)).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 12)
    }

    private func evaluation(_ e: Engine, _ m: InsightsModel, _ isHalf: Bool, _ pm: String) -> some View {
        let hs = e.halfSnap(m.mk)
        let hl: (letter: String, score: Int) = isHalf && hs != nil ? hs! : (m.letter, m.score)
        let dir = !m.hasPrev ? 0 : m.delta > 3 ? 1 : m.delta < -3 ? -1 : 0
        let dcol = dir > 0 ? good : dir < 0 ? bad : mute
        let closed = !m.isCur && !isHalf
        var why: [(Character, String)] = []
        if let ps = m.ps {
            let verb: String = closed ? "Gastaste " : "Gastas "
            let amount: String = "\(Int((abs(ps) * 100).rounded()))% "
            let dirWord: String = ps <= 0 ? "menos" : "más"
            let tail: String = closed ? "" : " a esta altura"
            why.append((ps <= 0 ? "▲" : "▼", verb + amount + dirWord + " que en " + pm + tail))
        }
        if let rc = m.rateC {
            let ahead = m.rateP != nil && rc >= (m.rateP ?? 0)
            let lead: String = closed ? "Ahorraste el " : "Estás ahorrando el "
            var line: String = lead + "\(Int((rc * 100).rounded()))% de tus ingresos"
            if let rp = m.rateP { line += " (antes \(Int((rp * 100).rounded()))%)" }
            why.append((ahead ? "▲" : "▼", line))
        }
        if m.limCount > 0 { why.append((m.within == m.limCount ? "▲" : "▼", "\(m.within) de \(m.limCount) categorías dentro de su límite")) }
        if m.contrib { why.append(("▲", "Aportaste a tus metas este mes (+5 de bonus)")) }
        else if !(e.data["savings"]?.arrayValue ?? []).isEmpty { why.append(("○", "Aportar a una meta suma un bonus extra")) }
        let headline = !m.hasPrev ? "Aún sin mes anterior para comparar" : dir > 0 ? "Vas mejor que en \(pm)" : dir < 0 ? "Vas peor que en \(pm)" : "Vas igual que en \(pm)"
        let detail = m.hasPrev ? (InsightsText.adjective[hl.letter] ?? "") + " · \(hl.score) de 100" : "Tu primera evaluación llega al cerrar el mes"
        return Card {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(headline).font(.inter(17, .semibold)).foregroundStyle(.primary)
                    Text(detail).font(.inter(13)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if m.hasPrev { tri(dir, dcol, 22) }
                if isHalf || !m.hasPrev { GhostScore(size: 64, letter: m.hasPrev ? hl.letter : "?") }
                else { GradeTile(letter: m.letter, level: m.plus, size: 64) }
            }
            if m.hasPrev {
                Text(isHalf ? (InsightsText.halfEvaluation[hl.letter] ?? InsightsText.halfEvaluation["B"]!) : (InsightsText.evaluation[m.letter] ?? InsightsText.evaluation["B"]!))
                    .font(.inter(14)).foregroundStyle(Self.ink2).padding(.top, 10)
                if !isHalf { StreakRow(letter: m.letter, streak: m.streak, level: m.plus) }
                if !isHalf, let hs {
                    HStack(spacing: 8) {
                        Text("Half‑time").font(.inter(14, .semibold))
                        GhostScore(size: 28, letter: hs.letter)
                        Text("→").foregroundStyle(.secondary)
                        GradeTile(letter: m.letter, level: m.plus, size: 28)
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 10)
                }
            }
            if !isHalf {
                Divider().padding(.top, 8)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(why.enumerated()), id: \.offset) { _, w in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            whyDot(w.0 == "○", w.0 == "▲" ? good : w.0 == "○" ? mute : bad)
                            Text(w.1).font(.inter(14)).foregroundStyle(Self.ink2)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private func comparison(_ e: Engine, _ f: Fmt, _ m: InsightsModel, _ isHalf: Bool, _ pm: String) -> some View {
        let closed = !m.isCur && !isHalf
        let vs = m.hasPrev ? "vs. \(pm)" + (m.est ? " (aprox.)" : "") : "sin mes anterior"
        let netC = m.cur.inc - m.cur.exp, netP = m.prev.inc - m.prev.exp
        return VStack(alignment: .leading, spacing: 8) {
            SectionHead(closed ? ("Cierre vs. \(pm)") : ("Este mes vs. \(pm)"), gap: 0)
            ListCard {
                statRow("Gastado", f.whole(m.cur.exp), sub: vs) { chip(pct(m.cur.exp, m.prev.exp), upIsBad: true) }
                if !isHalf {
                    RowDivider()
                    statRow("Ingresos", f.whole(m.cur.inc), sub: vs) { chip(pct(m.cur.inc, m.prev.inc), upIsBad: false) }
                }
                RowDivider()
                statRow("Te quedó libre", f.whole(netC), sub: vs) {
                    if !m.hasPrev { Text("—").font(.inter(15)).foregroundStyle(.secondary) }
                    else if abs(netC - netP) < 1 { Text("igual").font(.inter(15, .semibold)).foregroundStyle(.secondary) }
                    else {
                        HStack(spacing: 4) {
                            tri(netC >= netP ? 1 : -1, netC >= netP ? good : bad)
                            Text(f.whole(abs(netC - netP))).font(.inter(15, .semibold)).foregroundStyle(netC >= netP ? good : bad)
                        }
                    }
                }
            }
        }
    }

    private func topChanges(_ e: Engine, _ m: InsightsModel) -> [CatChange] {
        var all: [CatChange] = []
        for k in e.categoryNames {
            let a: Double = m.cur.cat[k] ?? 0
            let b: Double = m.prev.cat[k] ?? 0
            if a > 0 || b > 0 { all.append(CatChange(name: k, now: a, before: b)) }
        }
        all.sort { (x: CatChange, y: CatChange) -> Bool in abs(x.now - x.before) > abs(y.now - y.before) }
        return Array(all.prefix(3))
    }

    @ViewBuilder
    private func changedCategories(_ e: Engine, _ f: Fmt, _ m: InsightsModel, _ isHalf: Bool) -> some View {
        let rows = topChanges(e, m)
        if !isHalf, m.prev.n > 0, !rows.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionHead("Categorías que más cambiaron", gap: 0)
                ListCard {
                    ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                        if i > 0 { RowDivider() }
                        HStack(spacing: 12) {
                            CategoryTile(engine: e, name: r.name, color: Color(hex: e.categoryColor(r.name)))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.name).font(.inter(16, .semibold)).tracking(-0.3)
                                Text("\(f.whole(r.before)) → \(f.whole(r.now))").font(.inter(13)).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            if r.before > 0 { chip((r.now - r.before) / r.before, upIsBad: true) } else { Text("nuevo").font(.inter(15, .semibold)).foregroundStyle(.secondary) }
                        }
                        .padding(.vertical, 10)
                    }
                }
            }
        }
    }

    private func pace(_ e: Engine, _ f: Fmt, _ m: InsightsModel) -> some View {
        let c = e.calc()
        let fixed = m.cur.cat["Alquiler"] ?? 0
        let proj = m.day > 0 ? fixed + (m.cur.expV - fixed) / Double(m.day) * Double(m.dim) : 0
        let over = c.budgetTotal > 0 && proj > c.budgetTotal
        return VStack(alignment: .leading, spacing: 8) {
            SectionHead("Ritmo de gasto", gap: 0)
            Card {
                (Text("Al ritmo actual cerrarías el mes gastando ") + Text(f.whole(proj)).bold().foregroundColor(.primary) + Text("."))
                    .font(.inter(15)).foregroundStyle(.secondary)
                if c.budgetTotal > 0 {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(.tertiarySystemFill))
                            Capsule().fill(over ? Color(hex: "#FF3B30") : Brand.accent).frame(width: g.size.width * min(1, proj / c.budgetTotal))
                        }
                    }
                    .frame(height: 8).padding(.vertical, 4)
                    Text(over ? "Te pasarías \(f.whole(proj - c.budgetTotal)) de tu presupuesto de \(f.whole(c.budgetTotal))"
                              : "Quedarías \(f.whole(c.budgetTotal - proj)) por debajo de tu presupuesto de \(f.whole(c.budgetTotal))")
                        .font(.inter(14, .semibold)).foregroundStyle(over ? bad : good)
                }
            }
        }
    }

    @ViewBuilder
    private func biggest(_ e: Engine, _ f: Fmt, _ m: InsightsModel, _ isHalf: Bool) -> some View {
        let big = e.allTransactions
            .filter { String(Engine.text($0["date"]).prefix(7)) == m.mk && !e.isCreditPayment($0) && Engine.number($0["amount"]) < 0 }
            .min { e.amountUSD($0) < e.amountUSD($1) }
        if !isHalf, let big {
            VStack(alignment: .leading, spacing: 8) {
                SectionHead("Tu gasto más grande", gap: 0)
                ListCard {
                    NavigationLink(value: Route.tx(Engine.identifier(big["id"]))) { TransactionRow(tx: big, engine: e, fmt: f) }.buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func committed(_ e: Engine, _ f: Fmt, _ m: InsightsModel, _ isHalf: Bool, _ pm: String) -> some View {
        let c = e.calc()
        if !isHalf, c.subsTotal > 0 {
            VStack(alignment: .leading, spacing: 8) {
                SectionHead("Ya comprometido", gap: 0)
                Card {
                    let pctText = m.cur.inc > 0 ? ", el " + "\(Int((c.subsTotal / m.cur.inc * 100).rounded()))%" + " de lo que has ingresado este mes" : ""
                    Text("Tus servicios y suscripciones suman \(f.whole(c.subsTotal)) al mes\(pctText).")
                        .font(.inter(15)).foregroundStyle(.secondary)
                    if let sg = m.sg, sg.n > 0 || abs(sg.d) > 0.005 {
                        Text((sg.n > 0 ? Spanish.plural(sg.n, "suscripción nueva", "suscripciones nuevas") + " · " : "") + (sg.d >= 0 ? "+" : "−") + f.whole(abs(sg.d)) + " al mes frente a \(pm)")
                            .font(.inter(15, .semibold)).foregroundStyle(sg.d > 0.005 ? bad : good).padding(.top, 4)
                    }
                }
            }
        }
    }
}
