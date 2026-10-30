import SwiftUI
import PlataCore

/// La tarjeta de la extensión: leyendo → (confirmar) → guardada. Sin dependencias de la app: solo colores del sistema y el verde de Plata.
struct ShareView: View {
    let model: ShareModel
    private let green = Color(red: 0.133, green: 0.710, blue: 0.451)

    var body: some View {
        ZStack {
            Color.black.opacity(0.28).ignoresSafeArea().onTapGesture { if case .ready = model.phase { model.cancel() } }
            card.frame(maxWidth: 360).padding(24)
        }
        .task { await model.start() }
    }

    @ViewBuilder private var card: some View {
        VStack(spacing: 14) {
            switch model.phase {
            case .reading: reading
            case .ready(let r): ready(r)
            case .saved(let r): saved(r)
            case .failed: failed
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var reading: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(verbatim: Tr.t("Leyendo la constancia…")).font(.system(size: 16)).foregroundStyle(.secondary)
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
                    .frame(maxWidth: .infinity).frame(height: 50).background(green, in: Capsule())
            }
            Button { model.cancel() } label: { Text(verbatim: Tr.t("Cancelar")).font(.system(size: 16)).foregroundStyle(.secondary) }
        }
    }

    private func saved(_ r: NazcaConstancia.Result) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 44)).foregroundStyle(green)
            summary(r)
            Text(verbatim: Tr.t("Guardada. Plata la añade al abrirse.")).font(.system(size: 14)).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
    }

    private var failed: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.circle").font(.system(size: 40)).foregroundStyle(.secondary)
            Text(verbatim: Tr.t("No pude leer esta constancia")).font(.system(size: 17, weight: .semibold))
            Text(verbatim: Tr.t("Copia el texto y pégalo en Plata: Importar → Pegar constancia.")).font(.system(size: 14)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button { model.cancel() } label: {
                Text(verbatim: Tr.t("Cerrar")).font(.system(size: 17, weight: .semibold)).frame(maxWidth: .infinity).frame(height: 50)
                    .background(Color.primary.opacity(0.08), in: Capsule())
            }
            .foregroundStyle(.primary)
        }
    }

    private func summary(_ r: NazcaConstancia.Result) -> some View {
        let it = r.statement.items[0]
        return VStack(spacing: 4) {
            Text(verbatim: Tr.t(r.statement.label)).font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
            Text(verbatim: (it.amount < 0 ? "−" : "+") + Self.money(abs(it.amount), it.cur)).font(.system(size: 34, weight: .bold)).monospacedDigit()
            Text(verbatim: it.desc).font(.system(size: 16)).multilineTextAlignment(.center)
            Text(verbatim: it.date).font(.system(size: 14)).foregroundStyle(.secondary).monospacedDigit()
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
