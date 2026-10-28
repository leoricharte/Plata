import SwiftUI
import PlataCore

/// Categoría de gasto con su límite mensual (`FORMS.budget` de la web).
struct CategorySheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let name: String?

    @State private var loaded = false
    @State private var nameText = ""
    @State private var limitText = ""
    @State private var color = "#6D8BEA"
    @State private var icon = ""
    @State private var iconUser = false
    @State private var colorUser = false
    @State private var errorText: String?
    @State private var askDelete = false
    @FocusState private var focus: Bool

    var body: some View {
        let e = model.engine
        let f = model.fmt
        let cur = e.primaryCurrency
        ScrollView {
            VStack(spacing: 0) {
                SheetHead(title: name == nil ? "Nueva categoría" : "Categoría", onClose: { dismiss() }, onSave: { save() })
                StylePreview(kind: .category, name: nameText, color: color, icon: icon, iconUser: iconUser, colorUser: colorUser)
                AmountField(symbol: f.symbol(cur).trimmingCharacters(in: .whitespaces), text: $limitText,
                            placeholder: Money.decimals(cur) > 0 ? "0.00" : "0", focus: $focus, label: "Límite mensual (opcional)")
                SCard {
                    FieldRow(symbol: "pencil", label: "Nombre", placeholder: "Nombre", text: $nameText)
                }
                StylePicker(color: $color, icon: $icon, iconUser: $iconUser, colorUser: $colorUser)
                if let errorText { Text(errorText).font(.inter(14)).foregroundStyle(Brand.lossText).padding(.bottom, 10) }
                Button("Guardar") { save() }.buttonStyle(PrimaryPillStyle()).padding(.bottom, 8)
                if let name, name != "Otros" {
                    Button("Eliminar") { askDelete = true }.buttonStyle(SecondaryPillStyle(destructive: true)).padding(.bottom, 8)
                }
            }
            .padding(.horizontal, 16).padding(.top, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .presentationDetents([.large]).presentationDragIndicator(.visible).presentationCornerRadius(38)
        .presentationBackground(Color(light: "#F4F4F8", dark: "#1C1C1E"))
        .onAppear(perform: load)
        .confirmationDialog("¿Eliminar esto?", isPresented: $askDelete, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) {
                if let name { try? model.deleteCategory(name: name) }
                dismiss()
            }
            Button("Cancelar", role: .cancel) {}
        } message: { Text("Esta acción no se puede deshacer.") }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        let e = model.engine
        if let name {
            nameText = name
            color = e.categoryColor(name)
            let cat = (e.data["cats"]?.arrayValue ?? []).first { Engine.text($0["name"]) == name }
            icon = Engine.text(cat?["icon"])
            let lim = e.budgetLimits(model.viewSet)[name] ?? 0
            let shown = lim > 0 ? e.fromUSD(lim, e.primaryCurrency) : 0
            limitText = shown == 0 ? "" : (shown == shown.rounded() ? String(Int64(shown)) : String(Engine.roundCents(shown)))
        } else { focus = true }
    }

    private func save() {
        let e = model.engine
        let typed = Double(limitText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)) ?? 0
        do {
            try model.saveCategory(original: name, name: nameText, color: color, icon: icon, limitUSD: typed > 0 ? e.usd(typed, e.primaryCurrency) : 0)
            dismiss()
        } catch ProfileEditor.FormError.missingName { errorText = "Escribe un nombre."
        } catch ProfileEditor.FormError.reservedName { errorText = "Ese nombre está reservado."
        } catch ProfileEditor.FormError.duplicateCategory { errorText = "Ya existe esa categoría."
        } catch { errorText = "No se pudo guardar." }
    }
}
