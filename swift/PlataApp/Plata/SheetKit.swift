import SwiftUI

// Las piezas de las hojas de la web (estilo Apple Pay): cabecera con ✕ y ✓ de vidrio, monto grande, tarjeta de filas con icono, chips y selector en cápsula.

/// Cabecera de una hoja: ✕ de vidrio a la izquierda, título centrado y ✓ verde a la derecha.
struct SheetHead: View {
    let title: LocalizedStringKey
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

    var body: some View {
        VStack(spacing: 0) {
            Text("Monto").font(.inter(17)).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(symbol).font(.inter(52, .bold, relativeTo: .largeTitle)).tracking(-2)
                TextField(placeholder, text: $text)
                    .keyboardType(.decimalPad)
                    .font(.inter(52, .bold, relativeTo: .largeTitle)).tracking(-2)
                    .multilineTextAlignment(.center)
                    .focused(focus)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(minWidth: 60)
                    .monospacedDigit()
                Image(systemName: "pencil").font(.system(size: 18)).opacity(0.34).alignmentGuide(.firstTextBaseline) { $0[.bottom] - 8 }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
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
    let label: LocalizedStringKey
    let content: Content
    init(symbol: String, label: LocalizedStringKey, @ViewBuilder content: () -> Content) {
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
        .padding(.bottom, 12)
    }
}

/// El selector en cápsula de la web (`.seg`): fondo gris y una pastilla blanca que se desliza.
struct PillSegmented<Value: Hashable>: View {
    let items: [(Value, LocalizedStringKey)]
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
