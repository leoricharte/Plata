import SwiftUI

/// Convierte datos de ruta SVG (`d="M10 10 L…"`) en un `Path` de SwiftUI. Cubre todos los comandos, incluidos los arcos.
enum SVGPath {
    static func parse(_ d: String) -> Path {
        var p = Path()
        let s = Array(d.unicodeScalars)
        var i = 0
        var cur = CGPoint.zero, start = CGPoint.zero
        var lastC: CGPoint?, lastQ: CGPoint?
        var cmd: Character = " "

        func skip() { while i < s.count, s[i] == " " || s[i] == "," || s[i] == "\n" || s[i] == "\t" || s[i] == "\r" { i += 1 } }
        func number() -> CGFloat? {
            skip()
            guard i < s.count else { return nil }
            let from = i
            if s[i] == "+" || s[i] == "-" { i += 1 }
            var digits = false
            while i < s.count, s[i].properties.numericType != nil, s[i].value < 128 { i += 1; digits = true }
            if i < s.count, s[i] == "." {
                i += 1
                while i < s.count, s[i].properties.numericType != nil, s[i].value < 128 { i += 1; digits = true }
            }
            if digits, i < s.count, s[i] == "e" || s[i] == "E" {
                var j = i + 1
                if j < s.count, s[j] == "+" || s[j] == "-" { j += 1 }
                if j < s.count, s[j].value >= 48, s[j].value <= 57 {
                    while j < s.count, s[j].value >= 48, s[j].value <= 57 { j += 1 }
                    i = j
                }
            }
            guard digits else { i = from; return nil }
            return CGFloat(Double(String(String.UnicodeScalarView(s[from..<i]))) ?? 0)
        }
        func flag() -> Bool? {
            skip()
            guard i < s.count, s[i] == "0" || s[i] == "1" else { return nil }
            defer { i += 1 }
            return s[i] == "1"
        }

        while true {
            skip()
            guard i < s.count else { break }
            if s[i].properties.isAlphabetic, s[i] != "e", s[i] != "E" { cmd = Character(s[i]); i += 1 }
            else if cmd == " " { break }
            let rel = cmd.isLowercase
            let c = Character(cmd.uppercased())
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { rel ? CGPoint(x: cur.x + x, y: cur.y + y) : CGPoint(x: x, y: y) }
            switch c {
            case "Z":
                p.closeSubpath(); cur = start; lastC = nil; lastQ = nil
                // tras Z un nuevo número sin comando sería inválido: sigue con el siguiente comando
                cmd = " "
                skip(); if i < s.count, !s[i].properties.isAlphabetic { return p }
            case "M":
                guard let x = number(), let y = number() else { return p }
                cur = pt(x, y); start = cur; p.move(to: cur); lastC = nil; lastQ = nil
                cmd = rel ? "l" : "L"
            case "L":
                guard let x = number(), let y = number() else { return p }
                cur = pt(x, y); p.addLine(to: cur); lastC = nil; lastQ = nil
            case "H":
                guard let x = number() else { return p }
                cur = CGPoint(x: rel ? cur.x + x : x, y: cur.y); p.addLine(to: cur); lastC = nil; lastQ = nil
            case "V":
                guard let y = number() else { return p }
                cur = CGPoint(x: cur.x, y: rel ? cur.y + y : y); p.addLine(to: cur); lastC = nil; lastQ = nil
            case "C":
                guard let a = number(), let b = number(), let c2 = number(), let d2 = number(), let x = number(), let y = number() else { return p }
                let c1 = pt(a, b), c2p = pt(c2, d2), e = pt(x, y)
                p.addCurve(to: e, control1: c1, control2: c2p); lastC = c2p; lastQ = nil; cur = e
            case "S":
                guard let c2 = number(), let d2 = number(), let x = number(), let y = number() else { return p }
                let c1 = lastC.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                let c2p = pt(c2, d2), e = pt(x, y)
                p.addCurve(to: e, control1: c1, control2: c2p); lastC = c2p; lastQ = nil; cur = e
            case "Q":
                guard let a = number(), let b = number(), let x = number(), let y = number() else { return p }
                let q = pt(a, b), e = pt(x, y)
                p.addQuadCurve(to: e, control: q); lastQ = q; lastC = nil; cur = e
            case "T":
                guard let x = number(), let y = number() else { return p }
                let q = lastQ.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                let e = pt(x, y)
                p.addQuadCurve(to: e, control: q); lastQ = q; lastC = nil; cur = e
            case "A":
                guard let rx = number(), let ry = number(), let rot = number(), let large = flag(), let sweep = flag(), let x = number(), let y = number() else { return p }
                let e = pt(x, y)
                arc(&p, from: cur, to: e, rx: abs(rx), ry: abs(ry), rot: rot, large: large, sweep: sweep)
                cur = e; lastC = nil; lastQ = nil
            default:
                return p
            }
        }
        return p
    }

    /// Arco elíptico SVG convertido a curvas de Bézier cúbicas.
    private static func arc(_ p: inout Path, from a: CGPoint, to b: CGPoint, rx rx0: CGFloat, ry ry0: CGFloat, rot: CGFloat, large: Bool, sweep: Bool) {
        var rx = rx0, ry = ry0
        if a == b { return }
        if rx == 0 || ry == 0 { p.addLine(to: b); return }
        let phi = rot * .pi / 180, cp = cos(phi), sp = sin(phi)
        let dx = (a.x - b.x) / 2, dy = (a.y - b.y) / 2
        let x1 = cp * dx + sp * dy, y1 = -sp * dx + cp * dy
        let lam = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
        if lam > 1 { let k = sqrt(lam); rx *= k; ry *= k }
        let num = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
        let den = rx * rx * y1 * y1 + ry * ry * x1 * x1
        var co = den == 0 ? 0 : sqrt(max(0, num / den))
        if large == sweep { co = -co }
        let cx1 = co * rx * y1 / ry, cy1 = -co * ry * x1 / rx
        let cx = cp * cx1 - sp * cy1 + (a.x + b.x) / 2
        let cy = sp * cx1 + cp * cy1 + (a.y + b.y) / 2
        func ang(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let dot = ux * vx + uy * vy, l = sqrt(ux * ux + uy * uy) * sqrt(vx * vx + vy * vy)
            var t = acos(max(-1, min(1, dot / l)))
            if ux * vy - uy * vx < 0 { t = -t }
            return t
        }
        let th1 = ang(1, 0, (x1 - cx1) / rx, (y1 - cy1) / ry)
        var dth = ang((x1 - cx1) / rx, (y1 - cy1) / ry, (-x1 - cx1) / rx, (-y1 - cy1) / ry)
        if !sweep && dth > 0 { dth -= 2 * .pi }
        if sweep && dth < 0 { dth += 2 * .pi }
        let n = max(1, Int(ceil(abs(dth) / (.pi / 2) - 1e-9)))
        let step = dth / CGFloat(n)
        let t = 4 / 3 * tan(step / 4)
        var th = th1
        for _ in 0..<n {
            let c1 = cos(th), s1 = sin(th), c2 = cos(th + step), s2 = sin(th + step)
            func map(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: cp * rx * x - sp * ry * y + cx, y: sp * rx * x + cp * ry * y + cy)
            }
            let p1 = map(c1 - t * s1, s1 + t * c1), p2 = map(c2 + t * s2, s2 - t * c2), e = map(c2, s2)
            p.addCurve(to: e, control1: p1, control2: p2)
            th += step
        }
    }
}
