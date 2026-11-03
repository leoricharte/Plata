import Foundation
import PlataCore

extension Engine {
    /// Cómo se ve una cuenta o tarjeta en los menús de elegir: nombre, últimos dígitos y saldo (o lo disponible, si es de crédito),
    /// con las palabras ya traducidas. El orden de las listas es `accountsByUse` / `cardsByUse` / `accountsAndCardsByUse`.
    func menuLabel(_ a: JSONValue) -> String {
        menuLabel(a, available: Tr.t("disponible"), owed: Tr.t("pendiente"))
    }
}
