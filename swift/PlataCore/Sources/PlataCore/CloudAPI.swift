import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Transporte HTTP intercambiable: en la app es `URLSession`; en las pruebas, un servidor falso.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

extension URLSession: HTTPTransport {
    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (d, r) = try await data(for: request)
        guard let h = r as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (d, h)
    }
}

/// Respuesta del servidor: código HTTP y cuerpo JSON (vacío si no había cuerpo). Igual que `{ s, j }` en `clFetch` de la web.
public struct CloudResponse: Equatable, Sendable {
    public var status: Int
    public var json: JSONValue
    public var ok: Bool { status == 200 }
    public subscript(key: String) -> JSONValue? { json[key] }
}

/// Cliente del servidor de Plata Cloud (Cloudflare Worker, dev/worker/worker.js; protocolo en dev/docs/WORKER.md).
/// Una app nativa no manda el encabezado `Origin`, y el servidor solo rechaza orígenes de navegador que no estén en su lista,
/// así que no hace falta cambiar nada en el servidor para conectarse desde Swift.
public struct CloudAPI: Sendable {
    public static let productionURL = URL(string: "https://plata-cloud.xleoricharte.workers.dev")!

    public var baseURL: URL
    public var transport: HTTPTransport

    public init(baseURL: URL = CloudAPI.productionURL, transport: HTTPTransport = URLSession.shared) {
        self.baseURL = baseURL
        self.transport = transport
    }

    /// Llamada genérica. `token` va como `Authorization: Bearer` y `writeKey` como `X-Plata-Write`.
    public func call(_ path: String, method: String = "GET", body: JSONValue? = nil, token: String? = nil, writeKey: String? = nil) async throws -> CloudResponse {
        var req = URLRequest(url: URL(string: baseURL.absoluteString + path)!)
        req.httpMethod = method
        req.timeoutInterval = 30
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
        if let writeKey { req.setValue(writeKey, forHTTPHeaderField: "X-Plata-Write") }
        if let body { req.httpBody = try body.jsonData() }
        let (data, http) = try await transport.send(req)
        let json = (try? JSONValue(jsonData: data)) ?? .object([:])
        return CloudResponse(status: http.statusCode, json: json)
    }

    // MARK: inicio de sesión (sin contraseña: código por correo + frase de 12 palabras)

    /// Pide el código por correo. `access` false: no tiene acceso (`listed` indica si está en la lista de espera).
    public func authStart(email: String, lang: String) async throws -> CloudResponse {
        try await call("/auth/start", method: "POST", body: .object(["email": .string(email), "lang": .string(lang)]))
    }

    /// Verifica el código. Devuelve `token`, `new`, `hasKey`, `kc`, `hasData`, `rev`.
    public func authVerify(email: String, code: String, device: String) async throws -> CloudResponse {
        try await call("/auth/verify", method: "POST", body: .object(["email": .string(email), "code": .string(code), "dev": .string(device)]))
    }

    /// Cuenta nueva: fija la comprobación de clave y la llave de escritura (derivadas de la semilla).
    public func putKey(seed: Data, token: String) async throws -> CloudResponse {
        try await call("/me/key", method: "PUT", body: .object(["kc": .string(CloudCrypto.keyCheck(seed: seed))]), token: token, writeKey: CloudCrypto.writeKey(seed: seed))
    }

    public func logout(token: String) async throws -> CloudResponse {
        try await call("/auth/logout", method: "POST", token: token)
    }

    // MARK: copia cifrada

    /// `{ rev, next, blob }`: `rev` 0 = aún no hay copia; `next` es la revisión que tendrá la próxima.
    public func getSync(token: String, writeKey: String) async throws -> CloudResponse {
        try await call("/sync", token: token, writeKey: writeKey)
    }

    /// Sube una copia. 409 = `conflict` (otro dispositivo subió primero); 403 `wk` = la llave de escritura no es la de la cuenta.
    public func putSync(base: Int, next: Int?, blob: String, device: String, demo: Bool = false, token: String, writeKey: String) async throws -> CloudResponse {
        var body: [String: JSONValue] = ["base": .number(Double(base)), "blob": .string(blob), "v": .number(2), "dev": .string(device), "demo": .bool(demo)]
        if let next { body["next"] = .number(Double(next)) }
        return try await call("/sync", method: "PUT", body: .object(body), token: token, writeKey: writeKey)
    }

