import Foundation

/// El perfil de la persona: el mismo JSON (versión 3) que guarda la web en `finanzas.v3`, que exporta como archivo y que cifra para Plata Cloud.
/// Se guarda tal cual (`raw`): los campos que este código no conoce se conservan al volver a escribir, así un archivo
/// pasa de la web a iOS y de vuelta sin perder nada. Formato documentado en dev/docs/DATOS.md.
public struct Profile: Equatable, Sendable {
    public var raw: JSONValue

    public init(raw: JSONValue) { self.raw = raw }

    /// Perfil vacío de una persona nueva (igual al `EMPTY` de la web).
    public static var empty: Profile {
        Profile(raw: .object([
            "version": .number(3),
            "settings": .object(["currency": .string("USD"), "currency2": .string(""), "fx": .number(3.5), "cushion": .number(0),
                                 "variable_weekly": .number(0), "first": .string(""), "last": .string(""), "nick": .string(""), "gender": .string("n")]),
            "accounts": .array([.object(["id": .string("bank"), "name": .string("Cuenta principal"), "type": .string("checking"), "cur": .string("USD"), "balance": .number(0)])]),
            "transactions": .array([]), "history": .array([]), "cards": .array([]), "recurring": .array([]), "subs": .array([]),
            "savings": .array([]), "budget": .object([:]), "budgetSets": .array([]), "expected_income": .array([]), "expected_expense": .array([]),
            "planned": .array([]), "jobs": .array([]),
        ]))
    }

    public init(jsonData: Data) throws {
        let v = try JSONValue(jsonData: jsonData)
        guard case .object = v else { throw ProfileError.notAProfile }
        self.raw = v
    }

    public func jsonData() throws -> Data { try raw.jsonData() }

    // MARK: lectura

    private func list(_ key: String) -> [JSONValue] { raw[key]?.arrayValue ?? [] }

    public var settings: JSONValue { raw["settings"] ?? .object([:]) }
    public var isDemo: Bool { raw["demo"]?.boolValue ?? false }
    public var accounts: [Account] { decodeList("accounts") }
    public var transactions: [Transaction] { decodeList("transactions") }

    private func decodeList<T: Decodable>(_ key: String) -> [T] {
        list(key).compactMap { try? $0.decoded(as: T.self) }
    }

    /// ¿Hay algo más que el perfil vacío? (mismo criterio que `hasDataOf` de la web)
    public var hasData: Bool {
        let n = ["transactions", "cards", "savings", "subs", "expected_income", "expected_expense", "planned"].reduce(0) { $0 + list($1).count }
        return n > 0 || !(raw["budget"]?.objectValue ?? [:]).isEmpty
    }

    /// Completa lo que falte para que el resto del código pueda contar con las listas (sin tocar lo que ya hay).
    /// La web hace esto y además sanea textos y colores (`migrate` + `safeProfile`); esa parte se porta junto con las pantallas.
    public func normalized() -> Profile {
        var v = raw
        guard case .object = v else { return Profile.empty }
        let defaults = Profile.empty.raw.objectValue ?? [:]
        for (k, d) in defaults where v[k] == nil { v[k] = d }
        v["version"] = .number(3)
        return Profile(raw: v)
    }
}

public enum ProfileError: Error { case notAProfile }

// MARK: - Modelos de lectura

public struct Account: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var type: String?
    public var cur: String?
    public var balance: Double
    public var color: String?
    public var icon: String?

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeLossyString(.id)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        type = try? c.decode(String.self, forKey: .type)
        cur = try? c.decode(String.self, forKey: .cur)
        balance = (try? c.decode(Double.self, forKey: .balance)) ?? 0
        color = try? c.decode(String.self, forKey: .color)
        icon = try? c.decode(String.self, forKey: .icon)
    }
    enum CodingKeys: String, CodingKey { case id, name, type, cur, balance, color, icon }
}

public struct Transaction: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var date: String          // YYYY-MM-DD, hora local
    public var amount: Double        // gastos negativos, ingresos positivos
    public var category: String
    public var note: String
    public var acc: String?          // id de la cuenta o tarjeta
    public var est: Double?          // monto esperado, para comparar con lo real

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeLossyString(.id)
        date = (try? c.decode(String.self, forKey: .date)) ?? ""
        amount = (try? c.decode(Double.self, forKey: .amount)) ?? 0
        category = (try? c.decode(String.self, forKey: .category)) ?? ""
        note = (try? c.decode(String.self, forKey: .note)) ?? ""
        acc = try? c.decode(String.self, forKey: .acc)
        est = try? c.decode(Double.self, forKey: .est)
    }
    enum CodingKeys: String, CodingKey { case id, date, amount, category, note, acc, est }
}

private extension KeyedDecodingContainer {
    /// Los identificadores son números en los movimientos y texto en cuentas y tarjetas: se leen como texto.
    func decodeLossyString(_ key: Key) throws -> String {
        if let s = try? decode(String.self, forKey: key) { return s }
        if let n = try? decode(Double.self, forKey: key) { return JS.string(.number(n)) }
        throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: "sin id"))
    }
}
