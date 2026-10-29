import SwiftUI
import PlataCore

/// «Sets de presupuesto»: elegir cuál ver, crear uno nuevo o editar sus fechas (`bsetsHTML` y `bseditHTML` de la web).
struct BudgetSetsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private struct Draft: Equatable {
        var id: String
        var isNew: Bool
        var name = ""
        var from = Date()
        var to = Date()
        var cur = ""
        var sourceName = "Presupuesto base"
        var source: String?
    }

    @State private var draft: Draft?
    @State private var errorText: String?
    @State private var askDelete = false

    var body: some View {
        Group {
            if draft != nil { editor } else { list }
        }
        .presentationDetents([.large]).presentationDragIndicator(.visible).presentationCornerRadius(38)
        .presentationBackground(Color(light: "#F4F4F8", dark: "#1C1C1E"))
    }

    private func iso(_ d: Date) -> String { LocalDate.today(now: d).iso }

    private func range(_ b: JSONValue) -> String {
        guard let a = LocalDate(iso: Engine.text(b["from"])), let z = LocalDate(iso: Engine.text(b["to"])) else { return "" }
        return "Del \(a.day) \(Spanish.monthsShort[a.month0]) al \(z.day) \(Spanish.monthsShort[z.month0]) \(z.year)"
    }

    // MARK: lista

    private var list: some View {
        let e = model.engine
        let act = e.activeSet(), vs = model.viewSet
        let sets = (e.data["budgetSets"]?.arrayValue ?? []).sorted { Engine.text($0["from"]) < Engine.text($1["from"]) }
        return ScrollView {
            VStack(spacing: 0) {
                SheetHead(title: "Sets de presupuesto", onClose: { dismiss() })
                Text("Cada set tiene sus propios límites y se activa solo entre sus fechas. Toca uno para verlo y editar sus límites.")
                    .font(.inter(13)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8).padding(.bottom, 10)
                SCard {
                    row(name: "Presupuesto base", sub: "Se usa cuando no hay otro set activo", isActive: act == nil, isView: vs == nil, id: "base", editable: nil)
                    ForEach(Array(sets.enumerated()), id: \.offset) { _, b in
                        RowDivider()
                        row(name: Engine.text(b["name"]), sub: range(b), isActive: act == b, isView: vs == b, id: Engine.text(b["id"]), editable: b)
                    }
                }
                Button("Nuevo set") { startNew(vs) }.buttonStyle(PrimaryPillStyle()).padding(.top, 4)
            }
            .padding(.horizontal, 16).padding(.top, 16)
        }
    }

    private func row(name: String, sub: String, isActive: Bool, isView: Bool, id: String, editable: JSONValue?) -> some View {
        HStack(spacing: 8) {
            Button {
                model.bsel = id
                dismiss()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(name).font(.inter(16, .semibold)).lineLimit(1)
                        if isActive {
                            Text("Activo").font(.inter(12, .semibold)).foregroundStyle(Brand.gainTextStrong)
                                .padding(.horizontal, 8).padding(.vertical, 3).background(Brand.gainBg, in: Capsule())
                        }
                    }
                    Text(sub).font(.inter(13)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if let editable {
                Button { startEdit(editable) } label: {
                    Image(systemName: "pencil").font(.system(size: 15, weight: .semibold)).foregroundStyle(Brand.green)
                        .frame(width: 34, height: 34).background(Color(.tertiarySystemFill), in: Circle())
                }
                .buttonStyle(.plain).accessibilityLabel("Editar")
            }
            Image(systemName: "checkmark").font(.system(size: 15, weight: .bold)).foregroundStyle(Brand.green)
                .frame(width: 20).opacity(isView ? 1 : 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func startNew(_ vs: JSONValue?) {
        let t = model.today
        draft = Draft(id: String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6)).lowercased(), isNew: true,
                      from: t.date(), to: t.adding(days: 30).date(),
                      sourceName: vs.map { Engine.text($0["name"]) } ?? "Presupuesto base", source: vs.map { Engine.text($0["id"]) })
        errorText = nil
    }

    private func startEdit(_ b: JSONValue) {
        draft = Draft(id: Engine.text(b["id"]), isNew: false, name: Engine.text(b["name"]),
                      from: (LocalDate(iso: Engine.text(b["from"])) ?? model.today).date(),
                      to: (LocalDate(iso: Engine.text(b["to"])) ?? model.today).date(), cur: Engine.text(b["cur"]))
        errorText = nil
    }

    // MARK: edición

    private var editor: some View {
        let d = Binding(get: { draft ?? Draft(id: "", isNew: true) }, set: { draft = $0 })
        return ScrollView {
            VStack(spacing: 0) {
                HStack {
                    Button { draft = nil } label: {
                        Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold)).foregroundStyle(.primary)
                            .frame(width: 44, height: 44).modifier(GlassCircle())
                    }
                    .buttonStyle(.plain).accessibilityLabel("Atrás")
                    Spacer(minLength: 0)
                    Text(d.wrappedValue.isNew ? "Nuevo set" : "Editar set").font(.inter(17, .semibold))
                    Spacer(minLength: 0)
                    Button(action: save) {
                        Image(systemName: "checkmark").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 44, height: 44).background(Brand.accent, in: Circle())
                    }
                    .buttonStyle(.plain).accessibilityLabel("Guardar")
                }
                .padding(.bottom, 8)
                SCard {
                    FieldRow(symbol: "pencil", label: "Nombre", placeholder: "Ej. Mes de rodaje", text: d.name)
                    RowDivider()
                    DateRow(symbol: "calendar", label: "Inicio", date: d.from)
                    RowDivider()
                    DateRow(symbol: "calendar", label: "Fin", date: d.to)
                }
                if d.wrappedValue.isNew {
                    Text("Empieza con una copia de los límites de «\(d.wrappedValue.sourceName)». Luego los ajustas en Presupuesto.")
                        .font(.inter(13)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8).padding(.bottom, 6)
                }
                if let errorText { Text(errorText).font(.inter(14)).foregroundStyle(Brand.lossText).padding(.bottom, 10) }
                Button("Guardar", action: save).buttonStyle(PrimaryPillStyle()).padding(.bottom, 8)
                if !d.wrappedValue.isNew {
                    Button("Eliminar set") { askDelete = true }.buttonStyle(SecondaryPillStyle(destructive: true)).padding(.bottom, 8)
                }
            }
            .padding(.horizontal, 16).padding(.top, 16)
        }
        .alert("¿Eliminar este set?", isPresented: $askDelete) {
            Button("Eliminar", role: .destructive) {
                if let id = draft?.id { model.deleteBudgetSet(id: id) }
                dismiss()
            }
            Button("Cancelar", role: .cancel) {}
        } message: { Text("Esta acción no se puede deshacer.") }
    }

    private func save() {
        guard let d = draft else { return }
        do {
            try model.saveBudgetSet(id: d.id, isNew: d.isNew, name: d.name, from: iso(d.from), to: iso(d.to), cur: d.cur, source: d.source)
            dismiss()
        } catch ProfileEditor.FormError.missingName { errorText = "Escribe un nombre."
        } catch ProfileEditor.FormError.endBeforeStart { errorText = "El fin debe ser posterior al inicio."
        } catch ProfileEditor.FormError.setOverlap(let n) { errorText = Tr.f("Esas fechas se cruzan con «{0}». Cámbialas.", n)
        } catch { errorText = "No se pudo guardar." }
    }
}
