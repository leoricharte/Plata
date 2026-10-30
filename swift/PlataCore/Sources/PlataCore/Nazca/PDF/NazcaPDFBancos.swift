import Foundation

/// Pasarela por banco para PDF (puerto de `bancos/index.js`): Nazca reconoce el banco por el CONTENIDO del archivo y usa el lector que corresponde.
public enum NazcaPDFBancos {
    public struct Reader: Sendable {
        public let id: String
        public let bank: String
        public let label: String
        let detectFn: @Sendable (PdfDoc) -> Int
        let readFn: @Sendable (PdfDoc) -> Nazca.StatementResult?
        public func detect(_ doc: PdfDoc) -> Int { detectFn(doc) }
        public func read(_ doc: PdfDoc) -> Nazca.StatementResult? { readFn(doc) }
    }

    /// En el mismo orden que `READERS` de la web: el primero que reconoce el documento gana.
    public static let readers: [Reader] = [
        Reader(id: "bcp-ahorros", bank: "bcp", label: "BCP · Cuenta de ahorros", detectFn: { NazcaBCP.detect($0) }, readFn: { NazcaBCP.read($0) }),
        Reader(id: "interbank-ahorros", bank: "interbank", label: "Interbank · Cuenta de ahorros", detectFn: { NazcaInterbank.detect($0) }, readFn: { NazcaInterbank.read($0) }),
        Reader(id: "capitalone-tarjeta", bank: "capitalone", label: "Capital One · Tarjeta de crédito", detectFn: { NazcaCapitalOne.detect($0) }, readFn: { NazcaCapitalOne.read($0) }),
        Reader(id: "chime-checking", bank: "chime", label: "Chime · Cuenta corriente", detectFn: { NazcaChime.detect($0) }, readFn: { NazcaChime.read($0) }),
        Reader(id: "seen-tarjeta", bank: "seen", label: "Seen · Tarjeta de crédito", detectFn: { NazcaSeen.detect($0) }, readFn: { NazcaSeen.read($0) }),
        Reader(id: "bofa-cheques", bank: "bofa", label: "Bank of America · Cuenta de cheques", detectFn: { NazcaBofA.detect($0) }, readFn: { NazcaBofA.read($0) }),
        Reader(id: "applecard-tarjeta", bank: "applecard", label: "Apple Card · Tarjeta de crédito", detectFn: { NazcaAppleCard.detect($0) }, readFn: { NazcaAppleCard.read($0) }),
        Reader(id: "communitybank-cuenta", bank: "communitybank", label: "Community Bank · Cuenta corriente", detectFn: { NazcaCommunityBank.detect($0) }, readFn: { NazcaCommunityBank.read($0) }),
        Reader(id: "io-tarjeta", bank: "io", label: "iO · Tarjeta de crédito", detectFn: { NazcaIO.detect($0) }, readFn: { NazcaIO.read($0) }),
        Reader(id: "capitalone-cuenta", bank: "capitalone", label: "Capital One · Cuenta de cheques", detectFn: { NazcaCapitalOneCuenta.detect($0) }, readFn: { NazcaCapitalOneCuenta.read($0) }),
        Reader(id: "bbva-cuenta", bank: "bbva", label: "BBVA · Cuenta", detectFn: { NazcaBBVA.detect($0) }, readFn: { NazcaBBVA.read($0) }),
        Reader(id: "interbank-tarjeta", bank: "interbank", label: "Interbank · Tarjeta de crédito", detectFn: { NazcaInterbankTarjeta.detect($0) }, readFn: { NazcaInterbankTarjeta.read($0) }),
        Reader(id: "bcp-tarjeta", bank: "bcp", label: "BCP · Tarjeta de crédito", detectFn: { NazcaBCPTarjeta.detect($0) }, readFn: { NazcaBCPTarjeta.read($0) }),
        Reader(id: "mercadopago-cuenta", bank: "mercadopago", label: "Mercado Pago · Cuenta", detectFn: { NazcaMercadoPago.detect($0) }, readFn: { NazcaMercadoPago.read($0) }),
        Reader(id: "tjx-tarjeta", bank: "tjx", label: "TJX Rewards · Tarjeta de crédito", detectFn: { NazcaTJX.detect($0) }, readFn: { NazcaTJX.read($0) }),
        Reader(id: "milestone-tarjeta", bank: "milestone", label: "Milestone · Tarjeta de crédito", detectFn: { NazcaMilestone.detect($0) }, readFn: { NazcaMilestone.read($0) })]

    /// El lector que reconoce el documento, o nil. `onlyBank`: si la persona ya eligió un banco, solo prueba ese.
    public static func detect(_ doc: PdfDoc, onlyBank: String? = nil) -> Reader? {
        readers.first { (onlyBank == nil || $0.bank == onlyBank) && $0.detect(doc) >= 1 }
    }
}
