import Foundation

/// Respuestas del recorrido de bienvenida (`ui.w` de la web).
public struct WelcomeAnswers: Equatable, Sendable {
    public var level = "standard"            // simple · standard · extended
    public var first = "", last = "", nick = "", gender = "n"
    public var ins = true, score = true
    public var cur: [String] = ["USD"]
    public var fx = 0.0
    public var custom = ""
    public var accName = "Cuenta principal", accType = "checking", accCur = "", bal = ""
    public var incKind = "i", incName = "Sueldo", incAmt = "", incRep = "m", incQ1 = "15", incQ2 = "30", incDate = ""
    public var jMode = "", jName = "Trabajo", jRate = "", jHours = "40", jTax = "15", jFreq = "", jQ1 = "15", jQ2 = "30", jDate = ""
    public var fxName = "Renta", fxAmt = "", fxRep = "m", fxQ1 = "1", fxQ2 = "15", fxDate = ""
    public var bud: [String: String] = [:]
    public var subName = "", subAmt = "", subDay = "1"
    public var dbKind = "card", dbName = "", dbBal = "", dbLim = "", dbApr = "20", dbPay = "", dbDay = "1"
    public var gName = "", gGoal = "", gMon = ""
    /// `photo`, `photoSrc` y `photoCrop` ya listos para guardar en los ajustes.
    public var photo: [String: JSONValue] = [:]

    public init() {}

    /// `wClear`: «Omitir» deja en blanco lo del paso.
    public mutating func clear(step: String) {
        switch step {
        case "name": first = ""; last = ""; nick = ""
        case "inc": incAmt = ""; jRate = ""
        case "fixed": fxAmt = ""
        case "budget": bud = [:]
        case "subs": subAmt = ""
        case "debt": dbName = ""; dbBal = ""
        case "goal": gName = ""; gGoal = ""
        default: break
        }
    }
}

public enum Onboarding {
    /// Pasos por nivel (`W_STEPS`).
    public static func steps(level: String, importer: Bool = false) -> [String] {
        let all: [String: [String]] = [
            "simple": ["name", "cur", "acc", "imp", "look"],
            "standard": ["name", "ins", "cur", "acc", "imp", "inc", "budget", "look"],
            "extended": ["name", "ins", "cur", "acc", "imp", "inc", "fixed", "budget", "subs", "debt", "goal", "look"],
        ]
        return (all[level] ?? []).filter { ($0 != "imp") || importer }
    }

    /// Los pasos con «Omitir».
    public static let optionalSteps: Set<String> = ["name", "imp", "inc", "fixed", "budget", "subs", "debt", "goal"]

    /// Monedas a partir de la zona horaria (`curByTZ`).
    public static func currency(forTimeZone z: String) -> String? {
        if let c = tzCurrency[z], Currencies.table[c] != nil { return c }
        if z.hasPrefix("America/Argentina/") { return "ARS" }
        return nil
    }

    /// `guessCur`: la zona horaria manda; el país del idioma es respaldo.
    public static func guessCurrencies(timeZone: String, region: String) -> [String] {
        let m = ["US": "USD", "GB": "GBP", "JP": "JPY", "CN": "CNY", "AU": "AUD", "CA": "CAD", "CH": "CHF", "BA": "BAM", "HR": "EUR", "SG": "SGD",
                 "PE": "PEN", "DE": "EUR", "FR": "EUR", "IT": "EUR", "ES": "EUR", "NL": "EUR", "PT": "EUR", "IE": "EUR", "AT": "EUR", "BE": "EUR"]
        let c = currency(forTimeZone: timeZone) ?? m[region.uppercased()] ?? "USD"
        return c == "PEN" ? ["PEN", "USD"] : [c]
    }

    /// `fxDefault`: `Number((rate_s / rate_p).toPrecision(4))`.
    public static func fxDefault(_ p: String, _ s: String) -> Double {
        guard let rp = Currencies.table[p]?.rate, let rs = Currencies.table[s]?.rate, rp > 0 else { return 1 }
        return Double(String(format: "%.4g", rs / rp)) ?? 1
    }

