import Foundation
import PlataCore

/// Un hito del historial de una suscripción (`subHist` de la web).
struct SubHistoryEvent: Identifiable {
    let id = UUID()
    let date: String
    let color: String
    let title: String
    let detail: String
}

struct SubHistorySummary {
    let since: String
    let charges: Int
    let breaks: Int
    let events: [SubHistoryEvent]
}

/// Inicio, cambios de precio o cuenta, atrasos, quiebres y fin de una suscripción; se recalcula con los movimientos que haya.
enum SubHistory {
    private static let green = "#22B573", yellow = "#FF9F0A", red = "#FF6B5E", blue = "#4F94F7", gray = "#A1A1A6"

    private static func fold(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private static func ym(_ d: String) -> String { String(d.prefix(7)) }
    private static func dayOf(_ d: String) -> Int { Int(d.dropFirst(8).prefix(2)) ?? 1 }
    private static func mv(_ m: String, _ n: Int) -> String {
        let y = Int(m.prefix(4)) ?? 2000, mo = Int(m.dropFirst(5).prefix(2)) ?? 1
        let t = y * 12 + (mo - 1) + n
        return String(format: "%04d-%02d", t / 12, t % 12 + 1)
    }
    private static func lbl(_ m: String) -> String {
        let mo = Int(m.dropFirst(5).prefix(2)) ?? 1
        return Tr.monthAbbr(Spanish.monthsShort[max(0, min(11, mo - 1))]).capitalized + " " + m.prefix(4)
    }
    private static func rng(_ a: String, _ b: String) -> String { a == b ? lbl(a) : lbl(a) + " – " + lbl(b) }

    static func build(sub o: JSONValue, engine e: Engine, fmt f: Fmt) -> SubHistorySummary? {
        let subId = Engine.identifier(o["id"])
        let name = Engine.text(o["name"])
        let nName = fold(name)
        let brand = Brands.sub(named: name)?.id
        let dueDay = Int(Engine.number(o["day"])) > 0 ? Int(Engine.number(o["day"])) : 1
        let all = e.allTransactions
        let rest = e.allAccounts + e.allCards

        let L = all.filter { t in
            guard Engine.number(t["amount"]) < 0, !Engine.flag(t["job"]) else { return false }
            let cat = Engine.text(t["category"])
            if cat == "Pago de crédito" || cat == "Transferencia" { return false }
            if Engine.flag(t["sub"]) && Engine.identifier(t["sub"]) == subId { return true }
            let note = Engine.text(t["note"])
            if note.isEmpty { return false }
            if fold(note) == nName { return true }
            if let brand, Brands.sub(named: note)?.id == brand { return true }
            return false
        }
        if L.isEmpty { return nil }

        var byM: [String: JSONValue] = [:]
        for t in L {
            let m = ym(Engine.text(t["date"]))
            if let c = byM[m] {
                if abs(dayOf(Engine.text(t["date"])) - dueDay) < abs(dayOf(Engine.text(c["date"])) - dueDay) { byM[m] = t }
            } else { byM[m] = t }
        }
        let ms = byM.keys.sorted()
        var has = Set<String>(), accMax: [String: String] = [:]
        for t in all {
            let a = Engine.identifier(t["acc"]), d = Engine.text(t["date"])
            has.insert(a + "|" + ym(d))
            if accMax[a] == nil || d > accMax[a]! { accMax[a] = d }
        }
        func accName(_ id: String) -> String {
            Engine.text((rest.first { Engine.identifier($0["id"]) == id } ?? e.allAccounts.first)?["name"])
        }
        func accCur(_ id: String) -> String {
            Engine.text((rest.first { Engine.identifier($0["id"]) == id } ?? e.allAccounts.first)?["cur"])
        }
        func dlabel(_ iso: String) -> String { LocalDate(iso: iso).map { Spanish.dateShort($0) } ?? iso }

        var ev: [(d: String, c: String, t: String, s: String)] = []
        func add(_ d: String, _ c: String, _ t: String, _ s: String) { ev.append((d, c, t, s)) }

        let first = byM[ms[0]]!
        let cur = accCur(Engine.identifier(first["acc"]))
        add(Engine.text(first["date"]), green, Tr.t("Primer cobro en Plata"),
            f.exact(abs(Engine.number(first["amount"])), cur) + " · " + accName(Engine.identifier(first["acc"])))

        var prev: JSONValue?
        var breaks = 0
        var m = ms[0]
        while m <= ms[ms.count - 1] {
            defer { m = mv(m, 1) }
            guard let c = byM[m] else { continue }
            if let p = prev {
                let pAcc = Engine.identifier(p["acc"]), pDate = Engine.text(p["date"])
                var gm: [String] = []
                var x = mv(ym(pDate), 1)
                while x < m { gm.append(x); x = mv(x, 1) }
                if !gm.isEmpty {
                    let real = gm.filter { has.contains(pAcc + "|" + $0) }
                    let nod = gm.count - real.count
                    if real.isEmpty {
                        add(mv(m, -1) + "-15", gray, Tr.t("Sin datos"), Tr.t("Puede faltar un estado de cuenta") + " · " + rng(gm[0], gm[gm.count - 1]))
                    } else if real.count == 1 && nod == 0 {
                        add(gm[0] + "-15", yellow, Tr.t("Mes sin cobro"), lbl(gm[0]))
                    } else {
                        breaks += 1
                        add(gm[0] + "-15", red, Tr.t("Quiebre") + " · " + Spanish.plural(real.count, "mes", "meses") + " " + Tr.t("sin cobro"),
                            rng(gm[0], gm[gm.count - 1]) + (nod > 0 ? " · " + Tr.t("Puede faltar un estado de cuenta") : ""))
                    }
                }
                let a0 = abs(Engine.number(p["amount"])), a1 = abs(Engine.number(c["amount"]))
                if abs(a1 - a0) > max(0.5, a0 * 0.05) {
                    add(Engine.text(c["date"]), blue, Tr.t(a1 > a0 ? "Subió de" : "Bajó de") + " " + f.exact(a0, cur) + " → " + f.exact(a1, cur), dlabel(Engine.text(c["date"])))
                }
                if Engine.identifier(c["acc"]) != pAcc {
                    add(Engine.text(c["date"]), blue, Tr.t("Cambió de cuenta"), accName(pAcc) + " → " + accName(Engine.identifier(c["acc"])))
                }
            }
            prev = c
        }
        // Cobros fuera de fecha: solo se marca el primero de cada racha, como en la web.
        var lateOn = false
        for mm in ms {
            guard let c = byM[mm] else { continue }
            let d = dayOf(Engine.text(c["date"]))
            let dd = abs(d - dueDay)
            let late = min(dd, 31 - dd) > 5
            if late && !lateOn {
                add(Engine.text(c["date"]), yellow, Tr.t("Cobro fuera de fecha"), Tr.f("Cobró el día {0} · esperado el {1}", String(d), String(dueDay)))
            }
            lateOn = late
        }
        let last = byM[ms[ms.count - 1]]!
        let lastDate = Engine.text(last["date"])
        let mx = accMax[Engine.identifier(last["acc"])] ?? lastDate
        if let a = LocalDate(iso: mx), let b = LocalDate(iso: lastDate), a.days - b.days > 50 {
            add(lastDate, red, Tr.t("Último cobro"), Tr.t("¿Se canceló?") + " · " + Tr.f("Sin cobros desde {0}", lbl(mv(ym(lastDate), 1))))
        }
        let sorted = ev.enumerated().sorted { a, b in a.element.d != b.element.d ? a.element.d > b.element.d : a.offset < b.offset }.map(\.element)
        return SubHistorySummary(
            since: lbl(ms[0]), charges: L.count, breaks: breaks,
            events: sorted.prefix(10).map { SubHistoryEvent(date: $0.d, color: $0.c, title: $0.t, detail: $0.s) })
    }
}
