import SwiftUI

extension Color {
    /// `#RGB`, `#RRGGBB` o `#RRGGBBAA`.
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        if s.count == 8 { v >>= 8 }
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}

enum Brand {
    static let green = Color(hex: "#1A9D63")
    static let gain = Color(hex: "#1A9D63")
    static let loss = Color(hex: "#E5322D")
    static let warn = Color(hex: "#E5A100")
    static let expenseBar = Color(hex: "#EDB03E")
    static let incomeBar = Color(hex: "#6D8BEA")
}

/// Un símbolo de SF Symbols para cada categoría conocida; las demás usan una etiqueta.
func categorySymbol(_ name: String) -> String {
    switch name.lowercased() {
    case "comida": return "fork.knife"
    case "alquiler": return "house.fill"
    case "transporte": return "car.fill"
    case "ocio": return "ticket.fill"
    case "proyectos": return "briefcase.fill"
    case "mascotas": return "pawprint.fill"
    case "salud": return "cross.case.fill"
    case "ingreso": return "arrow.down.circle.fill"
    case "otros": return "ellipsis.circle.fill"
    case "pago de crédito": return "creditcard.fill"
    case "transferencia": return "arrow.left.arrow.right"
    default: return "tag.fill"
    }
}

/// El cuadrito redondeado con el icono de una categoría o cuenta.
struct Tile: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 38

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color, in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Una tarjeta del Resumen: título pequeño y contenido, sobre fondo de grupo.
struct Card<Content: View>: View {
    let title: LocalizedStringKey?
    let content: Content

    init(title: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
