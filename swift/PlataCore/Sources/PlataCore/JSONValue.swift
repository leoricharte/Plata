import Foundation

/// Un valor JSON cualquiera. El perfil de Plata se guarda como JSON sin esquema fijo (la web agrega campos con el tiempo),
/// así que el núcleo trabaja sobre este tipo: lo que no conoce lo conserva intacto al leer y volver a escribir el archivo.
public enum JSONValue: Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])
}

extension JSONValue: Codable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
        else if let o = try? c.decode([String: JSONValue].self) { self = .object(o) }
        else { throw DecodingError.dataCorruptedError(in: c, debugDescription: "JSON no válido") }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .number(let n):
            // Los enteros salen sin ".0", como los escribe la web.
            if n.rounded() == n, abs(n) < 9e15 { try c.encode(Int64(n)) } else { try c.encode(n) }
        case .string(let s): try c.encode(s)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }
}

public extension JSONValue {
    init(jsonData: Data) throws { self = try JSONDecoder().decode(JSONValue.self, from: jsonData) }

    func jsonData(sorted: Bool = false) throws -> Data {
        let e = JSONEncoder()
        if sorted { e.outputFormatting = [.sortedKeys] }
        return try e.encode(self)
    }

    subscript(key: String) -> JSONValue? {
        get { if case .object(let o) = self { return o[key] } else { return nil } }
        set {
            guard case .object(var o) = self else { return }
            o[key] = newValue
            self = .object(o)
        }
    }

    var objectValue: [String: JSONValue]? { if case .object(let o) = self { return o } else { return nil } }
    var arrayValue: [JSONValue]? { if case .array(let a) = self { return a } else { return nil } }
    var stringValue: String? { if case .string(let s) = self { return s } else { return nil } }
    var doubleValue: Double? { if case .number(let n) = self { return n } else { return nil } }
    var intValue: Int? { if case .number(let n) = self, n.rounded() == n { return Int(n) } else { return nil } }
    var boolValue: Bool? { if case .bool(let b) = self { return b } else { return nil } }
    var isNull: Bool { if case .null = self { return true } else { return false } }

    /// Decodifica este valor como un tipo concreto (por ejemplo, `Transaction`).
    func decoded<T: Decodable>(as type: T.Type = T.self) throws -> T {
        try JSONDecoder().decode(T.self, from: jsonData())
    }

    init<T: Encodable>(encoding value: T) throws {
        self = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(value))
    }
}

// MARK: - Reglas de JavaScript que usa la combinación de perfiles (deben coincidir con la web)

enum JS {
    /// Veracidad de JS: undefined, null, false, 0, NaN y "" son falsos; todo lo demás (incluidos [] y {}) es verdadero.
    static func truthy(_ v: JSONValue?) -> Bool {
        switch v {
        case .none, .some(.null): return false
        case .some(.bool(let b)): return b
        case .some(.number(let n)): return n != 0 && !n.isNaN
        case .some(.string(let s)): return !s.isEmpty
        default: return true
        }
    }

    /// `String(x)` de JS para identificadores (números enteros sin ".0").
    static func string(_ v: JSONValue) -> String {
        switch v {
        case .string(let s): return s
        case .number(let n): return n.rounded() == n && abs(n) < 9e15 ? String(Int64(n)) : String(n)
        case .bool(let b): return b ? "true" : "false"
        case .null: return "null"
        case .array: return ""
        case .object: return "[object Object]"
        }
    }

    /// `x.mod || 0`
    static func mod(_ v: JSONValue) -> Double {
        if let n = v["mod"]?.doubleValue, n != 0, !n.isNaN { return n }
        return 0
    }

    /// `Math.round`: redondea .5 hacia arriba (no "lejos de cero").
    static func round(_ x: Double) -> Double { (x + 0.5).rounded(.down) }
}
