import Foundation
import PlataCore

/// Los textos de Insights, tal cual la web (`PHRASES`, `EVAL_TXT`, `HALF_TXT`, `HALF_FIRST`, `HALF_EVAL`).
enum InsightsText {
    /// [con nombre, sin nombre]; `{n}` nombre, `{mes}` y `{Mes}` el mes, `{bien}` «Buen trabajo» / «Bien hecho».
    static let phrases: [String: [[String]]] = [
        "S": [["Excelente trabajo en {mes}, {n}.", "Excelente trabajo en {mes}."], ["{n}, {mes} fue un mes de primera.", "{Mes} fue un mes de primera."],
              ["Así se hace, {n}: {mes} quedó impecable.", "Así se hace: {mes} quedó impecable."], ["Mes redondo, {n}. Sigue así.", "Mes redondo. Sigue así."]],
        "A": [["Muy buen {mes}, {n}.", "Muy buen {mes}."], ["Vas por muy buen camino, {n}.", "Vas por muy buen camino."],
              ["Buen trabajo en {mes}, {n}. Casi perfecto.", "Buen trabajo en {mes}. Casi perfecto."], ["{n}, {mes} salió muy bien.", "{Mes} salió muy bien."]],
        "B": [["Buen ritmo en {mes}, {n}.", "Buen ritmo en {mes}."], ["Vas bien, {n}. Un pequeño ajuste y subes.", "Vas bien. Un pequeño ajuste y subes."],
              ["{Mes} salió sólido, {n}.", "{Mes} salió sólido."], ["{bien}, {n}. Aún hay margen para más.", "{bien}. Aún hay margen para más."]],
        "C": [["{Mes} fue regular, {n}. Se puede mejorar.", "{Mes} fue regular. Se puede mejorar."], ["Vas a medias, {n}. Veamos dónde ajustar.", "Vas a medias. Veamos dónde ajustar."],
              ["Hay espacio para mejorar, {n}.", "Hay espacio para mejorar."], ["Ni mal ni bien, {n}. Puedes más.", "Ni mal ni bien. Puedes más."]],
        "D": [["Podemos hacerlo mejor, {n}.", "Podemos hacerlo mejor."], ["{Mes} costó un poco, {n}. Aún estás a tiempo.", "{Mes} costó un poco. Aún estás a tiempo."],
              ["Toca ajustar, {n}. Empieza por lo más grande.", "Toca ajustar. Empieza por lo más grande."], ["Corrijamos el rumbo, {n}.", "Corrijamos el rumbo."]],
        "F": [["{Mes} fue difícil, {n}. Empecemos de nuevo.", "{Mes} fue difícil. Empecemos de nuevo."], ["Es momento de frenar, {n}. Lo vemos paso a paso.", "Es momento de frenar. Lo vemos paso a paso."],
              ["Esto no define tu año, {n}. Hagamos un plan.", "Esto no define tu año. Hagamos un plan."], ["Un mal mes le pasa a cualquiera, {n}. Seguimos.", "Un mal mes le pasa a cualquiera. Seguimos."]],
    ]

    static let evaluation: [String: String] = [
        "S": "Un mes ejemplar: gastas con control, ahorras y cumples tus metas. Mantén este ritmo y sigue puliendo los detalles. Estás construyendo un hábito que se nota.",
        "A": "Muy buen mes. Estás cerca de la excelencia; un pequeño ajuste en tus gastos más grandes te llevaría a la cima. Ya casi lo tienes.",
        "B": "Vas por buen camino. Aún hay margen para mejorar: revisa las categorías que más subieron y sigue avanzando. Cada mes cuenta.",
        "C": "Un mes intermedio. No está mal, pero puedes hacerlo un poquito mejor: elige una categoría para recortar y mira cómo cambia tu nota. Los grandes cambios empiezan con uno pequeño.",
        "D": "Este mes se complicó, pero estás a tiempo de corregir. Empieza por tu mayor gasto y celebra cada pequeño avance. Un mes más ordenado cambia el panorama.",
        "F": "Un mal mes no define tu camino. Empecemos de nuevo: un límite por categoría y un pequeño aporte a tus metas. Lo importante es seguir intentando.",
    ]

    static let halfEvaluation: [String: String] = [
        "S": "Ritmo de primera. Mantenlo y cierra el mes con nota perfecta.",
        "A": "Muy buen ritmo. Un pequeño ajuste y cierras el mes en lo más alto.",
        "B": "Buen ritmo, con margen. Cuida tus gastos grandes y sube de nota.",
        "C": "Vas a medias. Aún estás a tiempo de mejorar antes de fin de mes.",
        "D": "Mes cuesta arriba, pero hay tiempo. Empieza por tu mayor gasto.",
        "F": "Toca frenar, pero aún queda mes. Un plan simple cambia el rumbo.",
    ]

    static let half = [["¡Half‑time!", "Esto es lo que llevabas al día 15."], ["Llegó el half‑time.", "Un adelanto de tu nota, con margen para mejorarla."], ["Vas a mitad de mes.", "Este es tu half‑time: así iba tu nota el día 15."]]
    static let halfFirst = [["Tu primer half‑time.", "Tu primer cierre de mes se acerca. Así ibas el día 15."], ["¡Primer half‑time!", "Falta poco para tu primer cierre de mes."], ["Llegaste a mitad de mes.", "Este es tu primer half‑time; tu primer cierre se acerca."]]

    static let adjective = ["S": "Perfecto", "A": "Muy bueno", "B": "Bueno", "C": "Mediocre", "D": "Deficiente", "F": "Muy malo"]

    /// «A», «A+», «D-» o «Diamante» (`tL`).
    static func label(_ letter: String, _ plus: StreakLevel) -> String {
        if plus == .diamond { return "Diamante" }
        if plus == .plus { return letter + ((letter == "D" || letter == "F") ? "-" : "+") }
        return letter
    }

    /// La frase del banner de cierre (`insPhrase`).
    static func phrase(_ m: InsightsModel, nick: String, gender: String) -> String {
        if !m.hasPrev { return "Registra un mes completo para recibir tu evaluación." }
        let list = phrases[m.letter] ?? phrases["B"]!
        let y = Int(m.mk.prefix(4)) ?? 0, mo = (Int(String(m.mk.dropFirst(5).prefix(2))) ?? 1) - 1
        let v = list[(y * 12 + mo) % list.count]
        let mes = Spanish.monthsFull[mo]
        let bien = gender == "m" ? "Bien hecho" : "Buen trabajo"
        return (nick.isEmpty ? v[1] : v[0])
            .replacingOccurrences(of: "{n}", with: nick).replacingOccurrences(of: "{bien}", with: bien)
            .replacingOccurrences(of: "{Mes}", with: mes.prefix(1).uppercased() + mes.dropFirst())
            .replacingOccurrences(of: "{mes}", with: mes)
    }

    static func monthIndex(_ mk: String) -> Int { (Int(String(mk.dropFirst(5).prefix(2))) ?? 1) - 1 }
}
