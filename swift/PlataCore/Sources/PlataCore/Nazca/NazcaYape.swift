import Foundation

/// Nazca · Yape (Perú) · «Reporte de movimientos» en Excel (port de `bancos/yape-movimientos.js`).
/// Hoja con los títulos «Tipo de Transacción · Origen · Destino · Monto · Mensaje · Fecha de operación». PAGASTE → negativo, TE PAGÓ → positivo.
/// El reporte no trae saldos ni totales, así que no hay comprobación «cuadra».
public enum NazcaYape {
    static let req = ["tipo de transaccion", "origen", "destino", "monto", "fecha de operacion"]

    static func norm(_ t: String?) -> String {
        var stripped = String.UnicodeScalarView()
        for u in (t ?? "").lowercased().decomposedStringWithCanonicalMapping.unicodeScalars where !(0x300...0x36F).contains(u.value) { stripped.append(u) }
        return Rx(#"\s+"#).replace(String(stripped), " ").jsTrimmed
    }

    struct Header { var row: Int; var type: Int; var from: Int; var to: Int; var amount: Int; var date: Int; var msg: Int }

    static func headerAt(_ rows: [[String]]) -> Header? {
        for i in 0..<min(rows.count, 20) {
            let r = rows[i].map { norm($0) }
            var col: [String: Int] = [:]
            for k in req { if let j = r.firstIndex(of: k) { col[k] = j } }
            if req.allSatisfy({ col[$0] != nil }) {
                return Header(row: i, type: col["tipo de transaccion"]!, from: col["origen"]!, to: col["destino"]!, amount: col["monto"]!,
                              date: col["fecha de operacion"]!, msg: r.firstIndex(of: "mensaje") ?? -1)
            }
        }
        return nil
    }

    public static func detect(_ rows: [[String]]) -> Bool { headerAt(rows) != nil }

    static let moneyKeep = Rx(#"[^\d.,-]"#), moneyOk = Rx(#"^-?\d+(\.\d+)?$"#)
    static func money(_ s: String?) -> Double? {
        let t = moneyKeep.replace(s ?? "", "")
        if t.isEmpty { return nil }
        let c = t.lastIndex(of: ","), d = t.lastIndex(of: ".")
        let u: String
        if let c, d == nil || c > d! { u = t.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".") }
        else { u = t.replacingOccurrences(of: ",", with: "") }
        // en JS `c > d` con d == -1 (sin punto) también es verdadero; con c == -1 y d == -1 es falso
        guard moneyOk.test(u), let n = Double(u) else { return nil }
        return Nazca.jsRound(n * 100) / 100
    }

    static let wsRuns = Rx(#"\s+"#), refNo = Rx(#"[:\s-]*N[º°o]\.?\s*[\w-]{4,}"#, ci: true)
    static func clean(_ t: String?) -> String {
        var s = wsRuns.replace(t ?? "", " ")
        s = refNo.replace(s, "")
        return wsRuns.replace(s, " ").jsTrimmed
    }

    static let neg = Rx(#"^(pagaste|yapeaste|enviaste|recargaste|retiraste|compraste|transferiste)\b"#)
    static let pos = Rx(#"^(te pago|te yapeo|te yapearon|te devolvio|te envio|te transfirio|recibiste|devolucion)\b"#)
    static let dateRx = Rx(#"^(\d{1,2})\/(\d{1,2})\/(\d{4})"#)

    /// `nil` si no encuentra los títulos del reporte.
    public static func read(_ rows: [[String]]) -> Nazca.StatementResult? {
        guard let h = headerAt(rows) else { return nil }
        var items: [Nazca.Item] = []
        var unreadable = 0, zero = 0, line = 0
        var from = "", to = ""
        func cell(_ r: [String], _ j: Int) -> String { j >= 0 && j < r.count ? r[j] : "" }
        var i = h.row + 1
        while i < rows.count {
            defer { i += 1 }
            let r = rows[i]
            if !r.contains(where: { !$0.jsTrimmed.isEmpty }) { continue }
            line += 1
            let ty = norm(cell(r, h.type)), amt = money(cell(r, h.amount)), dm = dateRx.groups(cell(r, h.date).jsTrimmed)
            let sign = neg.test(ty) ? -1.0 : pos.test(ty) ? 1.0 : 0.0
            guard sign != 0, let dm, let amt else { unreadable += 1; continue }
            if amt == 0 { zero += 1; continue }
            let date = String(format: "%04d-%02d-%02d", Int(dm[3])!, Int(dm[2])!, Int(dm[1])!)
            let who = wsRuns.replace(cell(r, sign < 0 ? h.to : h.from), " ").jsTrimmed
            let msg = h.msg >= 0 ? clean(cell(r, h.msg)) : ""
            let descFull = (who.isEmpty ? (sign < 0 ? "Yape" : "Yape (recibido)") : who) + (msg.isEmpty ? "" : " · " + msg)
            let desc = String(String.UnicodeScalarView(descFull.unicodeScalars.prefix(90)))
            items.append(Nazca.Item(line: line, date: date, desc: desc, amount: sign * abs(amt), cur: "PEN"))
            if from.isEmpty || date < from { from = date }
            if to.isEmpty || date > to { to = date }
        }
        var r = Nazca.StatementResult(bank: "yape", kind: "corriente", label: "Yape · Movimientos", cur: "PEN", items: items)
        r.period = from.isEmpty ? nil : .init(from: from, to: to)
        r.unreadable = unreadable; r.zero = zero
        return r
    }
}
