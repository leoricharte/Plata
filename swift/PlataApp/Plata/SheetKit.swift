import SwiftUI
import PlataCore

// Las piezas de las hojas de la web (estilo Apple Pay): cabecera con ✕ y ✓ de vidrio, monto grande, tarjeta de filas con icono, chips y selector en cápsula.

/// Cabecera de una hoja: ✕ de vidrio a la izquierda, título centrado y ✓ verde a la derecha.
struct SheetHead: View {
    let title: String
    var onClose: () -> Void
    var onSave: (() -> Void)? = nil

    var body: some View {
        ZStack {
            Text(title).font(.inter(17, .semibold)).tracking(-0.43)
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .modifier(GlassCircle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cerrar")
                Spacer(minLength: 0)
                if let onSave {
                    Button(action: onSave) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Brand.accent, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Guardar")
                }
            }
        }
        .frame(height: 44)
        .padding(.bottom, 4)
    }
}

/// «Monto» y la cifra de 52 pt con el símbolo de la moneda, centrados.
struct AmountField: View {
    let symbol: String
    @Binding var text: String
    var placeholder = "0"
    var focus: FocusState<Bool>.Binding
    var label: String = "Monto"
    static let font = Font.custom("Inter", fixedSize: 52).weight(.bold)

    var body: some View {
        VStack(spacing: 0) {
            Text(label).font(.inter(17)).foregroundStyle(.secondary)
            HStack(alignment: .center, spacing: 4) {
                Text(symbol).font(AmountField.font).tracking(-2)
                TextField(placeholder, text: $text)
                    .keyboardType(.decimalPad)
                    .font(AmountField.font).tracking(-2)
                    .multilineTextAlignment(.center)
                    .focused(focus)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(minWidth: 60)
                Image(systemName: "pencil").font(.system(size: 18)).opacity(0.34).padding(.leading, 6)
            }
            .contentShape(Rectangle())
            .onTapGesture { focus.wrappedValue = true }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }
}

/// Tarjeta blanca de 22 pt de radio que agrupa filas de formulario.
struct SCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(.top, 6)
            .padding(.bottom, 14)
    }
}

/// Una fila de formulario: icono verde, etiqueta pequeña y el valor debajo.
struct SRow<Content: View>: View {
    let symbol: String
    let label: String
    let content: Content
    init(symbol: String, label: String, @ViewBuilder content: () -> Content) {
        self.symbol = symbol
        self.label = label
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 19))
                .foregroundStyle(Brand.gainText)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(label).font(.inter(13)).foregroundStyle(.secondary)
                content.font(.inter(17))
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }
}