    public func deleteSync(token: String, writeKey: String) async throws -> CloudResponse {
        try await call("/sync", method: "DELETE", token: token, writeKey: writeKey)
    }

    // MARK: lista de espera y cuenta

    /// Lista de espera (sin sesión). `website` vacío es el señuelo anti-robots que espera el servidor.
    public func waitlist(email: String, lang: String, platform: String) async throws -> CloudResponse {
        try await call("/waitlist", method: "POST", body: .object(["email": .string(email), "src": .string("app"), "lang": .string(lang), "plat": .string(platform), "website": .string("")]))
    }

    /// Manda un código por correo para una acción delicada: `kind` nil = reemplazar la copia; "delete" = borrar la cuenta.
    public func syncConfirm(kind: String? = nil, lang: String, token: String, writeKey: String?) async throws -> CloudResponse {
        var b: [String: JSONValue] = ["lang": .string(lang)]
        if let kind { b["kind"] = .string(kind) }
        return try await call("/sync/confirm", method: "POST", body: .object(b), token: token, writeKey: writeKey)
    }

    /// Comprueba el código antes de reemplazar la copia.
    public func syncCheck(code: String, token: String, writeKey: String?) async throws -> CloudResponse {
        try await call("/sync/check", method: "POST", body: .object(["code": .string(code)]), token: token, writeKey: writeKey)
    }

    /// Reemplaza la copia de la nube por completo (`replace`), con el código recibido por correo.
    public func replaceSync(base: Int, next: Int, blob: String, device: String, code: String?, token: String, writeKey: String) async throws -> CloudResponse {
        var b: [String: JSONValue] = ["base": .number(Double(base)), "next": .number(Double(next)), "blob": .string(blob), "v": .number(2), "dev": .string(device), "demo": .bool(false), "replace": .bool(true)]
        if let code { b["code"] = .string(code) }
        return try await call("/sync", method: "PUT", body: .object(b), token: token, writeKey: writeKey)
    }

    /// Cierra las demás sesiones; devuelve un `token` nuevo para este dispositivo.
    public func logoutAll(device: String, token: String, writeKey: String?) async throws -> CloudResponse {
        try await call("/auth/logout-all", method: "POST", body: .object(["dev": .string(device)]), token: token, writeKey: writeKey)
    }

    public func deleteAccount(code: String, token: String, writeKey: String?) async throws -> CloudResponse {
        try await call("/account", method: "DELETE", body: .object(["code": .string(code)]), token: token, writeKey: writeKey)
    }

    // MARK: aprobar dispositivos

    /// El dispositivo NUEVO pide entrar. `st` posibles al sondear: p (pendiente) · c (comprometido) · n (aleatorio del nuevo enviado) · r (código listo) · a (aprobado) · d (rechazado) · x (nadie puede aprobar).
    public func linkStart(email: String, pub: String, rid: String, platform: String, tz: String, lang: String) async throws -> CloudResponse {
        try await call("/link/start", method: "POST", body: .object(["email": .string(email), "pub": .string(pub), "rid": .string(rid), "plat": .string(platform), "tz": .string(tz), "lang": .string(lang)]))
    }

    public func linkPoll(email: String, rid: String, nonce: String? = nil) async throws -> CloudResponse {
        var b: [String: JSONValue] = ["email": .string(email), "rid": .string(rid)]
        if let nonce { b["step"] = .string("nonce"); b["nn"] = .string(nonce) }
        return try await call("/link/poll", method: "POST", body: .object(b))
    }

    /// El dispositivo ACTIVO: ¿hay alguien pidiendo entrar?
    public func linkPending(token: String, writeKey: String?) async throws -> CloudResponse {
        try await call("/link/pending", token: token, writeKey: writeKey)
    }

    /// El dispositivo ACTIVO responde: `commit`, `reveal` o `answer`.
    public func linkStep(_ body: [String: JSONValue], token: String, writeKey: String?) async throws -> CloudResponse {
        try await call("/link/step", method: "POST", body: .object(body), token: token, writeKey: writeKey)
    }
}
