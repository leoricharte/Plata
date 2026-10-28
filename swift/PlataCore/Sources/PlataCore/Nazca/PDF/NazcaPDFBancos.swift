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
        Reader(id: "bcp-ahorros", bank: "bcp", label: "BCP · Cuenta de ahorros", detectFn: NazcaBCP.detect, readFn: NazcaBCP.read),
        Reader(id: "interbank-ahorros", bank: "interbank", label: "Interbank · Cuenta de ahorros", detectFn: NazcaInterbank.detect, readFn: NazcaInterbank.read),
        Reader(id: "capitalone-tarjeta", bank: "capitalone", label: "Capital One · Tarjeta de crédito", detectFn: NazcaCapitalOne.detect, readFn: NazcaCapitalOne.read),
        Reader(id: "chime-checking", bank: "chime", label: "Chime · Cuenta corriente", detectFn: NazcaChime.detect, readFn: NazcaChime.read),
        Reader(id: "seen-tarjeta", bank: "seen", label: "Seen · Tarjeta de crédito", detectFn: NazcaSeen.detect, readFn: NazcaSeen.read),
        Reader(id: "bofa-cheques", bank: "bofa", label: "Bank of America · Cuenta de cheques", detectFn: NazcaBofA.detect, readFn: NazcaBofA.read),
        Reader(id: "applecard-tarjeta", bank: "applecard", label: "Apple Card · Tarjeta de crédito", detectFn: NazcaAppleCard.detect, readFn: NazcaAppleCard.read),
        Reader(id: "communitybank-cuenta", bank: "communitybank", label: "Community Bank · Cuenta corriente", detectFn: NazcaCommunityBank.detect, readFn: NazcaCommunityBank.read),
        Reader(id: "io-tarjeta", bank: "io", label: "iO · Tarjeta de crédito", detectFn: NazcaIO.detect, readFn: NazcaIO.read),
        Reader(id: "capitalone-cuenta", bank: "capitalone", label: "Capital One · Cuenta de cheques", detectFn: NazcaCapitalOneCuenta.detect, readFn: NazcaCapitalOneCuenta.read),
        Reader(id: "bbva-cuenta", bank: "bbva", label: "BBVA · Cuenta", detectFn: NazcaBBVA.detect, readFn: NazcaBBVA.read),
        Reader(id: "interbank-tarjeta", bank: "interbank", label: "Interbank · Tarjeta de crédito", detectFn: NazcaInterbankTarjeta.detect, readFn: NazcaInterbankTarjeta.read),
        Reader(id: "bcp-tarjeta", bank: "bcp", label: "BCP · Tarjeta de crédito", detectFn: NazcaBCPTarjeta.detect, readFn: NazcaBCPTarjeta.read),
        Reader(id: "mercadopago-cuenta", bank: "mercadopago", label: "Mercado Pago · Cuenta", detectFn: NazcaMercadoPago.detect, readFn: NazcaMercadoPago.read),
        Reader(id: "tjx-tarjeta", bank: "tjx", label: "TJX Rewards · Tarjeta de crédito", detectFn: NazcaTJX.detect, readFn: NazcaTJX.read),
        Reader(id: "milestone-tarjeta", bank: "milestone", label: "Milestone · Tarjeta de crédito", detectFn: NazcaMilestone.detect, readFn: NazcaMilestone.read)]

    /// El lector que reconoce el documento, o nil. `onlyBank`: si la persona ya eligió un banco, solo prueba ese.
    public static func detect(_ doc: PdfDoc, onlyBank: String? = nil) -> Reader? {
        readers.first { (onlyBank == nil || $0.bank == onlyBank) && $0.detect(doc) >= 1 }
    }
}