/// Fichas de categoría: cápsulas de 40 pt, la elegida en negro.
struct ChipRow: View {
    let items: [String]
    @Binding var selection: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    let on = item == selection
                    Button { selection = item } label: {
                        Text(item).font(.inter(15, .medium))
                            .foregroundStyle(on ? Color(light: "#FFFFFF", dark: "#000000") : Color.primary)
                            .padding(.horizontal, 16)
                            .frame(height: 40)
                            .background(on ? Color(light: "#1C1C1E", dark: "#F2F2F7") : Color(.secondarySystemGroupedBackground), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
        .padding(.bottom, 12)
    }
}

/// El selector en cápsula de la web (`.seg`): fondo gris y una pastilla blanca que se desliza.
struct PillSegmented<Value: Hashable>: View {
    let items: [(Value, String)]
    @Binding var selection: Value
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<items.count, id: \.self) { i in
                let item = items[i]
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) { selection = item.0 }
                } label: {
                    Text(item.1)
                        .font(.inter(items.count > 4 ? 13 : 15, .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background {
                            if selection == item.0 {
                                Capsule()
                                    .fill(Color(.secondarySystemGroupedBackground))
                                    .shadow(color: .black.opacity(0.14), radius: 2, y: 1)
                                    .shadow(color: .black.opacity(0.06), radius: 6, y: 4)
                                    .matchedGeometryEffect(id: "thumb", in: ns)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == item.0 ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Color(light: "#E5E5EA", dark: "#2C2C2E"), in: Capsule())
    }
}

/// Botón de la web para las pantallas de detalle (`.secbtn` / `.delbtn`): píldora blanca de 50 pt.
struct SecondaryPillStyle: ButtonStyle {
    var destructive = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.inter(17, .semibold))
            .foregroundStyle(destructive ? Brand.lossText : Color.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color(.secondarySystemGroupedBackground), in: Capsule())
            .overlay(Capsule().strokeBorder(Color(.separator).opacity(0.5), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// Etiqueta pequeña de la web (`.badge`): «Por confirmar», «Activo», «Simulado»…
struct StatusBadge: View {
    let text: String
    var fg: Color = Brand.warnText
    var bg: Color = Color(light: "#FFF1D6", dark: "#3A2A10")
    var size: CGFloat = 12
    var body: some View {
        Text(text).font(.inter(size, .semibold)).foregroundStyle(fg)
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(bg, in: Capsule())
    }
}

/// Fila de formulario con un campo de texto o número (`.srow` + `.sinput`).
struct FieldRow: View {
    let symbol: String
    let label: String
    let placeholder: String
    @Binding var text: String
    var numeric = false
    var prefix: String? = nil
    var body: some View {
        SRow(symbol: symbol, label: label) {
            HStack(spacing: 6) {
                if let prefix { Text(prefix).font(.inter(17, .medium)) }
                TextField(placeholder, text: $text)
                    .keyboardType(numeric ? .decimalPad : .default)
            }
        }
    }
}

/// Fila de fecha: el texto como en la web y el selector nativo invisible encima.
struct DateRow: View {
    let symbol: String
    let label: String
    @Binding var date: Date
    var maxToday = false

    static func text(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return "\(c.day ?? 1) \(Spanish.monthsShort[(c.month ?? 1) - 1]) \(c.year ?? 2000)"
    }

    var body: some View {
        SRow(symbol: symbol, label: label) {
            Text(DateRow.text(date)).frame(maxWidth: .infinity, alignment: .leading)
                .overlay {
                    Group {
                        if maxToday { DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date) }
                        else { DatePicker("", selection: $date, displayedComponents: .date) }
                    }
                    .labelsHidden().colorMultiply(.clear).frame(maxWidth: .infinity, alignment: .leading)
                }
        }
    }
}

/// Fecha opcional («Termina el (opcional)»): «Sin fecha» hasta que se elige una.
struct OptionalDateRow: View {
    let symbol: String
    let label: String
    @Binding var date: Date?

    var body: some View {
        SRow(symbol: symbol, label: label) {
            HStack {
                Text(date.map(DateRow.text) ?? "Sin fecha").foregroundStyle(date == nil ? .secondary : .primary)
                    .overlay {
                        DatePicker("", selection: Binding(get: { date ?? Date() }, set: { date = $0 }), displayedComponents: .date)
                            .labelsHidden().colorMultiply(.clear).frame(maxWidth: .infinity, alignment: .leading)
                    }
                Spacer(minLength: 0)
                if date != nil {
                    Button { date = nil } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }.buttonStyle(.plain)
                }
            }
        }
    }
}

/// Monedas disponibles en el perfil: la principal primero, luego las de tus cuentas y tarjetas.
func profileCurrencies(_ e: Engine, including extra: String = "") -> [String] {
    var out: [String] = [e.primaryCurrency]
    for a in e.allAccounts + e.allCards { let c = Engine.text(a["cur"]); if !c.isEmpty && !out.contains(c) { out.append(c) } }
    if !extra.isEmpty && !out.contains(extra) { out.append(extra) }
    return out
}

/// Elegir el color de una cuenta o tarjeta (`SWATCH` de la web).
struct SwatchRow: View {
    @Binding var color: String
    static let colors = ["#B98AE6", "#6D8BEA", "#5CC8C0", "#22B573", "#EDB03E", "#FF9F0A", "#F08FB0", "#FF453A", "#8E8E93", "#1C1C1E"]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Self.colors, id: \.self) { c in
                    Button { color = c } label: {
                        Circle().fill(Color(hex: c)).frame(width: 32, height: 32)
                            .overlay(Circle().strokeBorder(Color.primary, lineWidth: color == c ? 3 : 0).padding(-4))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6).padding(.vertical, 8)
        }
        .scrollClipDisabled()
    }
}
