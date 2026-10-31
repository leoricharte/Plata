import Foundation

/// A dónde llega lo que la persona decida compartir. Hoy no hay ninguno: `NazcaShare.enabled` está apagado y nada sale del dispositivo.
public protocol NazcaShareSink: Sendable {
    func send(_ payload: NazcaShare.Payload) async throws
}

/// El puente para que, más adelante, la persona pueda ayudar a Nazca compartiendo SOLO la forma de una captura.
/// El paquete es un formato cerrado: enteros y palabras fijas, sin texto libre. No cabe en él ningún monto, descripción, fecha ni identificador.
public enum NazcaShare {
    /// Apagado: el envío no existe hasta que se decida, se avise en la privacidad de la app y haya un servidor que lo reciba.
    public nonisolated(unsafe) static var enabled = false

    public static let schema = 1
    /// Los únicos nombres que viajan. Todo lo demás es «otro».
    public static let banks = ["bcp", "interbank", "bbva", "io", "yape", "plin", "capitalone", "chime", "bofa", "applecard", "mercadopago"]
    /// Las posiciones se redondean a una cuadrícula de 1/20 (5 %).
    static let grid = 20.0

    public struct Payload: Codable, Equatable, Sendable {
        public var schema: Int
        public var bank: String
        public var amountX: Int
        public var rightAligned: Bool
        public var tol: Int
        public var descDy: Int
        public var descLeft: Int
        public var dateMode: String
        public var dateDy: Int
        public var signMode: String
        /// Siempre «pending» al salir de la app: solo Nazca global la pasa a «verified», tras revisarla y probarla con capturas sintéticas.
        public var status = "pending"
    }

    public static func payload(_ t: NazcaExample.Template, bank: String?) -> Payload {
        func g(_ v: Double) -> Int { Int((max(0, min(1, v)) * grid).rounded()) }
        let b = (bank ?? "").lowercased()
        var dm = "none", dy = 0
        switch t.dateMode {
        case .row(let d): dm = "row"; dy = max(-2, min(2, d))
        case .header: dm = "header"
        case .none: break
        }
        let sm: String
        switch t.signMode { case .marker: sm = "marker"; case .tone: sm = "tone"; case .fixed: sm = "fixed" }
        return Payload(schema: schema, bank: banks.contains(b) ? b : "otro", amountX: g(t.amountX), rightAligned: t.rightAligned,
                       tol: max(1, g(t.tol)), descDy: max(-2, min(2, t.descDy)), descLeft: g(t.descLeft), dateMode: dm, dateDy: dy, signMode: sm)
    }

    /// Envía el paquete por el canal dado, solo si el puente está encendido. Devuelve lo enviado (o `nil` si está apagado).
    @discardableResult
    public static func submit(_ t: NazcaExample.Template, bank: String?, via sink: NazcaShareSink) async throws -> Payload? {
        guard enabled else { return nil }
        let p = payload(t, bank: bank)
        try await sink.send(p)
        return p
    }
}
