import Foundation

extension Nazca {
    /// Un estado de cuenta ya leído por el lector de un banco (PDF, Excel o CSV propio del banco): lo que la web llama el resultado de `NazcaBancos`.
    public struct StatementResult: Sendable {
        public struct Period: Equatable, Sendable { public var from: String; public var to: String
            public init(from: String, to: String) { self.from = from; self.to = to } }
        /// ¿Cuadra con los totales y el saldo final del banco? `ok == nil` = no se pudo comprobar.
        public struct Check: Equatable, Sendable {
            public var ok: Bool?
            /// El saldo final que trae el estado (en tarjetas, la deuda).
            public var end: Double?
            public var n: Int
            public init(ok: Bool?, end: Double? = nil, n: Int = 1) { self.ok = ok; self.end = end; self.n = n }
        }
        public struct CardInfo: Equatable, Sendable {
            public var limit: Double?
            public var apr: Double?
            public var minPayment: Double?
            public var dueDay: Int?
            public var dueDate: String?
            public init() {}
        }

        public var bank: String
        public var kind: String
        public var label: String
        public var cur: String
        public var last4 = ""
        public var name = ""
        public var apy: Double?
        public var period: Period?
        public var items: [Item]
        public var unreadable = 0
        public var zero = 0
        public var check: Check?
        public var card: CardInfo?

        public init(bank: String, kind: String, label: String, cur: String, items: [Item]) {
            self.bank = bank; self.kind = kind; self.label = label; self.cur = cur; self.items = items
        }
    }
}

extension Nazca.Analysis {
    /// Sin tabla: lo que tiene una revisión que viene de un estado de cuenta ya leído.
    static let blank = Nazca.Analysis(delim: ",", headerRow: 0, headers: [], width: 0, cols: Nazca.Columns(), dec: ".", order: "dmy", rows: [], truncated: false)
}
