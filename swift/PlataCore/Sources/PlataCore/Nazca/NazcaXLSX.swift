import Foundation
import Compression

/// Lector mínimo de `.xlsx` (port de `dev/app/src/core/nazca/xlsx.js`). Un .xlsx es un ZIP con XML: se abre en el dispositivo, sin librerías;
/// lee la primera hoja (textos en línea o compartidos, números). No evalúa fórmulas ni macros. Devuelve filas de texto.
/// Límites: 5 MB, 100 entradas y 30 MB descomprimidos (contra ZIP bombas).
public enum NazcaXLSX {
    public static let maxBytes = 5 * 1024 * 1024
    static let maxEntries = 100, maxOut = 30 * 1024 * 1024, maxRows = 20000

    public enum Failure: Error, Equatable { case tooBig, badZip, notXlsx }

    struct Entry { var method: Int; var csize: Int; var usize: Int; var lo: Int }

    static func u16(_ b: [UInt8], _ o: Int) -> Int { Int(b[o]) | (Int(b[o + 1]) << 8) }
    static func u32(_ b: [UInt8], _ o: Int) -> Int { Int(b[o]) | (Int(b[o + 1]) << 8) | (Int(b[o + 2]) << 16) | (Int(b[o + 3]) << 24) }

    public static func isZip(_ b: [UInt8]) -> Bool { b.count > 4 && b[0] == 0x50 && b[1] == 0x4b && (b[2] == 3 || b[2] == 5) }

    /// DEFLATE crudo con tope de tamaño (en Apple, `COMPRESSION_ZLIB` es DEFLATE sin cabecera).
    static func inflate(_ raw: [UInt8], limit: Int) throws -> [UInt8] {
        if raw.isEmpty { return [] }
        let bufSize = 64 * 1024
        let dst = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
        defer { dst.deallocate() }
        var out: [UInt8] = []
        var stream = compression_stream(dst_ptr: dst, dst_size: 0, src_ptr: UnsafePointer(dst), src_size: 0, state: nil)
        guard compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB) == COMPRESSION_STATUS_OK else { throw Failure.badZip }
        defer { compression_stream_destroy(&stream) }
        try raw.withUnsafeBufferPointer { src in
            stream.src_ptr = src.baseAddress!
            stream.src_size = src.count
            while true {
                stream.dst_ptr = dst
                stream.dst_size = bufSize
                let status = compression_stream_process(&stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
                let produced = bufSize - stream.dst_size
                if produced > 0 { out.append(contentsOf: UnsafeBufferPointer(start: dst, count: produced)) }
                if out.count > limit { throw Failure.tooBig }
                if status == COMPRESSION_STATUS_END { break }
                if status == COMPRESSION_STATUS_ERROR { throw Failure.badZip }
                if produced == 0 && stream.src_size == 0 { throw Failure.badZip }
            }
        }
        return out
    }

    static func entries(_ b: [UInt8]) throws -> [String: Entry] {
        var e = -1
        var i = b.count - 22
        let stop = max(0, b.count - 22 - 65535)
        while i >= stop { if u32(b, i) == 0x06054b50 { e = i; break }; i -= 1 }
        if e < 0 { throw Failure.badZip }
        let n = u16(b, e + 10)
        var o = u32(b, e + 16)
        if n > maxEntries { throw Failure.tooBig }
        var out: [String: Entry] = [:]
        for _ in 0..<n {
            if o + 46 > b.count || u32(b, o) != 0x02014b50 { throw Failure.badZip }
            let method = u16(b, o + 10), csize = u32(b, o + 20), usize = u32(b, o + 24)
            let nl = u16(b, o + 28), xl = u16(b, o + 30), cl = u16(b, o + 32), lo = u32(b, o + 42)
            if o + 46 + nl > b.count { throw Failure.badZip }
            let name = String(decoding: b[(o + 46)..<(o + 46 + nl)], as: UTF8.self)
            out[name] = Entry(method: method, csize: csize, usize: usize, lo: lo)
            o += 46 + nl + xl + cl
        }
        return out
    }

