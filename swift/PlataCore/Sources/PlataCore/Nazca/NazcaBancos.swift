import Foundation

/// La lista de bancos que Nazca conoce (`NazcaBancos.CATALOG` de la web) y lo que sirve para reconocerlos.
extension Nazca {
    public struct Bank: Equatable, Identifiable, Sendable {
        public var id: String
        public var name: String
        public var hq: String
        public var active: Bool
    }

    public struct Country: Equatable, Identifiable, Sendable {
        public var id: String
        public var name: String
        public var banks: [Bank]
    }

    /// Países y bancos, en el orden de la web: los activos primero y, dentro de cada grupo, alfabético.
    public static let bankCatalog: [Country] = {
        func b(_ id: String, _ name: String, _ hq: String, _ active: Bool = true) -> Bank { Bank(id: id, name: name, hq: hq, active: active) }
        let raw: [Country] = [
            Country(id: "PE", name: "Perú", banks: [
                b("bcp", "Banco de Crédito del Perú", "La Molina, Lima"), b("interbank", "Interbank", "La Victoria, Lima"), b("io", "iO", "La Molina, Lima"),
                b("yape", "Yape", "La Molina, Lima"), b("bbva", "BBVA Perú", "San Isidro, Lima"), b("scotiabank", "Scotiabank Perú", "San Isidro, Lima", false)]),
            Country(id: "US", name: "Estados Unidos", banks: [
                b("capitalone", "Capital One", "McLean, Virginia"), b("chime", "Chime", "San Francisco, California"), b("seen", "Seen", "Salt Lake City, Utah"),
                b("bofa", "Bank of America", "Charlotte, North Carolina"), b("applecard", "Apple Card", "Cupertino, California"),
                b("communitybank", "Community Bank, N.A.", "Canton, New York"), b("tjx", "TJX Rewards", "Framingham, Massachusetts"),
                b("milestone", "Milestone", "Beaverton, Oregon")]),
            Country(id: "CL", name: "Chile", banks: [b("mercadopago", "Mercado Pago", "Las Condes, Santiago")])]
        let es = Locale(identifier: "es")
        return raw.map { c in
            var c = c
            c.banks = c.banks.enumerated().sorted { x, y in
                if x.element.active != y.element.active { return x.element.active }
                let o = x.element.name.compare(y.element.name, options: [.caseInsensitive, .diacriticInsensitive], range: nil, locale: es)
                return o == .orderedSame ? x.offset < y.offset : o == .orderedAscending
            }.map(\.element)
            return c
        }
    }()

    public static func bankName(_ id: String?) -> String { bankCatalog.flatMap(\.banks).first { $0.id == id }?.name ?? "" }
    public static func bankShort(_ id: String?) -> String { id == "bcp" ? "BCP" : bankName(id) }
    public static func countryOf(_ bank: String) -> Country? { bankCatalog.first { $0.banks.contains { $0.id == bank } } }
    /// El nombre del país de un banco («Perú» si no se conoce).
    public static func countryName(_ bank: String) -> String { countryOf(bank)?.name ?? "Perú" }

    /// Cómo se reconoce un banco por el nombre de una cuenta de la persona (`BANKS[].keys` de la web).
    static let bankKeys: [[String]] = [
        ["bbva"], ["yape"], ["interbank", "ibk"], ["bcp", "banco de credito del peru"], ["scotiabank", "scotia", "sbk"], ["io", "tarjeta io"],
        ["capital one", "capitalone", "cap one"], ["chime"], ["seen"], ["bank of america", "bankofamerica", "bofa"], ["apple card", "applecard"],
        ["community bank", "communitybank", "cbna"], ["mercado pago", "mercadopago"], ["tjx rewards", "tjxrewards", "tjx"], ["milestone", "milestone mastercard"]]

    /// ¿El nombre de la cuenta (ya sin tildes ni mayúsculas) nombra a ese banco? Devuelve las claves del banco o nil.
    static func bankKeys(ofName name: String) -> [String]? {
        let n = Engine.bankNorm(name)
        if n.isEmpty { return nil }
        return bankKeys.first { ks in ks.contains { Rx("(^|[^a-z0-9])" + NSRegularExpression.escapedPattern(for: $0) + "([^a-z0-9]|$)").test(n) } }
    }

    /// Un CSV con columnas propias de un banco (hoy, Apple Card): por las columnas se reconoce el banco.
    public struct CSVSignature: Equatable, Sendable {
        public var bank: String
        public var kind: String
        public var label: String
        public var cur: String
        /// Ese CSV imprime las compras en positivo y los pagos en negativo; Plata los guarda al revés.
        public var flip: Bool
        var need: [String]
    }

