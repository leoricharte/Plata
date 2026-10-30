import SwiftUI
import PlataCore

/// Revisión (`revHTML` de la web): lo que Plata ve raro en tus movimientos, con tarjetas que se aceptan o se descartan. Nada cambia sin tu permiso.
struct ReviewView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var notice: String?
    @State private var page: String?
    @State private var editing: ReviewEdit?

    struct ReviewEdit: Identifiable { let tx: JSONValue; var id: String { Engine.identifier(tx["id"]) } }

    private struct Kind { let id: String, name: String, symbol: String, kinds: [String] }
    private static let groups: [Kind] = [
        Kind(id: "transf", name: "Transferencias", symbol: "arrow.left.arrow.right", kinds: ["xfer", "own"]),
        Kind(id: "pago", name: "Pagos", symbol: "creditcard", kinds: ["pay2", "card"]),
        Kind(id: "rec", name: "Recurrentes", symbol: "repeat", kinds: ["rec"]),
        Kind(id: "rep", name: "Repetidos", symbol: "doc.on.doc", kinds: ["dup"]),
        Kind(id: "monto", name: "Montos", symbol: "exclamationmark.circle", kinds: ["big"]),
        Kind(id: "falta", name: "Estados", symbol: "tray.full", kinds: ["gap"])]

    private static let one: [String: String] = [
        "xfer": "Sale de una cuenta y entra en otra.", "own": "Va a una cuenta tuya fuera de Plata.", "pay2": "Es el mismo pago, no lo cuentes doble.",
        "card": "Coincide con el pago de una tarjeta.", "dup": "Lo anotaste y también vino del banco.", "big": "Mucho más alto de lo normal.",
        "gap": "Puede faltar un estado.", "rec_job": "Ingreso que se repite.", "rec_sub": "Cobro que se repite.", "rec_fix": "Gasto que se repite."]
    private static let button: [String: String] = [
        "xfer": "Es transferencia", "own": "Es transferencia", "pay2": "Juntar como un pago", "card": "Registrar como pago", "dup": "Borrar el mío",
        "big": "Editar", "gap": "Importar un estado", "rec_job": "Crear trabajo", "rec_sub": "Crear suscripción", "rec_fix": "Crear gasto fijo"]
    private static let title: [String: String] = [
        "xfer": "Transferencia entre tus cuentas", "pay2": "Pago de tarjeta", "card": "Pago de tarjeta", "dup": "Movimiento repetido", "big": "Monto muy alto",
        "gap": "Estado faltante", "rec_job": "Trabajo", "rec_sub": "Suscripción", "rec_fix": "Gasto fijo"]
    private static let why: [String: String] = [
        "xfer": "Salió de una cuenta y entró a otra por casi el mismo monto. Como transferencia no cuenta como gasto ni ingreso.",
        "pay2": "Una tarjeta recibió un pago y una cuenta tuvo un gasto parecido: es el mismo pago. Júntalos para que no cuente doble.",
        "card": "Este gasto coincide con la cuota o el saldo de una de tus tarjetas.",
        "dup": "Uno lo anotaste a mano y el otro vino del banco, con el mismo monto y casi el mismo día. Borra el que anotaste a mano.",
        "big": "Es mucho más que lo habitual en esta categoría. ¿Lo escribiste bien?",
        "own": "Van o vienen de otra cuenta tuya que no está en Plata. Marcados como transferencia, dejan de contar como gasto o ingreso.",
        "rec_job": "Llega de la misma fuente, con ritmo regular y monto parecido. Como trabajo, Plata prevé tu próximo pago.",
        "rec_sub": "Se cobra con el mismo ritmo y monto, sumando todas tus cuentas. Como suscripción, Plata la prevé cada mes.",
        "rec_fix": "Se repite con ritmo regular. Como gasto fijo, Plata lo prevé cada vez.",
        "gap": "Puede faltar un estado, o la cuenta ya tenía saldo antes del primero que importaste."]
    private static let cadence = ["w": "cada semana", "b": "cada 2 semanas", "m": "cada mes", "q": "cada quincena"]

    @State private var fitH: CGFloat = 0
    @State private var detent: PresentationDetent = .large
    @State private var fitted = false
    @State private var cw: CGFloat = UIScreen.main.bounds.width

    var body: some View {
        let cards = model.reviewCards
        let consts = model.pendingConstancias
        let tabs = Self.groups.filter { g in cards.contains { g.kinds.contains($0.kind) } }
            + (consts.isEmpty ? [] : [Kind(id: "const", name: "Constancias", symbol: "doc.text.viewfinder", kinds: [])])
        let sel = tabs.first { $0.id == model.reviewTab } ?? tabs.first
        let list = sel.map { g in cards.filter { g.kinds.contains($0.kind) } } ?? []
        let likely = cards.filter { $0.kind == "xfer" && $0.hi }
        ScrollView {
            VStack(spacing: 0) {
                SheetHead(title: "Revisión", onClose: { dismiss() }).padding(.horizontal, 16)
                Text("Nada cambia hasta que aceptes.").font(.inter(14)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.bottom, 12)
                if model.reviewUndoState != nil {
                    HStack(spacing: 10) {
                        Text(notice ?? "Hecho").font(.inter(14.5, .semibold)).frame(maxWidth: .infinity, alignment: .leading)
                        Button("Deshacer") { model.reviewDoUndo(); notice = nil }
                            .font(.inter(15, .semibold)).foregroundStyle(Brand.green)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .plataGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .padding(.horizontal, 16).padding(.bottom, 12)
                }
                if cards.isEmpty && consts.isEmpty {
                    VStack(spacing: 4) {
                        Text("Todo en orden").font(.inter(17, .bold))
                        Text("Plata no encontró movimientos que parezcan mal clasificados.").font(.inter(13.5)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 22).padding(.horizontal, 16)
                    .plataGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .padding(.horizontal, 16).padding(.bottom, 12)
                } else if let sel {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(tabs, id: \.id) { g in tab(g, count: g.id == "const" ? consts.count : cards.filter { g.kinds.contains($0.kind) }.count, on: g.id == sel.id) }
                        }.padding(.horizontal, 16)
                    }
                    .padding(.bottom, 12)
                    if sel.id == "const" {
                        VStack(spacing: 12) { ForEach(consts) { constanciaCard($0) } }.padding(.horizontal, 16)
                    } else {
                    if sel.id == "transf" && likely.count >= 3 {
                        Button { notice = Tr.t("Transferencia registrada"); model.reviewAcceptAllLikely() } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark")
                                Text("Convertir") + Text(" \(likely.count) ") + Text("casi seguras")
                            }
                            .font(.inter(15, .semibold)).foregroundStyle(Brand.gainText)
                            .frame(maxWidth: .infinity).frame(height: 44)
                            .background(Brand.gainBg, in: Capsule())
                        }
                        .buttonStyle(.plain).padding(.horizontal, 16).padding(.bottom, 12)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: 12) {
                            ForEach(list, id: \.k) { r in
                                cardView(r).frame(width: max(240, cw - 32))
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .contentMargins(.horizontal, 16, for: .scrollContent)
                    .scrollClipDisabled()
                    .scrollTargetBehavior(.viewAligned)
                    .scrollPosition(id: $page)
                    if list.count > 1 {
                        Group {
                            if list.count <= 7 {
                                HStack(spacing: 6) {
                                    ForEach(list, id: \.k) { r in
                                        Circle().fill((page ?? list[0].k) == r.k ? Color.primary : Color(.tertiaryLabel)).frame(width: 7, height: 7)
                                    }
                                }
                            } else {
                                Text("Desliza") + Text(" · \(list.count)")
                            }
                        }
                        .font(.inter(13)).foregroundStyle(.secondary).padding(.top, 12)
                    }
                    }
                }
                if model.reviewOffCount > 0 {
                    Button("Mostrar las descartadas") { model.reviewResetDismissed() }
                        .font(.inter(16)).foregroundStyle(Brand.green).frame(maxWidth: .infinity).frame(height: 48).padding(.top, 8)
                }
            }
            .padding(.top, 16).padding(.bottom, 12)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { cw = $0 }
        }
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentSize.height } action: { _, h in fitH = h }
        .presentationDetents(fitH > 0 && fitH + 40 < UIScreen.main.bounds.height * 0.8 ? [.height(fitH + 40), .large] : [.large], selection: $detent)
        .onChange(of: fitH) { _, h in
            // Al abrir el popup ya está en .large: hay que mover la selección al detent ajustado.
            let ok = h > 0 && h + 40 < UIScreen.main.bounds.height * 0.8
            if ok { if detent != .large || !fitted { detent = .height(h + 40); fitted = true } }
            else { detent = .large }
        }
        .presentationDragIndicator(.visible).presentationCornerRadius(38)
        .presentationBackground(Brand.sheetBg)
        .sheet(item: $editing) { w in TransactionSheet(mode: .edit(w.tx)) }
        .onChange(of: model.reviewTab) { page = nil }
    }

    private func tab(_ g: Kind, count: Int, on: Bool) -> some View {
        Button { model.reviewTab = g.id } label: {
            HStack(spacing: 6) {
                Image(systemName: g.symbol).font(.system(size: 14, weight: .semibold))
                Text(g.name).font(.inter(15, .medium))
                Text(String(count)).font(.inter(13, .bold)).opacity(0.7)
            }
            .foregroundStyle(on ? Color.white : Color.primary)
            .padding(.horizontal, 14).frame(height: 38)
            .background(on ? Brand.ink : Brand.glassFill, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: tarjeta

    private func cardView(_ r: ReviewCard) -> some View {
        let e = model.engine, f = model.fmt
        let byId = Dictionary(e.allTransactions.map { (Engine.identifier($0["id"]), $0) }, uniquingKeysWith: { a, _ in a })
        let txs = r.txIds.compactMap { byId[$0] }
        let key = r.kindKey
        let cur = txs.first.map { e.accountCurrency($0["acc"]) } ?? e.primaryCurrency
        return VStack(alignment: .leading, spacing: 0) {
            titleRow(r, txs, key)
            Text(Self.one[key] ?? "").font(.inter(14.5)).foregroundStyle(.secondary).padding(.top, 4)
            meta(r, e, f, cur, txs)
            VStack(spacing: 0) { rows(r, txs, e, f) }.padding(.top, 6)
            DisclosureGroup {
                Text(Self.why[key] ?? "").font(.inter(14)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6)
            } label: {
                HStack(spacing: 6) { Image(systemName: "questionmark.circle"); Text("¿Por qué?") }.font(.inter(15, .medium)).foregroundStyle(.secondary)
            }
            .padding(.top, 10).tint(.secondary)
            Button { accept(r, byId) } label: {
                Text(Self.button[key] ?? "Aceptar").font(.inter(17, .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(Brand.ink, in: Capsule())
            }
            .buttonStyle(.plain).padding(.top, 20)
            Button { model.reviewDismiss(r); notice = nil } label: {
                Text("No es").font(.inter(16)).foregroundStyle(Brand.green).frame(maxWidth: .infinity).frame(height: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(22)
        .frame(alignment: .top)
        .plataGlass(in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    /// Una constancia de Yape/Plin compartida, esperando que la revises (no es un movimiento hasta que la importes).
    private func constanciaCard(_ c: ConstanciaInbox.Entry) -> some View {
        let f = model.fmt
        let brand = c.brand.lowercased()
        let date = LocalDate(iso: c.date).map { Spanish.dateShort($0) } ?? c.date
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Group {
                    if BankMarks.all[brand] != nil { BankMarkView(id: brand, size: 30).foregroundStyle(Color(red: 0.133, green: 0.710, blue: 0.451)) }
                    else { Image(systemName: "doc.text").font(.system(size: 26)) }
                }.frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(verbatim: c.brand.capitalized).font(.inter(18, .bold)).tracking(-0.4)
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 16)).foregroundStyle(Brand.accent)
                            .accessibilityLabel(Tr.t(c.brand.capitalized + " verificado"))
                    }
                    Text(verbatim: c.name.isEmpty ? c.desc : c.name).font(.inter(14.5)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text((c.amount < 0 ? "−" : "+") + f.exact(abs(c.amount), c.cur)).font(.inter(16, .semibold)).monospacedDigit()
                    Text(verbatim: date).font(.inter(12.5)).foregroundStyle(.secondary)
                }
            }
            Text("Constancia compartida. Revísala para elegir la cuenta y añadirla como movimiento.").font(.inter(13.5)).foregroundStyle(.secondary).padding(.top, 10)
            Button {
                let id = c.id
                dismiss()
                Task { try? await Task.sleep(for: .milliseconds(400)); model.reviewConstancias([id]) }
            } label: {
                Text("Revisar").font(.inter(17, .semibold)).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 50).background(Brand.ink, in: Capsule())
            }
            .buttonStyle(.plain).padding(.top, 14)
            Button { model.discardConstancia(c.id) } label: {
                Text("Descartar").font(.inter(16)).foregroundStyle(Brand.green).frame(maxWidth: .infinity).frame(height: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .plataGlass(in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func accept(_ r: ReviewCard, _ byId: [String: JSONValue]) {
        switch r.kind {
        case "big": if let id = r.txIds.first, let tx = byId[id] { editing = ReviewEdit(tx: tx) }
        case "gap":
            dismiss()
            Task { try? await Task.sleep(for: .milliseconds(400)); model.showImport = true }
        default: notice = model.reviewAccept(r).map { Tr.t($0) }
        }
    }

    private func titleRow(_ r: ReviewCard, _ txs: [JSONValue], _ key: String) -> some View {
        HStack(spacing: 8) {
            if r.kind == "rec" {
                if r.brand != nil, let note = txs.first.map({ Engine.text($0["note"]) }) { SubTile(name: note, fallback: .gray, size: 24) }
                Text(verbatim: r.name ?? "").font(.inter(18, .bold)).tracking(-0.4).lineLimit(1)
                Text(Self.title[key] ?? "").font(.inter(12, .bold)).foregroundStyle(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 3).background(Color(.tertiarySystemFill), in: Capsule())
            } else if r.kind == "own" {
                Text(verbatim: r.label ?? "").font(.inter(18, .bold)).tracking(-0.4)
            } else {
                Text(Self.title[r.kind] ?? "").font(.inter(18, .bold)).tracking(-0.4)
            }
            if r.hi { badge("casi seguro", Brand.gainText, Brand.gainBg) }
            else if r.far { badge("revisa las fechas", Brand.warnText, Brand.warn.opacity(0.16)) }
        }
    }

    private func badge(_ text: String, _ fg: Color, _ bg: Color) -> some View {
        Text(text).font(.inter(12, .bold)).foregroundStyle(fg).padding(.horizontal, 8).padding(.vertical, 3).background(bg, in: Capsule())
    }

    @ViewBuilder
    private func meta(_ r: ReviewCard, _ e: Engine, _ f: Fmt, _ cur: String, _ txs: [JSONValue]) -> some View {
        switch r.kind {
        case "own":
            let ds = txs.map { Engine.text($0["date"]) }.sorted()
            VStack(alignment: .leading, spacing: 2) {
                Text("\(txs.count) ") + Text("movimientos") + Text(" · \(String((ds.first ?? "").prefix(7))) → \(String((ds.last ?? "").prefix(7)))")
                if let out = r.out, let inn = r.inn, let c = r.cur, !c.isEmpty {
                    Text("Salidas") + Text(" \(f.exact(out, c)) · ") + Text("Entradas") + Text(" \(f.exact(inn, c))")
                }
            }.font(.inter(14)).foregroundStyle(.secondary).padding(.top, 8)
        case "rec":
            let amt = f.exact(r.amt ?? 0, r.cur ?? cur)
            (Text((r.fixed ?? false) ? "" : Tr.t("aprox.") + " ") + Text(amt) + Text(" ") + Text(Self.cadence[r.cad ?? "m"] ?? "") + Text(" · \(txs.count) ") + Text("veces"))
                .font(.inter(14)).foregroundStyle(.secondary).padding(.top, 8)
        case "gap":
            let a = r.acc.flatMap { id in (e.allAccounts).first { Engine.identifier($0["id"]) == id } }
            VStack(alignment: .leading, spacing: 2) {
                if let a {
                    let l4 = Engine.text(a["last4"])
                    Text(verbatim: Engine.text(a["name"]) + (l4.isEmpty ? "" : " · ● " + l4)).fontWeight(.bold).foregroundStyle(.primary)
                    if let miss = r.miss, !miss.isEmpty { Text("Sin movimientos:") + Text(verbatim: " " + miss.joined(separator: " · ")) }
                    if let d = r.diff, d != 0 { Text("Diferencia de saldo:") + Text(" " + f.exact(abs(d), Engine.text(a["cur"]))) }
                }
            }.font(.inter(14)).foregroundStyle(.secondary).padding(.top, 8)
        case "big":
            (Text("Lo normal:") + Text(" " + f.exact(r.med ?? 0, cur))).font(.inter(14)).foregroundStyle(.secondary).padding(.top, 8)
        default: EmptyView()
        }
    }

    @ViewBuilder
    private func rows(_ r: ReviewCard, _ txs: [JSONValue], _ e: Engine, _ f: Fmt) -> some View {
        switch r.kind {
        case "xfer": if txs.count == 2 { row(txs[0], "Sale", e, f); row(txs[1], "Entra", e, f) }
        case "pay2": if txs.count == 2 { row(txs[0], "Se corregirá", e, f); row(txs[1], "Se vinculará", e, f) }
        case "dup": if txs.count == 2 { row(txs[0], "Anotado a mano", e, f); row(txs[1], "Del banco", e, f) }
        case "own":
            let s = txs.sorted { Engine.text($0["date"]) > Engine.text($1["date"]) }
            ForEach(Array(s.prefix(2).enumerated()), id: \.offset) { _, t in row(t, "Transferencia", e, f) }
            more(Array(s.dropFirst(2)), "Transferencia", e, f)
        case "rec":
            let s = txs.sorted { Engine.text($0["date"]) > Engine.text($1["date"]) }
            let label = (r.neg ?? true) ? "Cargo" : "Ingreso"
            ForEach(Array(s.prefix(2).enumerated()), id: \.offset) { _, t in row(t, label, e, f) }
            more(Array(s.dropFirst(2)), label, e, f)
        case "gap": EmptyView()
        default: if let t = txs.first { row(t, r.kind == "big" ? "Lo editas tú" : "Se reemplazará", e, f) }
        }
    }

    @ViewBuilder
    private func more(_ rest: [JSONValue], _ label: String, _ e: Engine, _ f: Fmt) -> some View {
        if !rest.isEmpty {
            DisclosureGroup {
                ForEach(Array(rest.prefix(10).enumerated()), id: \.offset) { _, t in row(t, label, e, f) }
                if rest.count > 10 { Text("…").foregroundStyle(.secondary) }
            } label: {
                (Text("y") + Text(" \(rest.count) ") + Text("más")).font(.inter(15, .medium)).foregroundStyle(.secondary)
            }
            .tint(.secondary).padding(.top, 6)
        }
    }

    /// Una fila de movimiento (`smRow` de la web): nota, categoría · fecha, cuenta, monto y la etiqueta ámbar.
    private func row(_ t: JSONValue, _ label: String, _ e: Engine, _ f: Fmt) -> some View {
        let cur = e.accountCurrency(t["acc"])
        let note = Engine.text(t["note"]), cat = Engine.text(t["category"])
        let a = Engine.number(t["amount"])
        let date = LocalDate(iso: Engine.text(t["date"])).map { Spanish.dateShort($0) } ?? ""
        return VStack(spacing: 0) {
            Divider().overlay(Color(.separator).opacity(0.5))
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: note.isEmpty ? cat : note).font(.inter(15, .semibold)).lineLimit(1)
                    Text(verbatim: Tr.t(cat) + " · " + date).font(.inter(12.5)).foregroundStyle(.secondary).lineLimit(1)
                    Text(verbatim: e.accountName(t["acc"] ?? .null)).font(.inter(12.5)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 1) {
                    Text((a < 0 ? "−" : "+") + f.exact(abs(a), cur)).font(.inter(15, .semibold)).monospacedDigit()
                    Text(label).font(.inter(12.5, .bold)).foregroundStyle(Brand.warn)
                }
            }
            .padding(.vertical, 10)
        }
    }
}
