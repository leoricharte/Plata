import SwiftUI
import WidgetKit

/// Widgets del iPhone: se arman con las piezas del Bento, se guardan en una galería y desde ahí se añaden a la pantalla de inicio.
struct WidgetsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var bentos: [SavedBento] = BentoStore.load()
    @State private var snap: PhoneSnapshot?
    @State private var builder: SavedBento?
    @State private var building = false
    @State private var removing: SavedBento?

    private struct Template: Identifiable { let id: String; let name: String; let size: BentoSize; let pieces: [BentoPiece] }
    private let templates: [Template] = [
        .init(id: "mes", name: "Mi mes", size: .medium, pieces: [.kpi, .cats]),
        .init(id: "deu", name: "Presupuesto y deuda", size: .medium, pieces: [.budget, .debt]),
        .init(id: "per", name: "Perfil y evaluación", size: .medium, pieces: [.score, .rate]),
        .init(id: "graf", name: "Gráficos", size: .large, pieces: [.cats, .daily, .weekday, .flow]),
        .init(id: "todo", name: "Todo a la vista", size: .large, pieces: [.kpi, .budget, .upcoming, .goals]),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Arma widgets con las piezas del Bento, guárdalos en tu galería y añádelos a tu pantalla de inicio.")
                        .font(.inter(16)).foregroundStyle(.secondary).padding(.top, 4)
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill").foregroundStyle(.secondary)
                        Text("Los widgets podrían volverse una función premium en el futuro.").font(.inter(14)).foregroundStyle(.secondary)
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.top, 12)

                    SectionHead("Mi galería").padding(.top, 24)
                    if bentos.isEmpty {
                        Text("Todavía no guardaste ningún bento. Crea uno o parte de una plantilla.")
                            .font(.inter(15)).foregroundStyle(.secondary).padding(.vertical, 6)
                    }
                    ForEach(bentos) { b in galleryCard(b) }
                    Button { builder = nil; building = true } label: {
                        Label("Crear widget", systemImage: "plus").font(.inter(17, .semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 50).background(Brand.accent, in: Capsule())
                    }
                    .buttonStyle(.plain).padding(.top, 10)

                    SectionHead("Plantillas").padding(.top, 28)
                    ForEach(templates) { t in templateCard(t) }

                    SectionHead("Cómo añadirlo a tu pantalla").padding(.top, 28)
                    VStack(alignment: .leading, spacing: 8) {
                        step(1, "Mantén presionada tu pantalla de inicio y toca «+».")
                        step(2, "Busca Plata y elige «Bento» (o cualquiera de las piezas sueltas).")
                        step(3, "Toca «Añadir widget», luego tócalo y elige el bento de tu galería.")
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 16).padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Widgets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cerrar") { dismiss() } } }
        }
        .task { snap = WidgetBridge.snapshot(model); bentos = BentoStore.load() }
        .fullScreenCover(isPresented: $building, onDismiss: { bentos = BentoStore.load() }) { BentoBuilder(editing: builder, snap: snap) }
        .alert("¿Eliminar este bento?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } })) {
            Button("Eliminar", role: .destructive) { if let r = removing { bentos.removeAll { $0.id == r.id }; BentoStore.save(bentos) }; removing = nil }
            Button("Cancelar", role: .cancel) { removing = nil }
        } message: { Text("Los widgets que lo usan quedarán vacíos hasta que elijas otro.") }
    }

    private func preview(_ pieces: [BentoPiece], _ size: BentoSize) -> some View {
        BentoCanvas(pieces: pieces, snap: snap, family: size.family)
            .padding(14)
            .frame(width: size.width, height: size.height)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .frame(maxWidth: .infinity)
    }

    private func galleryCard(_ b: SavedBento) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(b.name).font(.inter(17, .semibold))
                    Text(b.size.label).font(.inter(13)).foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Button { builder = b; building = true } label: { Label("Editar", systemImage: "pencil") }
                    Button { var c = b; c.id = UUID().uuidString; c.name += " (copia)"; bentos.append(c); BentoStore.save(bentos) } label: { Label("Duplicar", systemImage: "plus.square.on.square") }
                    Button(role: .destructive) { removing = b } label: { Label("Eliminar", systemImage: "trash") }
                } label: { Image(systemName: "ellipsis.circle").font(.system(size: 22)).foregroundStyle(.secondary).frame(width: 44, height: 44) }
            }
            preview(b.pieces, b.size)
        }
        .padding(.top, 10)
    }

    private func templateCard(_ t: Template) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(t.name).font(.inter(17, .semibold))
                    Text(t.size.label).font(.inter(13)).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Añadir a mi galería") {
                    bentos.append(SavedBento(id: UUID().uuidString, name: t.name, size: t.size, pieces: t.pieces)); BentoStore.save(bentos)
                }
                .font(.inter(14, .semibold)).foregroundStyle(Brand.accent)
            }
            preview(t.pieces, t.size).opacity(0.9)
        }
        .padding(.top, 10)
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)").font(.inter(13, .bold)).foregroundStyle(Brand.gainText).frame(width: 22, height: 22).background(Brand.accent.opacity(0.15), in: Circle())
            Text(text).font(.inter(15))
        }
    }
}