    /// Perfil de «Inicio rápido»: solo la moneda de la zona y el tutorial activado.
    public static func quick(currencies: [String]) -> JSONValue {
        var p = Profile.empty.raw
        var s = p["settings"] ?? .object([:])
        s["currency"] = .string(currencies.first ?? "USD")
        s["currency2"] = .string(currencies.count > 1 ? currencies[1] : "")
        if currencies.count > 1 { s["fx"] = .number(fxDefault(currencies[0], currencies[1])) }
        s["tour"] = .object(["on": .bool(true), "seen": .object([:])])
        p["settings"] = s
        var accs = p["accounts"]?.arrayValue ?? []
        if !accs.isEmpty { accs[0]["cur"] = .string(currencies.first ?? "USD") }
        p["accounts"] = .array(accs)
        return p
    }

    public static func jobModes(_ cur: [String]) -> [(String, String)] {
        var m: [(String, String)] = []
        if cur.contains("USD") { m.append(("h", "EE.UU.")) }
        if cur.contains("PEN") { m.append(("s", "Perú")) }
        if m.count > 1, cur.first == "PEN" { m.reverse() }
        return m.isEmpty ? [("h", "EE.UU."), ("s", "Perú")] : m
    }

    public static func jobMode(_ w: WelcomeAnswers) -> String {
        let m = jobModes(w.cur)
        return m.contains { $0.0 == w.jMode } ? w.jMode : m[0].0
    }

