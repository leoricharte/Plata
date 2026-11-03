import SwiftUI
import EventKit
import EventKitUI
import PlataCore

/// Un pago (o cualquier evento) listo para el Calendario de Apple: se añade el día completo, con el monto en las notas
/// y un enlace `plata://event?key=…` que, al tocarlo en el calendario, abre ese evento en Plata.
struct CalendarDraft: Identifiable {
    let id = UUID()
    var title: String
    var day: LocalDate
    var notes: String
    var url: URL?
}

/// La hoja del sistema para añadir un evento al Calendario. La persona lo revisa y lo guarda ella: Plata no lee su calendario
/// y no necesita pedirle permiso.
struct CalendarEditSheet: UIViewControllerRepresentable {
    let draft: CalendarDraft
    let onDone: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onDone) }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.title = draft.title
        event.isAllDay = true
        let d = draft.day.date()
        event.startDate = d
        event.endDate = d
        event.notes = draft.notes
        event.url = draft.url
        event.addAlarm(EKAlarm(relativeOffset: -15 * 3600))   // un aviso el día anterior a las 9:00 (se puede quitar en la hoja)
        let vc = EKEventEditViewController()
        vc.eventStore = store
        vc.event = event
        vc.editViewDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: EKEventEditViewController, context: Context) {}

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let onDone: () -> Void
        init(_ onDone: @escaping () -> Void) { self.onDone = onDone }
        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) { onDone() }
    }
}
