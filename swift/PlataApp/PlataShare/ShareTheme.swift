import SwiftUI
import UIKit

/// Los colores de Plata para la extensión «Compartir» (la extensión no comparte el tema de la app): menta claro y verde bosque oscuro.
enum ShareTheme {
    static func hex(_ h: String) -> UIColor {
        let v = UInt32(h.dropFirst(), radix: 16) ?? 0
        return UIColor(red: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: 1)
    }
    static func adaptive(_ light: String, _ dark: String) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? hex(dark) : hex(light) })
    }

    static let green = Color(red: 0.133, green: 0.710, blue: 0.451)           // #22B573
    static let greenDeep = Color(red: 0.102, green: 0.616, blue: 0.388)       // #1A9D63
    static let text = adaptive("#0E2A1D", "#EAF7F0")
    static let sub = adaptive("#4F6B5E", "#8FB3A1")
    static let greenText = adaptive("#138A55", "#34D08A")
    static let cardTop = adaptive("#E6F6EE", "#12402C")
    static let cardBottom = adaptive("#F7FBF9", "#0A2218")
    static let rowFill = adaptive("#FFFFFF", "#1B4D37")
    static let rowStroke = adaptive("#BFE3D0", "#2C6B4E")
    static let scrim = adaptive("#0B3A27", "#02100A")
}

/// Una fila que se hunde un poco al tocarla.
struct ShareRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