/// La pasarela para crear un widget: tamaño → piezas → nombre.
struct BentoBuilder: View {
    @Environment(\.dismiss) private var dismiss
    let editing: SavedBento?
    let snap: PhoneSnapshot?
    @State private var page = 0
    @State private var size: BentoSize = .medium
    @State private var pieces: [BentoPiece] = []
    @State private var name = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { if page > 0 { withAnimation { page -= 1 } } else { dismiss() } } label: {
                    Image(systemName: page > 0 ? "chevron.left" : "xmark").font(.system(size: 18, weight: .semibold)).foregroundStyle(.primary).frame(width: 44, height: 44)
                }
                Spacer()
                HStack(spacing: 6) { ForEach(0..<3, id: \.self) { i in Circle().fill(i == page ? Color.primary : Color.primary.opacity(0.18)).frame(width: 7, height: 7) } }
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    switch page {
                    case 0: sizePage
                    case 1: piecesPage
                    default: namePage
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 20)
            }
            Button(page == 2 ? "Guardar en mi galería" : "Siguiente") { next() }
                .buttonStyle(PrimaryPillStyle()).disabled(!canNext).padding(.horizontal, 20).padding(.bottom, 12)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear {
            if let e = editing { size = e.size; pieces = e.pieces; name = e.name }
        }
    }

    private var canNext: Bool { page == 0 || (page == 1 && !pieces.isEmpty) || (page == 2 && !name.trimmingCharacters(in: .whitespaces).isEmpty) }

    private func next() {
        if page < 2 { withAnimation { page += 1 }; return }
        var list = BentoStore.load()
        let item = SavedBento(id: editing?.id ?? UUID().uuidString, name: name.trimmingCharacters(in: .whitespaces), size: size, pieces: pieces)
        if let i = list.firstIndex(where: { $0.id == item.id }) { list[i] = item } else { list.append(item) }
        BentoStore.save(list)
        dismiss()
    }

    private func canvas() -> some View {
        BentoCanvas(pieces: pieces, snap: snap, family: size.family)
            .padding(14)
            .frame(width: size.width, height: size.height)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .frame(maxWidth: .infinity)
    }

    private var sizePage: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("¿De qué tamaño?").font(.inter(30, .bold)).padding(.top, 8)
            Text("Elige el tamaño del widget. Después eliges las piezas.").font(.inter(16)).foregroundStyle(.secondary)
            ForEach(BentoSize.allCases) { s in
                Button { size = s; pieces = Array(pieces.prefix(s.maxPieces)) } label: {
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 8).stroke(Brand.accent, lineWidth: 2)
                            .frame(width: s == .small ? 34 : 70, height: s == .large ? 70 : 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.label).font(.inter(17, .semibold)).foregroundStyle(.primary)
                            Text(s == .small ? "1 pieza" : "hasta \(s.maxPieces) piezas").font(.inter(13)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: size == s ? "checkmark.circle.fill" : "circle").font(.system(size: 22)).foregroundStyle(size == s ? Brand.accent : Color.secondary.opacity(0.5))
                    }
                    .padding(14).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var piecesPage: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Elige las piezas").font(.inter(30, .bold)).padding(.top, 8)
            Text(size == .small ? "Este tamaño lleva una pieza." : "Hasta \(size.maxPieces) piezas, en el orden en que las toques.").font(.inter(16)).foregroundStyle(.secondary)
            canvas().padding(.vertical, 6)
            ForEach(BentoPiece.allCases) { p in
                let on = pieces.contains(p)
                let full = pieces.count >= size.maxPieces
                Button {
                    if on { pieces.removeAll { $0 == p } }
                    else if size == .small { pieces = [p] }
                    else if !full { pieces.append(p) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: p.symbol).font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                            .frame(width: 40, height: 40).background(Brand.accent, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(p.title).font(.inter(16, .semibold)).foregroundStyle(.primary)
                            Text(p.desc).font(.inter(13)).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                        }
                        Spacer()
                        if on, let i = pieces.firstIndex(of: p), size != .small { Text("\(i + 1)").font(.inter(13, .bold)).foregroundStyle(.white).frame(width: 24, height: 24).background(Brand.accent, in: Circle()) }
                        else { Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.system(size: 22)).foregroundStyle(on ? Brand.accent : Color.secondary.opacity(0.5)) }
                    }
                    .padding(12).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .opacity(!on && full && size != .small ? 0.45 : 1)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var namePage: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ponle nombre").font(.inter(30, .bold)).padding(.top, 8)
            Text("Así lo vas a ver en tu galería y al elegirlo en el widget.").font(.inter(16)).foregroundStyle(.secondary)
            canvas().padding(.vertical, 6)
            TextField("Nombre del bento", text: $name)
                .font(.inter(17)).padding(14)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}
