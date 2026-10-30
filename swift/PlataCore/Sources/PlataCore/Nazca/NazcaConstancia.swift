import Foundation

/// Nazca · Constancias de Yape y Plin (texto) — port de `core/nazca/constancia.js`.
/// Lee el TEXTO de una constancia (pegado, o reconocido de una captura con Vision) y arma un movimiento para revisar. Sin red.
/// Las reglas (expresiones regulares y meses) salen de `NazcaConstanciaTables.swift`, generado por `tools/gen-nazca-constancia.mjs` desde el mismo JS de la web;
/// aquí solo está el procedimiento, que se prueba contra lo que lee la web (`nazca_constancia.json`).
/// `flags`: `date` (sin fecha: se usó hoy) · `direction` (no dice si pagaste o te pagaron) · `who` (sin nombre) · `amount` (varios montos posibles).
/// `auto`: reconoce Yape/Plin, trae número de operación y no hay banderas → es seguro guardarla sin preguntar.
public enum NazcaConstancia {
    /// Largo máximo del texto que se lee (el mismo tope de la web).
    public static var maxLength: Int { maxChars }

    public struct Result: Sendable {
        /// Un movimiento (`items[0]`), con la misma forma que los estados de cuenta, listo para el flujo de revisión.
        public var statement: Nazca.StatementResult
        public var brand: String
        public var op: String
        public var time: String
        public var flags: [String]
        public var auto: Bool
    }

    struct Parsed {
        var amount: Double, cur: String, amb: Bool
        var date: String, time: String, hadDate: Bool
        var sign: Double
        var flags: [String]
        var brand: String, op: String, who: String, msg: String, via: String
    }

    // MARK: texto

