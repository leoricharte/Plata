import Foundation

/// Una fecha de calendario sin hora ni zona (día local). Reproduce lo que la web hace con `new Date(y, m, d)`:
/// meses y días fuera de rango se desbordan hacia el mes o año siguiente (el día 0 es el último del mes anterior).
public struct LocalDate: Comparable, Hashable, Sendable {
    /// Días desde 1970-01-01.
    public let days: Int

    public init(days: Int) { self.days = days }

    /// Equivale a `new Date(year, month0, day)` (mes desde 0).
    public init(year: Int, month0: Int, day: Int) {
        let y = year + LocalDate.floorDiv(month0, 12)
        let m0 = LocalDate.floorMod(month0, 12)
        self.days = LocalDate.daysFromCivil(y, m0 + 1, 1) + (day - 1)
    }

    /// Equivale a `pd("YYYY-MM-DD")`. Devuelve nil si el texto no tiene tres números.
    public init?(iso text: String) {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false).map { Int($0) }
        guard parts.count == 3, let y = parts[0], let m = parts[1], let d = parts[2] else { return nil }
        self.init(year: y, month0: m - 1, day: d)
    }

    public static func < (a: LocalDate, b: LocalDate) -> Bool { a.days < b.days }

    public func adding(days n: Int) -> LocalDate { LocalDate(days: days + n) }

    private var civil: (y: Int, m: Int, d: Int) { LocalDate.civilFromDays(days) }
    public var year: Int { civil.y }
    /// 1...12
    public var month: Int { civil.m }
    /// 0...11, como `getMonth()`
    public var month0: Int { civil.m - 1 }
    public var day: Int { civil.d }
    /// 0 = domingo, como `getDay()`
    public var weekday: Int { LocalDate.floorMod(days + 4, 7) }

    /// `YYYY-MM-DD`
    public var iso: String {
        let c = civil
        return String(c.y) + "-" + (c.m < 10 ? "0" : "") + String(c.m) + "-" + (c.d < 10 ? "0" : "") + String(c.d)
    }

    /// Días del mes (equivale a `new Date(y, m + 1, 0).getDate()`).
    public static func daysInMonth(year: Int, month0: Int) -> Int {
        LocalDate(year: year, month0: month0 + 1, day: 1).days - LocalDate(year: year, month0: month0, day: 1).days
    }

    static func floorDiv(_ a: Int, _ b: Int) -> Int { let q = a / b; return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q }
    static func floorMod(_ a: Int, _ b: Int) -> Int { let r = a % b; return r < 0 ? r + b : r }

    // Algoritmo de calendario civil (Howard Hinnant).
    static func daysFromCivil(_ year: Int, _ month: Int, _ day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = (month + 9) % 12
        let doy = (153 * mp + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146097 + doe - 719468
    }

    static func civilFromDays(_ days: Int) -> (y: Int, m: Int, d: Int) {
        let z = days + 719468
        let era = (z >= 0 ? z : z - 146096) / 146097
        let doe = z - era * 146097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
        let y = yoe + era * 400
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        return (m <= 2 ? y + 1 : y, m, d)
    }
}
