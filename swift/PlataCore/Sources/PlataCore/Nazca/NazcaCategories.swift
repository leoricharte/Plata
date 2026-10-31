import Foundation

extension Nazca {
    /// Un movimiento ya registrado (para aprender categorías y detectar repetidos).
    public struct Known: Sendable {
        public var acc: String
        public var date: String
        public var amount: Double
        public var note: String
        public var category: String
        public var imp: String
        public init(acc: String = "", date: String = "", amount: Double = 0, note: String = "", category: String = "", imp: String = "") {
            self.acc = acc; self.date = date; self.amount = amount; self.note = note; self.category = category; self.imp = imp
        }
    }

    public enum Duplicate: String, Sendable { case none = "", exact, near }

    public struct DupMark: Equatable, Sendable {
        public var fp: String
        public var dup: Duplicate
    }

    // MARK: Categoría sugerida: primero lo que ya hiciste antes con el mismo comercio, después palabras clave

    static let numRuns = Rx(#"[0-9]+"#)

    /// Las primeras tres palabras «útiles» de una descripción (sin números ni palabras vacías como «compra», «visa»…).
    public static func merchant(_ desc: String) -> String {
        var s = numRuns.replace(norm(desc), " ")
        s = s.replacingOccurrences(of: "/", with: " ")
        s = stopRx.replace(s, " ")
        s = wsRuns.replace(s, " ").jsTrimmed
        return s.split(separator: " ", omittingEmptySubsequences: false).prefix(3).joined(separator: " ")
    }

    public typealias Categorizer = @Sendable (_ desc: String, _ amount: Double) -> String

    public static func categorizer(_ names: [String], history: [Known] = []) -> Categorizer {
        var byNorm: [String: String] = [:]
        for n in names { byNorm[norm(n)] = n }
        var learned: [String: String] = [:]
        for t in history where t.amount < 0 && !t.note.isEmpty && names.contains(t.category) {
            let k = merchant(t.note)
            if !k.isEmpty { learned[k] = t.category }
        }
        let byNormF = byNorm, learnedF = learned
        let other = names.contains("Otros") ? "Otros" : (names.last ?? "Otros")
        let normed = names.map { (name: $0, cn: norm($0)) }
        return { desc, amount in
            if amount > 0 { return "Ingreso" }
            let k = merchant(desc)
            if !k.isEmpty, let l = learnedF[k] { return l }
            let n = norm(desc)
            for x in normed where x.cn.count >= 4 && x.cn != "otros" && (" " + n + " ").contains(" " + x.cn + " ") { return x.name }
            for (_, cats, rx) in catalog where rx.test(n) {
                for c in cats { if let hit = byNormF[norm(c)] { return hit } }
            }
            return other
        }
    }

    // MARK: Repetidos: huella exacta (si ya importaste este archivo) o mismo monto y fecha cercana (si lo anotaste a mano)

    static func fnv(_ s: String) -> String {
        var h: UInt32 = 2166136261
        for u in s.utf16 { h ^= UInt32(u); h = h &* 16777619 }
        return String(h, radix: 36)
    }

    public static func fingerprints(_ items: [Item]) -> [String] {
        var seen: [String: Int] = [:]
        return items.map { it in
            let base = it.date + "|" + String(format: "%.2f", it.amount) + "|" + norm(it.desc) + ((it.ref ?? "").isEmpty ? "" : "|" + it.ref!)
            seen[base, default: 0] += 1
            return fnv(base + "|" + String(seen[base]!))
        }
    }

    /// Días desde 1970 de una fecha `AAAA-MM-DD` (para comparar cercanía).
    static func dayNumber(_ s: String) -> Double {
        let y = Int(s.prefix(4)) ?? 1970, m = Int(s.dropFirst(5).prefix(2)) ?? 1, d = Int(s.dropFirst(8).prefix(2)) ?? 1
        // Algoritmo de días desde la época (civil_from_days, a la inversa)
        let yy = m <= 2 ? y - 1 : y
        let era = (yy >= 0 ? yy : yy - 399) / 400
        let yoe = yy - era * 400
        let doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return Double(era * 146097 + doe - 719468)
    }

    /// `includeImported`: para capturas, que no traen huella de importación; también se comparan con lo ya importado (mismo monto, mismo día o un día de diferencia, y nombre parecido o mismo día).
    public static func markDuplicates(_ items: [Item], existing: [Known], acc: String, includeImported: Bool = false) -> [DupMark] {
        let prints = fingerprints(items)
        let mine = existing.filter { $0.acc == acc }
        var used = Set<Int>()
        let byPrint = Set(mine.compactMap { $0.imp.isEmpty ? nil : $0.imp })
        return items.enumerated().map { i, it in
            if byPrint.contains(prints[i]) { return DupMark(fp: prints[i], dup: .exact) }
            var hit = -1
            for (k, t) in mine.enumerated() {
                if used.contains(k) || !t.imp.isEmpty { continue }
                if abs(t.amount - it.amount) < 0.005 && abs(dayNumber(t.date) - dayNumber(it.date)) <= 2 { hit = k; break }
            }
            if hit < 0 && includeImported {
                let words = Set(merchant(it.desc).split(separator: " ").map(String.init))
                for (k, t) in mine.enumerated() where !used.contains(k) && !t.imp.isEmpty {
                    guard abs(t.amount - it.amount) < 0.005 else { continue }
                    let days = abs(dayNumber(t.date) - dayNumber(it.date))
                    let same = !words.isDisjoint(with: Set(merchant(t.note).split(separator: " ").map(String.init)))
                    if days == 0 || (days <= 1 && same) { hit = k; break }
                }
            }
            if hit >= 0 { used.insert(hit); return DupMark(fp: prints[i], dup: .near) }
            return DupMark(fp: prints[i], dup: .none)
        }
    }
}
