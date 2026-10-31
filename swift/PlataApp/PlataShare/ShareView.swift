import SwiftUI
import PlataCore

/// La tarjeta de la extensión: leyendo → (confirmar) → guardada. Sin dependencias de la app: solo colores del sistema y el verde de Plata.
struct ShareView: View {
    let model: ShareModel
    private let green = ShareTheme.green

    var body: some View {
        ZStack {
            ShareTheme.scrim.opacity(0.52).ignoresSafeArea().onTapGesture { if case .ready = model.phase { model.cancel() } }
            card.frame(maxWidth: 360).padding(24)
        }
        .task { await model.start() }
    }

    @ViewBuilder private var card: some View {
        VStack(spacing: 14) {
            switch model.phase {
            case .reading: reading
            case .choose(let k): choose(k)
            case .handedOff: handedOff
            case .ready(let r): ready(r)
            case .saved(let r): saved(r)
            case .failed: failed
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(LinearGradient(colors: [ShareTheme.cardTop, ShareTheme.cardBottom], startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(ShareTheme.rowStroke.opacity(0.7), lineWidth: 1))
        .shadow(color: ShareTheme.scrim.opacity(0.35), radius: 28, y: 14)
        .foregroundStyle(ShareTheme.text)
        .tint(green)
    }

    private func option(_ icon: String, _ title: String, _ sub: String, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.system(size: 19, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(LinearGradient(colors: [ShareTheme.green, ShareTheme.greenDeep], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: Tr.t(title)).font(.system(size: 17, weight: .semibold)).foregroundStyle(ShareTheme.text)
                    Text(verbatim: Tr.t(sub)).font(.system(size: 13)).foregroundStyle(ShareTheme.sub).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(ShareTheme.greenText.opacity(0.7))
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(ShareTheme.rowFill.opacity(0.85), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(ShareTheme.rowStroke.opacity(0.8), lineWidth: 1))
        }
        .buttonStyle(ShareRowStyle())
    }

    /// El rótulo de la marca arriba de cada tarjeta.
    private var brand: some View {
        Text(verbatim: "PLATA").font(.system(size: 12, weight: .heavy)).tracking(3).foregroundStyle(ShareTheme.greenText)
    }

    private func choose(_ kind: ShareModel.Kind) -> some View {
        VStack(spacing: 12) {
            brand
            Text(verbatim: Tr.t(kind == .image ? "¿Qué es esta captura?" : "¿Qué hacemos con este archivo?")).font(.system(size: 19, weight: .bold))
            if kind == .image {
                option("checkmark.seal", "Constancia de Yape o Plin", "Un pago o ingreso suelto") { Task { await model.readAsConstancia() } }
                option("viewfinder", "Sesión de reconocimiento", "Nazca lee la lista de movimientos") { Task { await model.handOff(.recognition) } }
            } else {
                option("square.and.arrow.down", "Importar archivo", "Plata reconoce el banco sola") { Task { await model.handOff(.file) } }
                option("building.columns", "Elegir banco", "Tú dices de cuál es") { Task { await model.handOff(.banks) } }
            }
            Button { model.cancel() } label: { Text(verbatim: Tr.t("Cancelar")).font(.system(size: 16, weight: .medium)).foregroundStyle(ShareTheme.greenText).frame(maxWidth: .infinity, minHeight: 40) }
        }
    }

    private var handedOff: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 44)).foregroundStyle(green)
            Text(verbatim: Tr.t("Listo")).font(.system(size: 19, weight: .bold))
            Text(verbatim: Tr.t("Abre Plata para seguir. Te estará esperando.")).font(.system(size: 14)).foregroundStyle(ShareTheme.sub).multilineTextAlignment(.center)
        }
        .padding(.vertical, 6)
    }

    private var reading: some View {
        VStack(spacing: 12) {
            ProgressView().tint(green)
            Text(verbatim: Tr.t("Leyendo…")).font(.system(size: 16)).foregroundStyle(ShareTheme.sub)
        }
        .padding(.vertical, 8)
    }

    private func ready(_ r: NazcaConstancia.Result) -> some View {
        VStack(spacing: 14) {
            summary(r)
            ForEach(Self.notes(r.flags), id: \.self) { n in
                Label { Text(verbatim: Tr.t(n)).font(.system(size: 14)) } icon: { Image(systemName: "exclamationmark.circle") }
                    .foregroundStyle(.orange).frame(maxWidth: .infinity, alignment: .leading)
            }
            Button { model.save(r) } label: {
                Text(verbatim: Tr.t("Añadir a Plata")).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 50).background(LinearGradient(colors: [ShareTheme.green, ShareTheme.greenDeep], startPoint: .top, endPoint: .bottom), in: Capsule())
            }
            Button { model.cancel() } label: { Text(verbatim: Tr.t("Cancelar")).font(.system(size: 16, weight: .medium)).foregroundStyle(ShareTheme.greenText) }
        }
    }

    private func saved(_ r: NazcaConstancia.Result) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 44)).foregroundStyle(green)
            summary(r)
            Text(verbatim: Tr.t("Guardada. Queda en Revisión para que la confirmes.")).font(.system(size: 14)).foregroundStyle(ShareTheme.sub).multilineTextAlignment(.center)
        }
    }

    private var failed: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.circle").font(.system(size: 40)).foregroundStyle(ShareTheme.sub)
            Text(verbatim: Tr.t("No pude leer esta constancia")).font(.system(size: 17, weight: .semibold))
            Text(verbatim: Tr.t("No encontré un monto en la captura. Prueba con la captura completa de la constancia, o añádela desde Plata: Importar.")).font(.system(size: 14)).foregroundStyle(ShareTheme.sub).multilineTextAlignment(.center)
            Button { model.cancel() } label: {
                Text(verbatim: Tr.t("Cerrar")).font(.system(size: 17, weight: .semibold)).frame(maxWidth: .infinity).frame(height: 50)
                    .background(ShareTheme.green.opacity(0.16), in: Capsule())
            }
            .foregroundStyle(ShareTheme.greenText)
        }
    }

    private func summary(_ r: NazcaConstancia.Result) -> some View {
        let it = r.statement.items[0]
        return VStack(spacing: 4) {
            Text(verbatim: Tr.t(r.statement.label)).font(.system(size: 13, weight: .semibold)).foregroundStyle(ShareTheme.sub)
            Text(verbatim: (it.amount < 0 ? "−" : "+") + Self.money(abs(it.amount), it.cur)).font(.system(size: 34, weight: .bold)).monospacedDigit()
            Text(verbatim: it.desc).font(.system(size: 16)).multilineTextAlignment(.center)
            Text(verbatim: it.date).font(.system(size: 14)).foregroundStyle(ShareTheme.sub).monospacedDigit()
        }
    }

    static func money(_ v: Double, _ cur: String) -> String {
        (cur == "USD" ? "US$ " : "S/ ") + String(format: "%.2f", v)
    }

    /// Lo que no se pudo leer con seguridad, en palabras.
    static func notes(_ flags: [String]) -> [String] {
        flags.compactMap {
            switch $0 {
            case "date": return "No encontré la fecha: puse la de hoy. Revísala."
            case "direction": return "No sé si fue un pago o un ingreso. Revísalo."
            case "amount": return "Había más de un monto: revisa que este sea el correcto."
            case "who": return "No encontré el nombre."
            default: return nil
            }
        }
    }
}
