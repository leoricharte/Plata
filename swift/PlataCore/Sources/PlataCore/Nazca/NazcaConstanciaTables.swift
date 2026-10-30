// GENERADO por swift/tools/gen-nazca-constancia.mjs a partir de dev/app/src/core/nazca/constancia.js. No editar a mano.
import Foundation

extension NazcaConstancia {
    static let neg = Rx(#"\b(yapeaste|plineaste|enviaste|pagaste|transferiste|enviado a|enviado con exito|envio realizado|pago realizado|yapeo realizado|importe enviado|envio a contactos?)\b"#)
    static let pos = Rx(#"\b(te yapearon|te yapeo|te plinearon|te plineo|te enviaron|te envio|te pago|te transfirieron|te transfirio|te devolvieron|recibiste|recibido de)\b"#)
    static let key = Rx(#"(yapeaste|plineaste|enviaste|pagaste|transferiste|te yapearon|te yapeo|te plinearon|te plineo|te enviaron|te envio|te pago|recibiste|monto|importe|total)"#)
    static let bad = Rx(#"(comision|saldo|limite|disponible|itf|cargo|costo)"#)
    static let amt = Rx(#"(?:^|[^A-Za-z0-9])(?:(S[ \t]*\/[ \t]*\.?|PEN|US[ \t]*\$|USD|\$)|(5[ \t]*\/[ \t]*\.?)(?:(?!\d)|(?=\d+[.,]\d{2}(?![.,]?\d))))[ \t]*(?:([-−–])[ \t]*)?(\d{1,3}(?:[. ]\d{3})+(?:[.,]\d{1,2})?|\d{1,3}(?:,\d{3})+(?:[.]\d{1,2})?|\d+(?:[.,]\d{1,2})?)(?![.,]?\d|[ \t]*\/[ \t]*\d)"#, ci: true)
    static let labelTo = Rx(#"^(nombre del destinatario|nombre de destinatario|destinatario|destino|enviado a|enviaste a|pagaste a|yapeaste a|plineaste a|transferiste a|beneficiario|nombre del beneficiario|pagado a|comercio|contacto|para(?=[ ]*:))\b[ ]*[:\-]?[ ]*(.*)$"#)
    static let labelFrom = Rx(#"^(nombre del remitente|remitente|origen|enviado por|de parte de|recibido de|de)\b[ ]*[:\-]?[ ]*(.*)$"#)
    static let labelMsg = Rx(#"^(mensaje|detalle(?![ ]+de[ ]+(?:movimiento|la[ ]+operacion))|concepto|motivo|descripcion|referencia|servicio)\b[ ]*[:\-]?[ ]*(.*)$"#)
    static let labelish = Rx(#"^(nombre|celular|telefono|numero|nro|cuenta|monto|importe|total|fecha|hora|mensaje|detalle|concepto|motivo|operacion|codigo|destino|origen|destinatario|remitente|enviado|recibido|banco|comision|saldo|referencia|servicio|datos|id)\b"#)
    static let inlineNeg = Rx(#"(?:yapeaste|plineaste|enviaste|pagaste|transferiste)[ ]+(?:(?:s\/|5\/)[ ]*[\d.,]+[ ]+)?a[ ]+(.+)$"#)
    static let inlinePos = Rx(#"^(.+?)[ ]+te[ ]+(?:yapeo|plineo|envio|pago|transfirio)\b"#)
    static let op = Rx(#"(?:n[ro°º.]*[ ]*(?:de[ ]*)?operacion|codigo[ ]*(?:de[ ]*)?operacion|numero[ ]*de[ ]*operacion|id[ ]*(?:de[ ]*)?operacion|codigo[ ]*(?:de[ ]*)?transaccion|operacion[ ]*n[ro°º.]*|operacion)[ ]*[:#]?[ ]*([a-z0-9][a-z0-9.-]{4,28})"#)
    static let dateIso = Rx(#"(\d{4})-(\d{2})-(\d{2})"#)
    static let dateWords = Rx(#"(\d{1,2})[ ]*(?:de[ ]+)?([a-z]{3,10})\.?,?[ ]*(?:de[ ]+)?(\d{4})"#)
    static let dateNum = Rx(#"(\d{1,2})[\/.-](\d{1,2})[\/.-](\d{4}|\d{2})(?![\d])"#)
    static let timeRe = Rx(#"(\d{1,2}):(\d{2})(?::\d{2})?[ ]*(?:([ap])\.?[ ]?m\b\.?)?"#)
    static let headCon = Rx(#"^(pagaste|enviaste|transferiste|yapeaste|plineaste)[ ]+con[ ]+(plin|yape)\b"#)
    static let dashWho = Rx(#"(?:^|[ ])(?:plin|yape)[ ]*[-–][ ]*([a-zñ].*)$"#, ci: true)
    static let entidadRx = Rx(#"entidad de destino"#)
    static let months: [String: Int] = ["ene": 1, "jan": 1, "feb": 2, "mar": 3, "abr": 4, "apr": 4, "may": 5, "jun": 6, "jul": 7, "ago": 8, "aug": 8, "set": 9, "sep": 9, "oct": 10, "nov": 11, "dic": 12, "dec": 12]
    static let maxChars = 6000
    static let maxLines = 80
}
