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

    private var custom: Binding<Color> {
        Binding(get: { Color(hex: color.isEmpty ? "#22B573" : color) },
                set: { color = $0.hexString; colorUser = true })
    }

    var body: some View {
        SCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Color").font(.inter(13)).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(SwatchRow.colors, id: \.self) { c in
                            Button { color = c; colorUser = true } label: {
                                Circle().fill(Color(hex: c)).frame(width: 32, height: 32)
                                    .overlay(Circle().strokeBorder(Color.primary, lineWidth: color.uppercased() == c ? 3 : 0).padding(-4))
                            }
                            .buttonStyle(.plain).accessibilityLabel("Color")
                        }
                        ColorPicker("Color personalizado", selection: custom, supportsOpacity: false)
                            .labelsHidden()
                            .overlay(Circle().strokeBorder(Color.primary, lineWidth: !SwatchRow.colors.contains(color.uppercased()) && !color.isEmpty ? 3 : 0).padding(-4).allowsHitTesting(false))
                    }
                    .padding(.horizontal, 6).padding(.vertical, 8)
                }
                .scrollClipDisabled()
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
