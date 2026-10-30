import UIKit
import SwiftUI

/// La extensión «Compartir» de Plata: aparece en la hoja de compartir de Yape, Plin, Fotos o Archivos cuando lo que se comparte es una imagen, un PDF o texto.
/// Lee la constancia EN EL DISPOSITIVO (Vision + Nazca) y la deja en la bandeja compartida; la app la añade al abrirse.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        let host = UIHostingController(rootView: ShareView(model: ShareModel(context: extensionContext)))
        host.view.backgroundColor = .clear
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)
    }
}
