import SwiftUI
import CoreText
import UIKit
import PlataCore

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

extension Color {
    /// Un color que cambia entre modo claro y oscuro.
    init(light: String, dark: String) {
        self.init(UIColor { $0.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light)) })
    }
}

/// Los colores de la marca, los mismos de la web.
enum Brand {
    static let accent = Color(hex: "#22B573")
    static let green = Color(hex: "#1A9D63")
    static let gain = Color(hex: "#1A9D63")
    static let loss = Color(hex: "#E5322D")
    static let warn = Color(hex: "#E5A100")
    static let expenseBar = Color(hex: "#EDB03E")
    static let incomeBar = Color(hex: "#6D8BEA")
    static let track = Color(.tertiarySystemFill)
    /// Texto verde de la web (`--gt`) y su fondo suave (`--gbg`).
    static let gainText = Color(light: "#138A55", dark: "#34D08A")
    static let gainTextStrong = Color(light: "#12784A", dark: "#4FE0A0")
    static let gainBg = Color(light: "#E2F6EC", dark: "#12301F")
    static let warnText = Color(light: "#8A5100", dark: "#FFB340")
    static let lossText = Color(light: "#D70015", dark: "#FF6961")
}

// MARK: - Tipografía (Inter, la misma de la web)

enum PlataFont {
    /// Inter viene dentro de la app (fuente variable); se registra al abrir.
    static func register() {
        guard let url = Bundle.main.url(forResource: "Inter", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}

extension Font {
    static func inter(_ size: CGFloat, _ weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        Font.custom("Inter", size: size, relativeTo: style).weight(weight)
    }
}

// MARK: - Textos en español (como la web)

enum Spanish {
    /// «Ejemplo: «Estás listo, Ana. Bienvenido.»» (`genderExampleL`, en español).
    static func genderExample(_ g: String, nick: String) -> String {
        let n = nick.trimmingCharacters(in: .whitespaces)
        if Tr.isEnglish { return "Example: “Well done" + (n.isEmpty ? "" : ", " + n) + ". Welcome.”" }
        let a = ["m": "Estás listo", "f": "Estás lista"][g] ?? "Todo listo"
        let b = ["m": "Bienvenido", "f": "Bienvenida"][g] ?? "Te damos la bienvenida"
        return "Ejemplo: «\(a)\(n.isEmpty ? "" : ", " + n). \(b).»"
    }

    static let monthsFull = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
    static let monthsShort = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]
    static let weekdaysFull = ["Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"]
    static let weekdaysShort = ["dom", "lun", "mar", "mié", "jue", "vie", "sáb"]

    /// "Miércoles 28 de octubre"
    static func dateLong(_ d: LocalDate) -> String {
        "\(weekdaysFull[d.weekday]) \(d.day) de \(monthsFull[d.month0])"
    }

    /// "mié 28 oct"
    static func dateShort(_ d: LocalDate) -> String {
        "\(weekdaysShort[d.weekday]) \(d.day) \(monthsShort[d.month0])"
    }

    static func greeting(nick: String, hour: Int) -> String {
        let word = hour < 12 ? "Buenos días" : (hour < 19 ? "Buenas tardes" : "Buenas noches")
        return nick.isEmpty ? "\(word)." : "\(word), \(nick)."
    }

    static func plural(_ n: Int, _ one: String, _ many: String) -> String { "\(n) \(n == 1 ? one : many)" }
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

// MARK: - Piezas

/// El cuadrito redondeado con el icono de una categoría o cuenta (46 pt en la web).
struct Tile: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 46

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.43, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color, in: RoundedRectangle(cornerRadius: size * 0.283, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// La inicial de un nombre en un cuadrito de color (ingresos previstos).
struct LetterTile: View {
    let letter: String
    let color: Color
    var size: CGFloat = 46

    var body: some View {
        Text(letter.uppercased())
            .font(.inter(size * 0.43, .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color, in: RoundedRectangle(cornerRadius: size * 0.283, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Una tarjeta: texto pequeño arriba y el contenido; esquinas de 26 pt como la web.
struct Card<Content: View>: View {
    let title: String?
    let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title).font(.inter(15)).foregroundStyle(.secondary)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

/// Tarjeta de lista: filas con separador fino y sin título (la web las llama `card lst`).
struct ListCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        VStack(spacing: 0) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

/// Título de sección grande ("Cuentas", "Más").
struct SectionHead: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.inter(22, .bold, relativeTo: .title2))
            .tracking(-0.4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.top, 6)
    }
}

/// Fila de una tarjeta de lista con flecha: título a la izquierda y detalle a la derecha.
struct MoreRow: View {
    let title: String
    var detail: String = ""
    var detailColor: Color = .secondary

    var body: some View {
        HStack(spacing: 8) {
            Text(title).font(.inter(17)).foregroundStyle(.primary)
            Spacer(minLength: 8)
            if !detail.isEmpty {
                Text(detail).font(.inter(15)).foregroundStyle(detailColor).lineLimit(1)
            }
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(.tertiary)
        }
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }
}

/// Separador fino entre filas de una `ListCard`.
struct RowDivider: View {
    var body: some View { Divider().overlay(Color(.separator).opacity(0.5)) }
}

/// Enlace verde de una tarjeta ("Ver ahorro").
struct GreenLink: View {
    let title: String
    var body: some View {
        Text(title).font(.inter(15, .medium)).foregroundStyle(Brand.green).padding(.top, 6)
    }
}

/// La píldora oscura "B E T A".
struct BetaPill: View {
    var label: String = "B E T A"
    var body: some View {
        Text(label)
            .font(.inter(11, .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .frame(height: 20)
            .background(Color(hex: "#1C1C1E"), in: Capsule())
            .accessibilityLabel("Beta")
    }
}

/// Un botón redondo con efecto de vidrio (Liquid Glass en iOS 26 o posterior; material translúcido antes).
struct GlassCircle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular.interactive(), in: Circle())
        } else {
            content
                .background(.regularMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.6), lineWidth: 1))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        }
    }
}

struct GlassIcon: View {
    let symbol: String
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: 44, height: 44)
            .modifier(GlassCircle())
    }
}

/// El botón principal oscuro de la web (píldora negra, texto blanco).
struct PrimaryPillStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.inter(18, .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color(hex: "#111111"), in: Capsule())
            .opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
    }
}