    static func file(_ b: [UInt8], _ ent: [String: Entry], _ name: String) throws -> String? {
        guard let x = ent[name] else { return nil }
        if x.usize > maxOut { throw Failure.tooBig }
        let o = x.lo
        if o + 30 > b.count || u32(b, o) != 0x04034b50 { throw Failure.badZip }
        let s = o + 30 + u16(b, o + 26) + u16(b, o + 28)
        if s + x.csize > b.count { throw Failure.badZip }
        let raw = Array(b[s..<(s + x.csize)])
        let bytes: [UInt8]
        switch x.method {
        case 0: bytes = raw
        case 8: bytes = try inflate(raw, limit: min(maxOut, x.usize + 16))
        default: throw Failure.badZip
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    static let entityRx = Rx(#"&(#x[0-9a-f]+|#\d+|lt|gt|amp|quot|apos);"#, ci: true)
    static func unesc(_ t: String) -> String {
        entityRx.replace(t) { g in
            let k = g[1]
            if k.hasPrefix("#") {
                let hex = k.dropFirst().lowercased().hasPrefix("x")
                let n = hex ? UInt32(k.dropFirst(2), radix: 16) : UInt32(k.dropFirst())
                return n.flatMap { Unicode.Scalar($0) }.map { String(Character($0)) } ?? g[0]
            }
            switch k.lowercased() {
            case "lt": return "<"
            case "gt": return ">"
            case "amp": return "&"
            case "quot": return "\""
            case "apos": return "'"
            default: return g[0]
            }
        }
    }

    static let tRx = Rx(#"<t(?:\s[^>]*)?>([\s\S]*?)<\/t>"#)
    static func texts(_ x: String) -> String { tRx.all(x).map { unesc($0[1]) }.joined() }

    static func colIdx(_ r: String) -> Int {
        var n = 0, any = false
        for u in r.unicodeScalars {
            guard u.value >= 65 && u.value <= 90 else { break }
            any = true
            n = n * 26 + Int(u.value) - 64
        }
        return any ? n - 1 : -1
    }

    static let siRx = Rx(#"<si\b[^>]*>([\s\S]*?)<\/si>"#)
    static let sheetRidRx = Rx(#"<sheet\b[^>]*\br:id="([^"]+)""#)
    static let cellRx = Rx(#"<c\b([^>]*?)(?:\/>|>([\s\S]*?)<\/c>)"#)
    static let refRx = Rx(#"\br="([A-Z]+)(\d+)""#)
    static let typeRx = Rx(#"\bt="([^"]+)""#)
    static let vRx = Rx(#"<v>([\s\S]*?)<\/v>"#)
    static let sheetPathRx = Rx(#"^xl\/worksheets\/[^\/]+\.xml$"#)
    static let targetRx = Rx(#"\bTarget="([^"]+)""#)

    public static func read(_ data: Data) throws -> [[String]] {
        let b = [UInt8](data)
        if b.count > maxBytes { throw Failure.tooBig }
        if !isZip(b) { throw Failure.notXlsx }
        let ent = try entries(b)
        if ent["xl/workbook.xml"] == nil { throw Failure.notXlsx }
        var path = "xl/worksheets/sheet1.xml"
        if let wb = try file(b, ent, "xl/workbook.xml"), let rels = try file(b, ent, "xl/_rels/workbook.xml.rels"), let sid = sheetRidRx.groups(wb) {
            let id = sid[1].filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "." || $0 == "-") }
            let relRx = Rx(#"<Relationship\b[^>]*\bId=""# + id + #""[^>]*>"#, ci: true)
            if let tag = relRx.first(rels), let t = targetRx.groups(tag) {
                var p = t[1]
                if p.hasPrefix("/") { p.removeFirst() }
                if !p.hasPrefix("xl/") { p = "xl/" + p }
                path = p
            }
        }
        if ent[path] == nil { path = ent.keys.sorted().first { sheetPathRx.test($0) } ?? "" }
        if path.isEmpty { throw Failure.notXlsx }
        var ss: [String] = []
        if let sx = try file(b, ent, "xl/sharedStrings.xml") { ss = siRx.all(sx).map { texts($0[1]) } }
        guard let xml = try file(b, ent, path) else { throw Failure.notXlsx }
        var rows: [Int: [Int: String]] = [:]
        var maxRow = -1
        for m in cellRx.all(xml) {
            let at = m[1]
            guard let ref = refRx.groups(at), !m[2].isEmpty || m[0].hasSuffix("</c>") else { continue }
            // celda vacía <c .../> no trae contenido (m[2] vacío): la web la salta con `m[2] == null`
            if !m[0].hasSuffix("</c>") { continue }
            let ri = (Int(ref[2]) ?? 0) - 1, ci = colIdx(ref[1])
            if ri < 0 || ri >= maxRows || ci < 0 || ci > 60 { continue }
            let t = typeRx.groups(at)?[1]
            let v = vRx.groups(m[2])
            let val: String
            if t == "inlineStr" { val = texts(m[2]) }
            else if t == "s" { val = v.flatMap { Int($0[1]) }.flatMap { $0 >= 0 && $0 < ss.count ? ss[$0] : nil } ?? "" }
            else { val = v.map { unesc($0[1]) } ?? "" }
            if val.isEmpty { continue }
            rows[ri, default: [:]][ci] = val
            maxRow = max(maxRow, ri)
        }
        var out: [[String]] = []
        if maxRow >= 0 {
            for i in 0...maxRow {
                let r = rows[i] ?? [:]
                let width = (r.keys.max() ?? -1) + 1
                out.append((0..<width).map { r[$0] ?? "" })
            }
        }
        return out
    }
}
