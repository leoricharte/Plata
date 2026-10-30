import SwiftUI

// Los textos del reloj están escritos en español; estas sobrecargas los pasan por `Tr.t` (el idioma lo fija el snapshot del iPhone).
// Para un texto que nunca se traduce, usa `Text(verbatim:)`.

extension Text {
    init(_ s: String) { self.init(verbatim: Tr.t(s)) }
}

extension Button where Label == Text {
    init(_ title: String, action: @escaping () -> Void) {
        self.init(action: action) { Text(title) }
    }
}

extension View {
    func navigationTitle(_ title: String) -> some View { navigationTitle(Text(title)) }
}