    static let csvSignatures = [CSVSignature(bank: "applecard", kind: "tarjeta", label: "Apple Card · Tarjeta de crédito", cur: "USD", flip: true,
                                             need: ["transaction date", "clearing date", "merchant", "type", "amount (usd)", "purchased by"])]

    public static func detectCsv(_ headers: [String]) -> CSVSignature? {
        let h = headers.map { $0.jsTrimmed.lowercased() }
        return csvSignatures.first { sg in sg.need.allSatisfy { h.contains($0) } }
    }

    /// Los bancos de los que Nazca ya sabe leer algún archivo en esta versión de la app; los demás salen como «No disponible».
    public nonisolated(unsafe) static var ready: Set<String> = ["yape"]

    /// Cómo descargar el estado de cuenta, paso a paso, por banco (`IMP_STEPS` de la web).
    public static let bankSteps: [String: [String]] = [
        "bcp": ["Ve a la Banca por Internet.", "Elige la cuenta a consultar.", "Selecciona la opción Más, y después Estado de Cuenta.", "Elige el mes y año a consultar.", "Genera el estado de cuenta y descárgalo de tu correo."],
        "yape": ["Abre la app de Yape.", "Toca Movimientos.", "Descarga el reporte de movimientos en Excel.", "Guarda el archivo en tu celular o en tu PC."],
        "io": ["Abre la app iO.", "Entra a tu tarjeta de crédito.", "Abre Estados de cuenta.", "Elige el ciclo a consultar.", "Descarga el estado de cuenta en PDF."],
        "communitybank": ["Entra a la banca en línea o a la app de Community Bank.", "Abre tu cuenta y luego eStatements.", "Elige el mes a consultar.", "Descarga el estado de cuenta en PDF."],
        "bofa": ["Entra a la app o a bankofamerica.com.", "Elige tu cuenta.", "Abre Statements & Documents.", "Elige el mes a consultar.", "Descarga el estado de cuenta."],
        "milestone": ["Entra a mymilestonecard.com o a la app de Milestone.", "Abre tu cuenta y luego Statements.", "Elige el mes a consultar.", "Descarga el estado de cuenta en PDF."],
        "tjx": ["Entra a tjxrewards.com o a la app de TJX Rewards.", "Abre tu cuenta y luego Statements.", "Elige el mes a consultar.", "Descarga el estado de cuenta en PDF."],
        "applecard": ["Abre Wallet en tu iPhone y toca tu Apple Card.", "Toca Card Balance y luego Statements.", "Elige el mes a consultar.", "Toca Share o Descargar para guardar el PDF."],
        "seen": ["Abre la app de Seen.", "Elige tu tarjeta.", "Abre Statements.", "Elige el mes a consultar.", "Descarga el estado de cuenta."],
        "chime": ["Abre la app de Chime.", "Toca Cuenta o Settings.", "Abre Statements & documents.", "Elige el mes a consultar.", "Descarga el estado de cuenta."],
        "capitalone": ["Entra a tu cuenta en la app o en la web de Capital One.", "Elige la tarjeta a consultar.", "Abre Statements.", "Elige el mes a consultar.", "Descarga el estado de cuenta."],
        "mercadopago": ["Abre la app de Mercado Pago o entra a mercadopago.cl.", "Abre tu actividad o tus movimientos.", "Busca la opción para descargar el estado de cuenta.", "Elige el periodo a consultar.", "Descarga el estado de cuenta en PDF."],
        "bbva": ["Entra a la banca por internet o a la app de BBVA.", "Elige tu cuenta.", "Abre Movimientos y saldos.", "Elige el periodo a consultar.", "Descarga el estado de cuenta en PDF."],
        "interbank": ["Ve a la Banca por Internet.", "Elige la cuenta a consultar.", "Elige los ⋯ en la parte derecha.", "Elige el mes y año a consultar.", "Genera el estado de cuenta y guárdalo."]]

    /// Bancos cuyo estado de cuenta siempre viene con clave: qué se le pide a la persona (`IMP_KEY`).
    public struct KeyInfo: Sendable { public var label: String; public var numeric: Bool; public var note: String }
    public static let bankKey: [String: KeyInfo] = [
        "bcp": KeyInfo(label: "DNI", numeric: true, note: "El BCP protege el estado de cuenta con tu DNI. Plata no lo guarda ni lo revisa: solo sirve para abrirlo en este dispositivo."),
        "io": KeyInfo(label: "DNI", numeric: true, note: "iO protege el estado de cuenta con tu DNI. Plata no lo guarda ni lo revisa: solo sirve para abrirlo en este dispositivo.")]
}
