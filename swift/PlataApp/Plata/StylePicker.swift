import SwiftUI
import UIKit
import PlataCore

/// Los 16 iconos que elige la persona (`ICONS` de la web) en su equivalente de SF Symbols, en el mismo orden.
let iconChoices: [(key: String, symbol: String)] = [
    ("bank", "building.columns"), ("card", "creditcard"), ("wallet", "wallet.bifold"), ("cash", "banknote"),
    ("coins", "dollarsign.circle"), ("bag", "bag"), ("car", "car"), ("home", "house"),
    ("cap", "graduationcap"), ("plane", "airplane"), ("heart", "heart"), ("star", "star"),
    ("bolt", "bolt"), ("phone", "iphone"), ("globe", "globe"), ("gift", "gift"),
]
func iconSymbol(_ key: String) -> String? { iconChoices.first { $0.key == key }?.symbol }

extension Engine {
    /// Símbolo de una categoría: el icono elegido a mano si existe, si no el de siempre.
    func catSymbol(_ name: String) -> String {
        let cat = (data["cats"]?.arrayValue ?? []).first { Engine.text($0["name"]) == name }
        return iconSymbol(Engine.text(cat?["icon"])) ?? categorySymbol(name)
    }
}

/// El icono de una categoría en las listas: el que eligió la persona o, si no hay, la inicial (como la web).
struct CategoryTile: View {
    let engine: Engine
    let name: String
    let color: Color
    var size: CGFloat = 46
    var body: some View {
        let cat = (engine.data["cats"]?.arrayValue ?? []).first { Engine.text($0["name"]) == name }
        if let sym = iconSymbol(Engine.text(cat?["icon"])) { Tile(symbol: sym, color: color, size: size) }
        else { LetterTile(letter: String(Tr.t(name).prefix(1)), color: color, size: size) }
    }
}

extension Color {
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }
}

/// Color + Icono de una categoría, cuenta, tarjeta o meta (`styleHTML` de la web).
struct StylePicker: View {
    @Binding var color: String
    @Binding var icon: String
    @Binding var iconUser: Bool
    @Binding var colorUser: Bool
    var debt = false
    @State private var hexText = ""

    private var custom: Binding<Color> {
        Binding(get: { Color(hex: color.isEmpty ? "#22B573" : color) },
                set: { color = $0.hexString; colorUser = true })
    }

    var body: some View {
        SCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Text("Color").font(.inter(13)).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    // vista previa viva: se ve el cambio sin subir a mirar el cuadrito de arriba
                    RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Color(hex: color.isEmpty ? SwatchRow.colors[0] : color))
                        .frame(width: 38, height: 38)
                        .overlay {
                            if let s = iconSymbol(icon) { Image(systemName: s).font(.system(size: 18, weight: .semibold)).foregroundStyle(.white) }
                        }
                        .animation(.easeOut(duration: 0.15), value: color)
                        .accessibilityHidden(true)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), alignment: .center, spacing: 10) {
                    ForEach(SwatchRow.colors, id: \.self) { c in
                        Button { color = c; colorUser = true; hexText = c } label: {
                            Circle().fill(Color(hex: c)).frame(width: 32, height: 32)
                                .overlay(Circle().strokeBorder(Color.primary, lineWidth: color.uppercased() == c ? 3 : 0).padding(-4))
                                .frame(width: 40, height: 40)
                        }
                        .buttonStyle(.plain).accessibilityLabel("Color")
                    }
                }
                HStack(spacing: 10) {
                    ColorPicker("Espectro", selection: custom, supportsOpacity: false)
                        .font(.inter(15)).fixedSize()
                    Spacer(minLength: 0)
                    TextField("#RRGGBB", text: $hexText)
                        .font(.inter(15)).monospaced().textInputAutocapitalization(.characters).autocorrectionDisabled()
                        .multilineTextAlignment(.trailing).frame(width: 96)
                        .onChange(of: hexText) { _, v in
                            var h = v.trimmingCharacters(in: .whitespaces).uppercased()
                            if !h.hasPrefix("#") { h = "#" + h }
                            if h.range(of: "^#[0-9A-F]{6}$", options: .regularExpression) != nil { color = h; colorUser = true }
                        }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            RowDivider()
            VStack(alignment: .leading, spacing: 10) {
                Text("Icono").font(.inter(13)).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], spacing: 8) {
                    cell(on: icon.isEmpty) { icon = ""; iconUser = false; colorUser = false } content: {
                        if debt { Image(systemName: "creditcard").font(.system(size: 20, weight: .medium)) }
                        else { Text("Aa").font(.inter(16, .bold)) }
                    }
                    .accessibilityLabel("Automático")
                    ForEach(iconChoices, id: \.key) { ch in
                        cell(on: icon == ch.key) { icon = ch.key; iconUser = true } content: {
                            Image(systemName: ch.symbol).font(.system(size: 20, weight: .medium))
                        }
                        .accessibilityLabel(ch.key)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .padding(.bottom, 8)
        .onAppear { hexText = color.uppercased() }
        .onChange(of: color) { _, v in if v.uppercased() != hexText.uppercased() { hexText = v.uppercased() } }
    }

    private func cell<C: View>(on: Bool, action: @escaping () -> Void, @ViewBuilder content: () -> C) -> some View {
        Button(action: action) {
            content()
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary, lineWidth: on ? 2 : 0))
        }
        .buttonStyle(.plain)
    }
}

/// La vista previa del cuadrito en los formularios (`#fPrev` de la web): 64 pt, centrada sobre el monto.
struct StylePreview: View {
    enum Kind { case account, debt, category }
    let kind: Kind
    let name: String
    let color: String
    let icon: String
    let iconUser: Bool
    let colorUser: Bool

    var body: some View {
        let col = color.isEmpty ? SwatchRow.colors[0] : color
        let obj: JSONValue = .object(["name": .string(name), "color": .string(color), "icon": .string(icon),
                                      "iconUser": .bool(iconUser), "colorUser": .bool(colorUser)])
        Group {
            if kind == .category {
                Tile(symbol: iconSymbol(icon) ?? categorySymbol(name), color: Color(hex: col), size: 64)
            } else {
                AccountTile(o: obj, color: col, debt: kind == .debt, size: 64)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }
}
