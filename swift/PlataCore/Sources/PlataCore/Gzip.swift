import Foundation

/// gzip (RFC 1952) sobre el DEFLATE crudo de Apple. La web comprime las copias de la nube con CompressionStream('gzip').
enum Gzip {
    enum Failure: Error { case notGzip, truncated, crc }

    static func compress(_ data: Data) throws -> Data {
        let raw = try (data as NSData).compressed(using: .zlib) as Data   // en Apple, .zlib es DEFLATE crudo (sin cabecera)
        var out = Data([0x1f, 0x8b, 0x08, 0x00, 0, 0, 0, 0, 0x00, 0xff])
        out.append(raw)
        out.append(le32(crc32(data)))
        out.append(le32(UInt32(truncatingIfNeeded: data.count)))
        return out
    }

    static func decompress(_ data: Data) throws -> Data {
        let b = [UInt8](data)
        guard b.count >= 18, b[0] == 0x1f, b[1] == 0x8b, b[2] == 8 else { throw Failure.notGzip }
        let flg = b[3]
        var p = 10
        if flg & 4 != 0 { guard p + 2 <= b.count else { throw Failure.truncated }; p += 2 + Int(b[p]) + (Int(b[p + 1]) << 8) }
        if flg & 8 != 0 { while p < b.count, b[p] != 0 { p += 1 }; p += 1 }
        if flg & 16 != 0 { while p < b.count, b[p] != 0 { p += 1 }; p += 1 }
        if flg & 2 != 0 { p += 2 }
        guard p < b.count - 8 else { throw Failure.truncated }
        let deflate = Data(b[p..<(b.count - 8)])
        let out = try (deflate as NSData).decompressed(using: .zlib) as Data
        let tail = Array(b[(b.count - 8)...])
        let want = UInt32(tail[0]) | UInt32(tail[1]) << 8 | UInt32(tail[2]) << 16 | UInt32(tail[3]) << 24
        guard crc32(out) == want else { throw Failure.crc }
        return out
    }

    private static func le32(_ v: UInt32) -> Data {
        Data([UInt8(v & 0xff), UInt8((v >> 8) & 0xff), UInt8((v >> 16) & 0xff), UInt8((v >> 24) & 0xff)])
    }

    private static let table: [UInt32] = (0..<256).map { n in
        var c = UInt32(n)
        for _ in 0..<8 { c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1) }
        return c
    }

    static func crc32(_ data: Data) -> UInt32 {
        var c: UInt32 = 0xFFFFFFFF
        for byte in data { c = table[Int((c ^ UInt32(byte)) & 0xff)] ^ (c >> 8) }
        return c ^ 0xFFFFFFFF
    }
}