    static let wsRuns = Rx(#"\s+"#)

    static func strip(_ t: String) -> String {
        var out = String.UnicodeScalarView()
        for u in t.lowercased().decomposedStringWithCanonicalMapping.unicodeScalars where !(0x300...0x36F).contains(u.value) { out.append(u) }
        return String(out)
    }

    static func norm(_ t: String) -> String { wsRuns.replace(strip(t), " ").jsTrimmed }

    static func pad(_ n: Int) -> String { String(format: "%02d", n) }

    // MARK: fecha y hora

    static func daysIn(_ y: Int, _ m: Int) -> Int {
        if m == 2 { return (y % 4 == 0 && (y % 100 != 0 || y % 400 == 0)) ? 29 : 28 }
        return [4, 6, 9, 11].contains(m) ? 30 : 31
    }

    static func okDate(_ y: Int, _ m: Int, _ d: Int) -> Bool { y >= 2000 && y <= 2100 && m >= 1 && m <= 12 && d >= 1 && d <= daysIn(y, m) }

    /// Fecha de una línea ya normalizada: «2026-10-29», «29 oct. 2026», «29 de octubre de 2026», «29/10/2026» (día primero).
    static func dateIn(_ n: String) -> String {
        if let m = dateIso.groups(n), okDate(Int(m[1])!, Int(m[2])!, Int(m[3])!) { return m[1] + "-" + m[2] + "-" + m[3] }
        for m in dateWords.all(n) {
            if let mo = months[String(m[2].prefix(3))], okDate(Int(m[3])!, mo, Int(m[1])!) { return m[3] + "-" + pad(mo) + "-" + pad(Int(m[1])!) }
        }
        if let m = dateNum.groups(n) {
            let y = m[3].count == 2 ? 2000 + Int(m[3])! : Int(m[3])!
            if okDate(y, Int(m[2])!, Int(m[1])!) { return String(y) + "-" + pad(Int(m[2])!) + "-" + pad(Int(m[1])!) }
        }
        return ""
    }

    /// «HH:MM» de 24 h, o vacío.
    static func timeIn(_ n: String) -> String {
        guard let m = timeRe.groups(n) else { return "" }
        var h = Int(m[1])!
        let mi = Int(m[2])!
        if m[3] == "p" && h < 12 { h += 12 }
        if m[3] == "a" && h == 12 { h = 0 }
        return h < 24 && mi < 60 ? pad(h) + ":" + pad(mi) : ""
    }

    // MARK: monto

    static func parseAmt(_ raw: String) -> Double? {
        let t = Array(raw.replacingOccurrences(of: " ", with: ""))
        let sep = max(t.lastIndex(of: ",") ?? -1, t.lastIndex(of: ".") ?? -1)
        func digits(_ a: ArraySlice<Character>) -> String { String(a.filter { $0 != "." && $0 != "," }) }
        let u: String
        if sep < 0 { u = String(t) }
        else if t.count - sep - 1 == 3 { u = digits(t[...]) }
        else { u = digits(t[..<sep]) + "." + String(t[(sep + 1)...]) }
        guard let d = Double(u) else { return nil }
        let v = Nazca.jsRound(d * 100) / 100
        return v > 0 && v < 1e7 ? v : nil
    }

    static let usdRx = Rx(#"^(US|USD|\$)"#, ci: true), sRx = Rx(#"^S"#, ci: true)

    static func amountOf(_ lines: [String], _ ns: [String]) -> (v: Double, cur: String, amb: Bool, i: Int)? {
        struct Cand { var v: Double; var cur: String; var sc: Int; var i: Int }
        var c: [Cand] = []
        for (i, ln) in lines.enumerated() {
            for m in amt.all(ln) {
                guard let v = parseAmt(m[3]) else { continue }
                let sym = m[1]
                let usd = !sym.isEmpty && usdRx.test(wsRuns.replace(sym, "")) && !sRx.test(sym)
                var sc = 0
                if key.test(ns[i]) { sc += 3 }
                if i > 0 && key.test(ns[i - 1]) { sc += 2 }
                var rest = ln
                if let r = rest.range(of: m[0]) { rest.removeSubrange(r) }
                if bad.test(ns[i]) || (i > 0 && bad.test(ns[i - 1]) && rest.jsTrimmed.isEmpty) { sc -= 5 }
                c.append(Cand(v: v, cur: usd ? "USD" : "PEN", sc: sc, i: i))
            }
        }
        guard var best = c.first else { return nil }
        for x in c where x.sc > best.sc { best = x }
        let amb = c.contains { $0.sc == best.sc && $0.v != best.v }
        return (best.v, best.cur, amb, best.i)
    }

    static let headBad = Rx(#"yape|plin|operacion|transaccion|seguridad|gracias|compartir"#), digitRx = Rx(#"\d"#), alpha3 = Rx(#"[a-z]{3}"#, ci: true)
    /// Pagos de servicios y comercios: sin «Destino», el nombre es la línea que sigue al monto.
    static func headWho(_ lines: [String], _ ns: [String], _ i: Int) -> String {
        let j = i + 1
        if j >= lines.count { return "" }
        let l = wsRuns.replace(lines[j], " ").jsTrimmed
        if l.jsLength < 3 || l.jsLength > 60 || digitRx.test(l) || !alpha3.test(l) || labelish.test(ns[j]) || headBad.test(ns[j]) { return "" }
        return cleanWho(l)
    }

    // MARK: nombre y mensaje

    static let junk = Rx(#"^[\d\s*xX•·-]+$"#), edges = Rx(#"^[\s:\-–]+|[\s:\-–,;]+$"#), titleRx = Rx(#"(^|[ ])([a-zñáéíóúü])"#), upperRx = Rx(#"[A-Z]"#)
    static let msgEmpty = Rx(#"^(-+|sin mensaje|ninguno|n\/a)$"#, ci: true)

    static func titleCase(_ v: String) -> String { titleRx.replace(v.lowercased()) { $0[1] + $0[2].uppercased() } }

    static func cleanWho(_ v: String) -> String {
        var s = edges.replace(wsRuns.replace(v, " "), "")
        if s.isEmpty || junk.test(s) { return "" }
        if s == s.uppercased() && upperRx.test(s) { s = titleCase(s) }
        return s.jsLength > 60 ? s.jsSlice(0, 60).jsTrimmed : s
    }

    /// Lo que sigue a una etiqueta: en la misma línea o, si está vacía, en la línea de abajo (si esa no es otra etiqueta).
    static func after(_ lines: [String], _ ns: [String], _ i: Int, _ rem: String) -> String {
        if !rem.isEmpty { return ns[i].jsLength == lines[i].jsLength ? lines[i].jsSlice(lines[i].jsLength - rem.jsLength) : rem }
        let j = i + 1
        if j < lines.count && !labelish.test(ns[j]) { return lines[j] }
        return ""
    }

    static func whoOf(_ lines: [String], _ ns: [String], _ sign: Int) -> String {
        let order = sign > 0 ? [labelFrom, labelTo] : [labelTo, labelFrom]
        for L in order {
            for i in lines.indices {
                if let m = L.groups(ns[i]) { let v = cleanWho(after(lines, ns, i, m[2])); if !v.isEmpty && v.lowercased() != "yape" && v.lowercased() != "plin" { return v } }
            }
        }
        for i in lines.indices {
            if sign <= 0, let m = inlineNeg.groups(ns[i]) {
                let v = cleanWho(ns[i].jsLength == lines[i].jsLength ? lines[i].jsSlice(lines[i].jsLength - m[1].jsLength) : m[1])
                if !v.isEmpty { return v }
            }
            if sign >= 0, let m = inlinePos.groups(ns[i]) {
                let v = cleanWho(ns[i].jsLength == lines[i].jsLength ? lines[i].jsSlice(0, m[1].jsLength) : m[1])
                if !v.isEmpty { return v }
            }
        }
        return ""
    }

    static let msgBad = Rx(#"yape|plin|compartir|datos|transaccion|seguridad|operacion|n°|nº"#), alphaMsg = Rx(#"[a-z]{3}"#, ci: true), adsRx = Rx(#"^mas en (yape|plin)\b"#)
    static func msgOf(_ lines: [String], _ ns: [String], _ di: Int) -> String {
        for i in lines.indices {
            guard let m = labelMsg.groups(ns[i]) else { continue }
            let v = wsRuns.replace(after(lines, ns, i, m[2]), " ").jsTrimmed
            if !v.isEmpty && !msgEmpty.test(v) { return v.jsSlice(0, 60) }
        }
        // Yape pone el mensaje sin etiqueta, en una burbuja justo debajo de la fecha.
        let j = di + 1
        if di >= 0 && j < lines.count && lines[j].jsLength >= 3 && lines[j].jsLength <= 60 && alphaMsg.test(lines[j]) && !labelish.test(ns[j]) && !msgBad.test(ns[j]) && dateIn(ns[j]).isEmpty {
            return wsRuns.replace(lines[j], " ").jsTrimmed
        }
        return ""
    }

    // MARK: marca, banco y operación

    static let viaInter = Rx(#"\binterbank\b"#), viaBbva = Rx(#"\bbbva\b"#), viaBcp = Rx(#"\bbcp\b|banco de credito"#), plinWords = Rx(#"plineaste|plin enviado|plineo|te plinearon|volver a plin"#), yapeOnly = Rx(#"yapeaste|te yapeo|te yapearon|yapeo realizado|codigo de seguridad"#), originRx = Rx(#"cuenta de (origen|cargo)"#), yapeOnly2 = Rx(#"yapeaste|te yapeo|te yapearon"#)

    static let shopRx = Rx(#"ventana del comercio|finalizar tu compra"#)
    static func brandOf(_ n: String) -> String {
        let y = n.contains("yape"), p = n.contains("plin")
        if y && yapeOnly.test(n) { return "yape" }
        if !y && !p && shopRx.test(n) { return "plin" }   // pago en un comercio: el logo de Plin es una imagen y el OCR no lo lee
        if y && p { return plinWords.test(n) ? "plin" : "yape" }
        return y ? "yape" : p ? "plin" : ""
    }

    static func viaOf(_ n: String) -> String { viaInter.test(n) ? "interbank" : viaBbva.test(n) ? "bbva" : viaBcp.test(n) ? "bcp" : "" }

    static func opOf(_ n: String) -> String {
        for m in op.all(n) where m[1].unicodeScalars.contains(where: { (0x30...0x39).contains($0.value) }) { return m[1].uppercased() }
        return ""
    }

    // MARK: lectura

    static func parse(_ text: String?, today: String, forced: Int = 0) -> Parsed? {
        let raw = (text ?? "").jsSlice(0, maxChars).replacingOccurrences(of: "\r\n", with: "\n")
        var lines = Array(raw.components(separatedBy: "\n").map { wsRuns.replace($0, " ").jsTrimmed }.filter { !$0.isEmpty }.prefix(maxLines))
        if let cut = lines.firstIndex(where: { adsRx.test(norm($0)) }), cut > 0 { lines = Array(lines[0..<cut]) }   // lo de abajo son anuncios, con montos que no son del pago
        if lines.isEmpty { return nil }
        let ns = lines.map { norm($0) }, n = ns.joined(separator: "\n"), flat = ns.joined(separator: " ")
        guard let amount = amountOf(lines, ns) else { return nil }
        var date = "", time = "", di = -1
        var i = 0
        while i < ns.count && date.isEmpty {
            let d = dateIn(ns[i])
            if !d.isEmpty {
                date = d; di = i
                let t0 = timeIn(ns[i])
                time = !t0.isEmpty ? t0 : (i + 1 < ns.count ? timeIn(ns[i + 1]) : "")
            }
            i += 1
        }
        let isNeg = neg.test(n), isPos = pos.test(n)
        var sign = forced != 0 ? (forced > 0 ? 1 : -1) : (isPos && !isNeg ? 1 : isNeg && !isPos ? -1 : 0)
        if sign == 0 {
            let hasTo = ns.contains { labelTo.test($0) }, hasFrom = ns.contains { labelFrom.test($0) }
            sign = hasFrom && !hasTo ? 1 : hasTo ? -1 : 0
        }
        var flags: [String] = []
        if sign == 0 { flags.append("direction") }
        if date.isEmpty { flags.append("date") }
        if amount.amb { flags.append("amount") }
        var brand = brandOf(n)
        if originRx.test(n) && !viaOf(n).isEmpty && !yapeOnly2.test(n) { brand = "plin" }   // constancia del banco (BBVA…): el dinero salió de esa cuenta
        let op = opOf(flat)
        // Si la persona dice que recibió pero la captura es de quien envió (o al revés), el nombre que sale es el suyo, no el de la otra parte.
        let other = forced != 0 && ((forced > 0 && isNeg && !isPos) || (forced < 0 && isPos && !isNeg))
        let who: String = { if other { return "" }; let w = whoOf(lines, ns, sign); return w.isEmpty && sign <= 0 ? headWho(lines, ns, amount.i) : w }()
        if who.isEmpty && !other { flags.append("who") }
        return Parsed(amount: amount.v, cur: amount.cur, amb: amount.amb, date: date.isEmpty ? today : date, time: time, hadDate: !date.isEmpty,
                      sign: sign == 0 ? -1 : Double(sign), flags: flags, brand: brand, op: op, who: who, msg: msgOf(lines, ns, di),
                      via: brand == "plin" ? viaOf(n) : "")
    }

    /// 0 = no es una constancia · 2 = Yape o Plin con monto · 1 = parece constancia de otro banco (monto + fecha + número de operación).
    public static func detect(_ text: String?) -> Int {
        guard let p = parse(text, today: "") else { return 0 }
        return !p.brand.isEmpty ? 2 : (!p.op.isEmpty && p.hadDate ? 1 : 0)
    }

    /// `nil` si no hay ningún monto. `today` (AAAA-MM-DD) es la fecha que se usa si el texto no trae una.
    /// `sign`: 1 = me llegó dinero, -1 = envié, 0 = que lo decida el texto de la constancia.
    public static func read(_ text: String?, today: String = "", sign: Int = 0) -> Result? {
        guard let p = parse(text, today: today, forced: sign) else { return nil }
        let name = p.brand == "yape" ? "Yape" : p.brand == "plin" ? "Plin" : ""
        let base = !p.who.isEmpty ? p.who : (!name.isEmpty ? (p.sign < 0 ? name : name + " (recibido)") : "Constancia")
        let desc = (base + (p.msg.isEmpty ? "" : " · " + p.msg)).jsSlice(0, 90)
        let ref = !p.op.isEmpty ? p.op : (!p.time.isEmpty ? "t" + p.time.replacingOccurrences(of: ":", with: "") : "")
        let item = Nazca.Item(line: 1, date: p.date, desc: desc, amount: p.sign * p.amount, cur: p.cur, ref: ref.isEmpty ? nil : ref)
        let bank = p.brand == "yape" ? "yape" : p.via
        var st = Nazca.StatementResult(bank: bank.isEmpty ? nil : bank, kind: "corriente", label: name.isEmpty ? "Constancia" : name + " · Constancia", cur: p.cur, items: [item])
        st.name = name
        st.period = p.date.isEmpty ? nil : .init(from: p.date, to: p.date)
        return Result(statement: st, brand: p.brand, op: p.op, time: p.time, flags: p.flags, auto: !p.brand.isEmpty && !p.op.isEmpty && p.flags.isEmpty)
    }
}