    private static func n(_ v: String) -> Double { Double(v.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)) ?? 0 }
    private static func day(_ v: String, _ d: Int) -> Int {
        let x = Int(n(v).rounded()); return (x >= 1 && x <= 31) ? x : d
    }
    private static func trim(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// `wFinish`: arma el perfil nuevo con lo que se respondió.
    public static func build(_ w: WelcomeAnswers, today: LocalDate, newId: () -> String) -> JSONValue {
        var p = Profile.empty.raw
        let cur = w.cur.isEmpty ? ["USD"] : w.cur
        var s = p["settings"] ?? .object([:])
        for (k, v) in w.photo { s[k] = v }
        s["first"] = .string(trim(w.first)); s["last"] = .string(trim(w.last)); s["nick"] = .string(trim(w.nick))
        s["gender"] = .string(w.gender.isEmpty ? "n" : w.gender)
        s["insights"] = .bool(w.ins); s["score"] = .bool(w.ins && w.score)
        s["currency"] = .string(cur[0]); s["currency2"] = .string(cur.count > 1 ? cur[1] : "")
        s["customCur"] = .string(w.custom)
        s["fx"] = .number(cur.count > 1 ? (w.fx > 0 ? w.fx : fxDefault(cur[0], cur[1])) : (s["fx"]?.doubleValue ?? 3.5))
        s["tour"] = .object(["on": .bool(true), "seen": .object([:])])
        p["settings"] = s

        let accCur = cur.contains(w.accCur) ? w.accCur : cur[0]
        var acc: JSONValue = (p["accounts"]?.arrayValue ?? []).first ?? .object([:])
        acc["name"] = .string(trim(w.accName).isEmpty ? "Cuenta principal" : trim(w.accName))
        acc["type"] = .string(w.accType); acc["cur"] = .string(accCur)
        acc["balance"] = .number(Engine.round2(n(w.bal)))
        p["accounts"] = .array([acc])
        let accId = acc["id"] ?? .string("bank")
        let todayIso = today.iso

        func qDate(_ a: String, _ b: String, _ da: Int, _ db: Int) -> (String, String) {
            let r = Engine.qMake(.number(Double(day(a, da))), .number(Double(day(b, db))))
            return (r, Engine.qNext(today, r, inclusive: true).iso)
        }

        let amt = n(w.incAmt)
        if w.incKind == "j" {
            let md = jobMode(w), rate = n(w.jRate)
            let hrs = md == "s" ? 0 : max(0, min(168, n(w.jHours)))
            if rate > 0 && (md == "s" || hrs > 0) {
                let fq = ["w", "b", "q", "m"].contains(w.jFreq) ? w.jFreq : (md == "s" ? "m" : "b")
                var job: [String: JSONValue] = [
                    "id": .string(newId()), "mode": .string(md), "name": .string(trim(w.jName).isEmpty ? "Trabajo" : trim(w.jName)),
                    "rate": .number(rate), "hours": .number(hrs), "tax": .number(md == "s" ? 0 : max(0, min(90, n(w.jTax)))),
                    "freq": .string(fq), "acc": accId, "start": .string(w.jDate.isEmpty ? todayIso : w.jDate), "until": .string(""), "sim": .number(0)]
                if fq == "q" {
                    let jq = Engine.qDays("q\(day(w.jQ1, 15)),\(day(w.jQ2, 30))")
                    job["q1"] = .number(Double(jq.0)); job["q2"] = .number(Double(jq.1))
                    job["start"] = .string(Engine.qNext(today, "q\(jq.0),\(jq.1)", inclusive: true).iso)
                }
                p["jobs"] = .array([.object(job)])
            }
        } else if amt > 0 {
            var item: [String: JSONValue] = ["id": .string(newId()), "name": .string(trim(w.incName).isEmpty ? "Sueldo" : trim(w.incName)),
                                              "amount": .number(amt), "acc": accId]
            if w.incRep == "q" {
                let q = qDate(w.incQ1, w.incQ2, 15, 30)
                item["date"] = .string(q.1); item["repeat"] = .string(q.0)
            } else {
                item["date"] = .string(w.incDate.isEmpty ? todayIso : w.incDate)
                item["repeat"] = w.incRep == "m" ? .string("m") : .number(Double(w.incRep) ?? 0)
            }
            p["expected_income"] = .array([.object(item)])
        }

        if w.level == "extended" {
            let fx = n(w.fxAmt), nm = trim(w.fxName)
            if fx > 0 {
                var item: [String: JSONValue] = ["id": .string(newId()), "name": .string(nm.isEmpty ? "Gasto fijo" : nm), "amount": .number(fx), "acc": accId,
                                                  "until": .string(""),
                                                  "cat": .string(nm.range(of: "renta|alquiler", options: [.regularExpression, .caseInsensitive]) != nil ? "Alquiler" : "Otros")]
                if w.fxRep == "q" {
                    let q = qDate(w.fxQ1, w.fxQ2, 1, 15)
                    item["date"] = .string(q.1); item["repeat"] = .string(q.0)
                } else {
                    item["date"] = .string(w.fxDate.isEmpty ? todayIso : w.fxDate)
                    item["repeat"] = w.fxRep == "m" ? .string("m") : .number(Double(w.fxRep) ?? 0)
                }
                p["expected_expense"] = .array([.object(item)])
            }
            let sb = n(w.subAmt)
            if sb > 0 {
                p["subs"] = .array([.object(["id": .string(newId()), "since": .string(todayIso),
                                             "name": .string(trim(w.subName).isEmpty ? "Servicio o suscripción" : trim(w.subName)),
                                             "amount": .number(sb), "cur": .string(accCur), "day": .number(Double(max(1, min(31, Int(n(w.subDay).rounded()) == 0 ? 1 : Int(n(w.subDay).rounded())))))])])
            }
            let db = n(w.dbBal), dn = trim(w.dbName)
            if db > 0 || !dn.isEmpty {
                let loan = w.dbKind == "loan"
                p["cards"] = .array([.object([
                    "id": .string(newId()), "kind": .string(loan ? "loan" : "card"), "name": .string(dn.isEmpty ? (loan ? "Préstamo" : "Tarjeta") : dn),
                    "cur": .string(accCur), "limit": .number(loan ? 0 : n(w.dbLim)), "balance": .number(db),
                    "apr": .number(w.dbApr.isEmpty ? 20 : n(w.dbApr)), "payment": .number(n(w.dbPay)),
                    "due_day": .number(Double(max(1, min(31, Int(n(w.dbDay).rounded()) == 0 ? 1 : Int(n(w.dbDay).rounded()))))),
                    "color": .string(""), "icon": .string("")])])
            }
            let gl = n(w.gGoal), gn = trim(w.gName)
            if !gn.isEmpty && gl > 0 {
                p["savings"] = .array([.object(["id": .string(newId()), "name": .string(gn), "cur": .string(accCur), "balance": .number(0),
                                                "goal": .number(gl), "monthly": .number(n(w.gMon)), "color": .string("#B98AE6"), "icon": .string("")])])
            }
        }
        if w.level != "simple" {
            var bd: [String: JSONValue] = [:]
            for (k, v) in w.bud where n(v) > 0 { bd[k] = .number(n(v)) }
            if !bd.isEmpty { p["budget"] = .object(bd) }
        }
        ProfileEditor.syncJobs(&p, newId: "")
        return p
    }

    private static let tzCurrency: [String: String] = [
        "America/Lima": "PEN",
        "America/Mexico_City": "MXN",
        "America/Cancun": "MXN",
        "America/Monterrey": "MXN",
        "America/Tijuana": "MXN",
        "America/Bogota": "COP",
        "America/Santiago": "CLP",
        "America/Sao_Paulo": "BRL",
        "America/Montevideo": "UYU",
        "America/Asuncion": "PYG",
        "America/La_Paz": "BOB",
        "America/Caracas": "VES",
        "America/Costa_Rica": "CRC",
        "America/Guatemala": "GTQ",
        "America/Tegucigalpa": "HNL",
        "America/Managua": "NIO",
        "America/Santo_Domingo": "DOP",
        "America/Havana": "CUP",
        "America/Toronto": "CAD",
        "America/Vancouver": "CAD",
        "America/Edmonton": "CAD",
        "America/Winnipeg": "CAD",
        "America/Halifax": "CAD",
        "America/Montreal": "CAD",
        "America/Regina": "CAD",
        "America/St_Johns": "CAD",
        "Europe/London": "GBP",
        "Europe/Sarajevo": "BAM",
        "Asia/Tokyo": "JPY",
        "Asia/Dubai": "AED",
        "Asia/Kolkata": "INR",
        "Asia/Calcutta": "INR",
        "Asia/Shanghai": "CNY",
        "Asia/Seoul": "KRW",
        "Asia/Singapore": "SGD",
        "Asia/Hong_Kong": "HKD",
        "Asia/Bangkok": "THB",
        "Asia/Manila": "PHP",
        "Asia/Jakarta": "IDR",
        "Europe/Zurich": "CHF",
        "Europe/Warsaw": "PLN",
        "Europe/Prague": "CZK",
        "Europe/Stockholm": "SEK",
        "Europe/Oslo": "NOK",
        "Europe/Copenhagen": "DKK",
        "Europe/Istanbul": "TRY",
        "Europe/Moscow": "RUB",
        "Europe/Kiev": "UAH",
        "Europe/Kyiv": "UAH",
        "Africa/Johannesburg": "ZAR",
        "Africa/Cairo": "EGP",
        "Africa/Lagos": "NGN",
        "Africa/Nairobi": "KES",
        "Australia/Sydney": "AUD",
        "Australia/Melbourne": "AUD",
        "Australia/Perth": "AUD",
        "Pacific/Auckland": "NZD",
        "America/Argentina/Buenos_Aires": "ARS",
        "America/New_York": "USD",
        "America/Chicago": "USD",
        "America/Denver": "USD",
        "America/Los_Angeles": "USD",
        "America/Phoenix": "USD",
        "America/Anchorage": "USD",
        "America/Detroit": "USD",
        "America/Boise": "USD",
        "America/Indiana/Indianapolis": "USD",
        "America/Kentucky/Louisville": "USD",
        "America/Adak": "USD",
        "Pacific/Honolulu": "USD",
        "America/Panama": "USD",
        "America/El_Salvador": "USD",
        "America/Guayaquil": "USD",
        "America/Puerto_Rico": "USD",
        "Pacific/Guam": "USD",
        "Europe/Madrid": "EUR",
        "Europe/Paris": "EUR",
        "Europe/Berlin": "EUR",
        "Europe/Rome": "EUR",
        "Europe/Amsterdam": "EUR",
        "Europe/Brussels": "EUR",
        "Europe/Lisbon": "EUR",
        "Europe/Dublin": "EUR",
        "Europe/Vienna": "EUR",
        "Europe/Athens": "EUR",
        "Europe/Helsinki": "EUR",
        "Europe/Luxembourg": "EUR",
        "Europe/Zagreb": "EUR",
        "Europe/Tallinn": "EUR",
        "Europe/Riga": "EUR",
        "Europe/Vilnius": "EUR",
        "Europe/Bratislava": "EUR",
        "Europe/Ljubljana": "EUR",
        "Europe/Malta": "EUR",
        "Atlantic/Canary": "EUR",
        "Atlantic/Azores": "EUR",
        "Atlantic/Madeira": "EUR",
        "Africa/Ceuta": "EUR",
        "Europe/Monaco": "EUR",
        "Europe/Vatican": "EUR",
        "Europe/San_Marino": "EUR",
        "Europe/Andorra": "EUR",
        "Asia/Nicosia": "EUR",
        "Europe/Podgorica": "EUR",
        "Europe/Busingen": "EUR",
        "Australia/Brisbane": "AUD",
        "Australia/Adelaide": "AUD",
        "Australia/Darwin": "AUD",
        "Australia/Hobart": "AUD",
        "Australia/Canberra": "AUD",
        "Europe/Bucharest": "RON",
        "Europe/Budapest": "HUF",
        "Europe/Sofia": "BGN",
        "Europe/Belgrade": "RSD",
        "Atlantic/Reykjavik": "ISK",
        "Europe/Skopje": "MKD",
        "Europe/Tirane": "ALL",
        "Europe/Chisinau": "MDL",
        "Europe/Minsk": "BYN",
        "Asia/Taipei": "TWD",
        "Asia/Ho_Chi_Minh": "VND",
        "Asia/Saigon": "VND",
        "Asia/Kuala_Lumpur": "MYR",
        "Asia/Karachi": "PKR",
        "Asia/Dhaka": "BDT",
        "Asia/Riyadh": "SAR",
        "Asia/Jerusalem": "ILS",
        "Asia/Tel_Aviv": "ILS",
        "Asia/Qatar": "QAR",
        "Asia/Kuwait": "KWD",
        "Asia/Colombo": "LKR",
        "Asia/Kathmandu": "NPR",
        "Asia/Almaty": "KZT",
        "Asia/Tbilisi": "GEL",
        "Asia/Yerevan": "AMD",
        "Asia/Baku": "AZN",
        "Asia/Baghdad": "IQD",
        "Asia/Amman": "JOD",
        "Asia/Beirut": "LBP",
        "Asia/Phnom_Penh": "KHR",
        "Asia/Yangon": "MMK",
        "Asia/Tashkent": "UZS",
        "Africa/Casablanca": "MAD",
        "Africa/Accra": "GHS",
        "Africa/Tunis": "TND",
        "Africa/Algiers": "DZD",
        "Africa/Addis_Ababa": "ETB",
        "Africa/Dar_es_Salaam": "TZS",
        "Africa/Kampala": "UGX",
        "America/Jamaica": "JMD",
        "America/Port_of_Spain": "TTD",
        "America/Nassau": "BSD",
        "America/Barbados": "BBD",
        "America/Guyana": "GYD",
        "America/Paramaribo": "SRD",
        "America/Port-au-Prince": "HTG",
        "America/Belize": "BZD",
        "America/Buenos_Aires": "ARS",
        "America/Manaus": "BRL",
        "America/Fortaleza": "BRL",
        "America/Recife": "BRL",
        "America/Bahia": "BRL",
        "America/Belem": "BRL",
        "America/Cuiaba": "BRL",
        "America/Campo_Grande": "BRL",
        "America/Merida": "MXN",
        "America/Chihuahua": "MXN",
        "America/Hermosillo": "MXN",
        "America/Mazatlan": "MXN",
        "America/Matamoros": "MXN",
        "America/Bahia_Banderas": "MXN",
        "America/Ojinaga": "MXN",
        "America/Punta_Arenas": "CLP",
        "America/Whitehorse": "CAD",
        "America/Yellowknife": "CAD",
        "America/Iqaluit": "CAD",
        "America/Moncton": "CAD",
        "America/Goose_Bay": "CAD",
        "America/Glace_Bay": "CAD",
        "America/Thunder_Bay": "CAD",
        "America/Nipigon": "CAD",
        "America/Rainy_River": "CAD",
        "America/Dawson": "CAD",
        "America/Dawson_Creek": "CAD",
        "America/Fort_Nelson": "CAD",
        "America/Swift_Current": "CAD",
        "America/Cambridge_Bay": "CAD",
        "America/Inuvik": "CAD",
        "America/Rankin_Inlet": "CAD",
        "America/Resolute": "CAD",
        "America/Atikokan": "CAD",
        "America/Pangnirtung": "CAD"
    ]
}
