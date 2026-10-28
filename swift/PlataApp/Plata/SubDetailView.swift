import SwiftUI
import PlataCore

/// El detalle de un servicio o suscripción (`renderItem` de la web, `kind === 'sub'`): datos, «Adelantar cobro» e historial.
struct SubDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let id: String
    @State private var askDelete = false
    @State private var errorText: String?

    var body: some View {
        let e = model.engine
        if let o = e.subscriptionList.first(where: { Engine.identifier($0["id"]) == id }) {
            content(o, e)
        } else {
            Color.clear.onAppear { dismiss() }
        }
    }

    private func content(_ o: JSONValue, _ e: Engine) -> some View {
        let f = model.fmt
        let cur = Engine.text(o["cur"]), name = Engine.text(o["name"])
        let amount = Engine.number(o["amount"])
        let accId = Engine.text(o["acc"])
        let owner = accId.isEmpty ? nil : (e.allAccounts + e.allCards).first { Engine.text($0["id"]) == accId }
        let idx = e.subscriptionList.firstIndex { Engine.identifier($0["id"]) == id } ?? 0
        let fallback = Color(hex: Engine.cardColorsForApp[idx % max(1, Engine.cardColorsForApp.count)])
        let hist = SubHistory.build(sub: o, engine: e, fmt: f)
        return ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    SubTile(name: name, fallback: fallback, size: 64).padding(.top, 4)
                    Text(name).font(.inter(28, .bold, relativeTo: .title)).tracking(-0.8).multilineTextAlignment(.center).padding(.top, 10)
                    Text("Servicio o suscripción").font(.inter(15)).foregroundStyle(.secondary).padding(.top, 2)
                    Text(f.exact(amount, cur)).font(.inter(40, .bold, relativeTo: .largeTitle)).tracking(-1.4).monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.6).padding(.top, 12)
                }
                .padding(.bottom, 16)

                box {
                    pair(("Día de cobro", "Día \(Int(Engine.number(o["day"])))"), ("Frecuencia", "Cada mes"))
                    if let owner { pair(("Se cobra de", Engine.text(owner["name"])), nil, top: 14) }
                    pair(("Por año", f.exact(Engine.roundCents(amount * 12), cur)),
                         cur != e.primaryCurrency ? ("Equivale a", "≈ " + f.exact(e.usd(amount, cur), e.primaryCurrency)) : nil, top: 14)
                }

                Button { advance() } label: {
                    Text("Adelantar cobro").font(.inter(17, .semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(Brand.green, in: Capsule())
                }
                .buttonStyle(.plain).padding(.bottom, 12)

                SectionHead("Historial")
                box {
                    if let hist {
                        HStack(alignment: .top, spacing: 20) {
                            miniStat("Desde", hist.since)
                            miniStat("Cobros", String(hist.charges))
                            miniStat("Quiebres", String(hist.breaks))
                        }
                        .padding(.bottom, hist.events.isEmpty ? 0 : 14)
                        ForEach(Array(hist.events.enumerated()), id: \.element.id) { i, ev in
                            eventRow(ev, last: i == hist.events.count - 1)
                        }
                    } else {
                        Text("Aún no hay cobros de esta suscripción en tus movimientos.")
                            .font(.inter(15)).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                }

                if let errorText { Text(errorText).font(.inter(14)).foregroundStyle(Brand.lossText).padding(.bottom, 10) }
                Button("Editar") { model.activeSheet = .sub(id: id) }.buttonStyle(SecondaryPillStyle()).padding(.bottom, 8)
                Button("Eliminar") { askDelete = true }.buttonStyle(SecondaryPillStyle(destructive: true)).padding(.bottom, 8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { model.activeSheet = .sub(id: id) } label: { Image(systemName: "pencil") }.accessibilityLabel("Editar")
            }
        }
        .confirmationDialog("¿Eliminar esto?", isPresented: $askDelete, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) { try? model.deleteSub(id: o["id"] ?? .null); dismiss() }
            Button("Cancelar", role: .cancel) {}
        } message: { Text("Dejará de aparecer en tus pagos futuros. Tu historial no cambia.") }
    }

    private func advance() {
        do { try model.advanceSubscription(id: id); errorText = nil }
        catch { errorText = Tr.t("No se pudo adelantar el cobro.") }
    }

    private func box<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .padding(.bottom, 14)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.inter(15)).foregroundStyle(.secondary)
            Text(value).font(.inter(20, .bold)).tracking(-0.4).lineLimit(2).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func miniStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.inter(13)).foregroundStyle(.secondary)
            Text(value).font(.inter(17, .bold)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pair(_ a: (String, String), _ b: (String, String)?, top: CGFloat = 0) -> some View {
        HStack(alignment: .top, spacing: 20) {
            stat(a.0, a.1)
            if let b { stat(b.0, b.1) } else { Spacer(minLength: 0).frame(maxWidth: .infinity) }
        }
        .padding(.top, top)
    }

    /// Un hito de la línea de tiempo: punto de color sobre una línea de 2 pt, como `.tl .dot` de la web.
    private func eventRow(_ ev: SubHistoryEvent, last: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack(alignment: .top) {
                if !last { Rectangle().fill(Color(.separator).opacity(0.6)).frame(width: 2).padding(.top, 6) }
                Circle().fill(Color(hex: ev.color)).frame(width: 12, height: 12)
            }
            .frame(width: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text(ev.title).font(.inter(16, .medium)).fixedSize(horizontal: false, vertical: true)
                Text(ev.detail).font(.inter(13)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, last ? 0 : 16)
        }
    }
}
