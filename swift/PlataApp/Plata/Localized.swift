import SwiftUI

// Los textos de la app están escritos en español. Estas sobrecargas hacen que `Text("…")`, `Button("…")`,
// `Label("…")`, alertas, etc. pasen por `Tr.t` (el traductor de la web) y salgan en el idioma elegido.
// Para un texto que nunca se traduce (nombres propios de idioma, códigos), usa `Text(verbatim:)`.

extension Text {
    init(_ s: String) { self.init(verbatim: Tr.t(s)) }
}

extension Button where Label == Text {
    init(_ title: String, action: @escaping @MainActor () -> Void) {
        self.init(action: action) { Text(title) }
    }

    init(_ title: String, role: ButtonRole?, action: @escaping @MainActor () -> Void) {
        self.init(role: role, action: action) { Text(title) }
    }
}

extension Label where Title == Text, Icon == Image {
    init(_ title: String, systemImage name: String) {
        self.init { Text(title) } icon: { Image(systemName: name) }
    }
}

extension Section where Parent == Text, Content: View, Footer == EmptyView {
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.init(content: content) { Text(title) }
    }
}

extension Toggle where Label == Text {
    init(_ title: String, isOn: Binding<Bool>) {
        self.init(isOn: isOn) { Text(title) }
    }
}

extension Picker where Label == Text {
    init(_ title: String, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) {
        self.init(selection: selection, content: content) { Text(title) }
    }
}

extension TextField where Label == Text {
    init(_ title: String, text: Binding<String>) {
        self.init(text: text, prompt: Text(title)) { Text(title) }
    }
}

extension View {
    func navigationTitle(_ title: String) -> some View { navigationTitle(Text(title)) }

    func accessibilityLabel(_ label: String) -> some View { accessibilityLabel(Text(label)) }

    func alert<A: View>(_ title: String, isPresented: Binding<Bool>, @ViewBuilder actions: () -> A) -> some View {
        alert(Text(title), isPresented: isPresented, actions: actions)
    }

    func alert<A: View, M: View>(_ title: String, isPresented: Binding<Bool>, @ViewBuilder actions: () -> A, @ViewBuilder message: () -> M) -> some View {
        alert(Text(title), isPresented: isPresented, actions: actions, message: message)
    }

    func confirmationDialog<A: View>(_ title: String, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: () -> A) -> some View {
        confirmationDialog(Text(title), isPresented: isPresented, titleVisibility: titleVisibility, actions: actions)
    }

    func confirmationDialog<A: View, M: View>(_ title: String, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: () -> A, @ViewBuilder message: () -> M) -> some View {
        confirmationDialog(Text(title), isPresented: isPresented, titleVisibility: titleVisibility, actions: actions, message: message)
    }
}
