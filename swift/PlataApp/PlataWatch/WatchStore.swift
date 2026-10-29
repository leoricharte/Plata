import Foundation
import Observation
import SwiftUI
import WatchConnectivity
import WatchKit

/// Lo último que mandó el iPhone, guardado para usarlo sin conexión, y los movimientos anotados aquí.
@MainActor
@Observable
final class WatchStore: NSObject, WCSessionDelegate {
    var snapshot: WatchSnapshot?
    /// Un movimiento confirmado que todavía se puede deshacer (se envía a los pocos segundos).
    var pending: WatchEntry?
    private var sendTask: Task<Void, Never>?
    private let key = "plata.watch.snapshot"

    override init() {
        super.init()
        if let d = UserDefaults.standard.data(forKey: key), let s = try? JSONDecoder().decode(WatchSnapshot.self, from: d) { snapshot = s }
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: resumen

    private func take(_ ctx: [String: Any]) {
        guard let d = ctx[WatchKey.snapshot] as? Data, let s = try? JSONDecoder().decode(WatchSnapshot.self, from: d) else { return }
        snapshot = s
        UserDefaults.standard.set(d, forKey: key)
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let ctx = session.receivedApplicationContext
        Task { @MainActor in self.take(ctx) }
    }
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.take(applicationContext) }
    }

    // MARK: movimientos

    /// Anota un movimiento: queda 5 segundos para deshacer y luego viaja al iPhone (que lo guarda y lo sincroniza).
    func add(_ e: WatchEntry) {
        flushPending()
        pending = e
        WKInterfaceDevice.current().play(.success)
        sendTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.flushPending()
        }
    }

    func undo() {
        sendTask?.cancel()
        pending = nil
        WKInterfaceDevice.current().play(.click)
    }

    func flushPending() {
        sendTask?.cancel()
        guard let e = pending, let d = try? JSONEncoder().encode(e) else { pending = nil; return }
        WCSession.default.transferUserInfo([WatchKey.entry: d])   // se encola y llega aunque el iPhone no esté cerca
        pending = nil
    }
}
