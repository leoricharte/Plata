import Foundation
import SwiftUI

// Lo que la app calcula para los widgets del iPhone (las piezas del Bento que sirven como widget). Se guarda en el App Group.

struct PSlice: Codable, Hashable, Identifiable { var name: String; var v: Double; var hex: String; var id: String { name } }
struct PBar: Codable, Hashable, Identifiable { var label: String; var income: Double; var expense: Double; var id: String { label } }
/// Una fila genérica: gasto, próximo movimiento, límite, tarjeta o meta.
struct PRow: Codable, Hashable, Identifiable {
    var name: String
    var amt: Double          // monto con signo (gastos negativos)
    var lim: Double          // límite o meta (0 = no aplica)
    var sub: String          // línea chica (fecha, "en 3 d"…)
    var frac: Double         // 0...1 (-1 = no aplica)
    var id: String { name + sub + String(amt) }
}

struct PhoneSnapshot: Codable {
    var stamp: Double
    var sym: String
    var dec: Int
    var name: String
    var balance: Double
    var income: Double
    var expense: Double
    var rate: Double         // tasa de ahorro 0...1 (-9 = sin ingresos)
    var letter: String
    var adjective: String
    var score: Int
    var day: Int
    var dim: Int
    var budgetTotal: Double
    var budgetSpent: Double
    var debtTotal: Double
    var creditUsed: Double   // 0...1 (-1 = sin tarjetas con límite)
    var cats: [PSlice]
    var budget: [PRow]
    var top: [PRow]
    var upcoming: [PRow]
    var debt: [PRow]
    var goals: [PRow]
    var daily: [Double]      // gasto acumulado por día del mes
    var weekday: [Double]    // gasto por día de la semana (domingo primero)
    var flow: [PBar]
}

enum PhoneShare {
    static let key = "phone.snapshot"
    static func save(_ data: Data) { UserDefaults(suiteName: WatchShare.group)?.set(data, forKey: key) }
    static func load() -> PhoneSnapshot? {
        guard let d = UserDefaults(suiteName: WatchShare.group)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PhoneSnapshot.self, from: d)
    }
}

extension Color {
    init(wHex hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self.init(red: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255, blue: Double(v & 255) / 255)
    }
}
