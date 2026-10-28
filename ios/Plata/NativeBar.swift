import SwiftUI
import UIKit

/// Vidrio: Liquid Glass real en iOS 26+, vidrio esmerilado (material) en versiones anteriores.
struct GlassBackground<S: Shape>: ViewModifier {
    let shape: S
    var interactive = false
    var tint: Color? = nil

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            let base = tint.map { Glass.regular.tint($0) } ?? Glass.regular
            content.glassEffect(interactive ? base.interactive() : base, in: shape)
        } else {
            content
                .background(tint.map { AnyShapeStyle($0) } ?? AnyShapeStyle(Material.ultraThinMaterial), in: shape)
                .overlay(shape.stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.09), radius: 15, x: 0, y: 8)
        }
    }
}

/// En iOS 26+ agrupa las piezas de vidrio para que se fundan y se muevan juntas.
struct GlassGroup<Content: View>: View {
    let content: Content
    init(@ViewBuilder _ content: () -> Content) { self.content = content() }

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 14) { content }
        } else {
            content
        }
    }
}

/// Barra de pestañas, botón "+" y engranaje, dibujados en nativo sobre la web.
/// Cada pieza se coloca donde la web tiene su control (que está oculto pero sigue su CSS), con su misma opacidad.
struct NativeBar: View {
    let state: WebState
    let perform: (WebAction) -> Void
    let setValue: (Int, Double) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            bars
            // El menú del + va fuera del grupo de vidrio para que no se funda con el botón
            if let m = state.menu { NativeMenuPanel(m: m, perform: perform) }
        }
    }

    private var bars: some View {
        GlassGroup {
            ZStack(alignment: .topLeading) {
                ForEach(state.btns) { b in nativeButton(b) }
                // Cuando la web oculta un control (opacidad ~0) se quita del todo: el vidrio de iOS 26 no siempre respeta .opacity(0)
                if state.bar.isUsable && state.bar.o > 0.02 { pill }
                if state.plus.isUsable && state.plus.o > 0.02 {
                    roundButton(state.plus, asset: "btn-plus", sf: "plus", label: state.plusLabel, action: .plus)
                }
                if state.gear.isUsable && state.gear.o > 0.02 {
                    roundButton(state.gear, asset: "btn-gear", sf: "gearshape", label: state.gearLabel, action: .gear, dot: state.gdot)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    // MARK: botones de la web que pasan a nativo

    @ViewBuilder
    private func nativeButton(_ b: NativeBtn) -> some View {
        if b.box.isUsable && b.box.o > 0.02 {
            if b.kind == "switch" {
                NativeSwitch(b: b, perform: perform)
            } else if b.kind == "slider" {
                NativeSlider(b: b, setValue: setValue)
            } else {
                glassButton(b)
            }
        }
    }

    private func glassButton(_ b: NativeBtn) -> some View {
        let prominent = b.kind == "prominent"
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            perform(.nid(b.id))
        } label: {
            Group {
                if b.kind == "icon" {
                    Image(systemName: b.symbol).font(.system(size: 17, weight: .semibold))
                } else {
                    Text(b.label).font(.system(size: 18, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                }
            }
            .frame(width: b.box.w, height: b.box.h)
            .foregroundStyle(prominent ? Color(.systemBackground) : Color.primary)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .modifier(NativeShape(circle: b.kind == "icon", tint: prominent ? Color(.label) : nil))
        .opacity(b.box.o)
        .accessibilityLabel(b.label.isEmpty ? b.symbol : b.label)
        .position(b.box.center)
    }

    // MARK: pestañas

    private var pill: some View {
        HStack(spacing: 2) {
            ForEach(TabKey.allCases) { key in tabButton(key) }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(width: state.bar.w, height: state.bar.h)
        .modifier(GlassBackground(shape: Capsule(), interactive: true))
        .opacity(state.bar.o)
        .allowsHitTesting(state.bar.o > 0.5)
        .position(state.bar.center)
    }

    private func tabButton(_ key: TabKey) -> some View {
        let active = state.on == key.rawValue
        let label = state.labels[key.rawValue] ?? key.rawValue.capitalized
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            perform(.tab(key))
        } label: {
            VStack(spacing: 2) {
                icon("tab-\(key.rawValue)-\(active ? "fill" : "line")", sf: active ? key.sfFill : key.sfLine)
                    .frame(width: 24, height: 24)
                if !state.compact {
                    Text(label)
                        .font(.system(size: 10, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(active ? Color.accentColor : Color(.secondaryLabel))
            .background {
                if active { Capsule().fill(Color.primary.opacity(0.08)) }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    // MARK: botones redondos

    private func roundButton(_ b: Box, asset: String, sf: String, label: String, action: WebAction, dot: Int = 0) -> some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            perform(action)
        } label: {
            icon(asset, sf: sf)
                .frame(width: 24, height: 24)
                .frame(width: b.w, height: b.h)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.primary)
        .modifier(GlassBackground(shape: Circle(), interactive: true))
        .overlay(alignment: .topTrailing) { badge(dot) }
        .opacity(b.o)
        .allowsHitTesting(b.o > 0.5)
        .accessibilityLabel(label)
        .position(b.center)
    }

    @ViewBuilder
    private func badge(_ kind: Int) -> some View {
        if kind > 0 {
            Circle()
                .fill(kind == 2 ? Color(red: 0.843, green: 0.0, blue: 0.082) : Color(red: 1.0, green: 0.584, blue: 0.0))
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                .offset(x: -1, y: 1)
        }
    }

    // MARK: iconos (Remix por defecto; SF Symbols con NativeIcons.useSFSymbols)

    @ViewBuilder
    private func icon(_ asset: String, sf: String) -> some View {
        if NativeIcons.useSFSymbols {
            Image(systemName: sf).font(.system(size: 20, weight: .medium))
        } else {
            Image(asset).renderingMode(.template).resizable().scaledToFit()
        }
    }
}

/// Vidrio con forma de círculo (iconos) o cápsula (texto).
struct NativeShape: ViewModifier {
    let circle: Bool
    var tint: Color?

    @ViewBuilder
    func body(content: Content) -> some View {
        if circle {
            content.modifier(GlassBackground(shape: Circle(), interactive: true, tint: tint))
        } else {
            content.modifier(GlassBackground(shape: Capsule(), interactive: true, tint: tint))
        }
    }
}

/// Interruptor nativo (en iOS 26 trae su propio vidrio). El valor se muestra al instante y la web lo confirma.
struct NativeSwitch: View {
    let b: NativeBtn
    let perform: (WebAction) -> Void
    @State private var on = false

    var body: some View {
        Toggle("", isOn: Binding(get: { on }, set: { new in
            on = new
            perform(.nid(b.id))
        }))
        .labelsHidden()
        .tint(Color.accentColor)
        .disabled(b.dis)
        .opacity(b.box.o)
        .position(b.box.center)
        .onAppear { on = b.chk }
        .onChange(of: b.chk) { _, new in on = new }
    }
}

/// Slider nativo: arrastra el valor al input original de la web.
struct NativeSlider: View {
    let b: NativeBtn
    let setValue: (Int, Double) -> Void
    @State private var v = 0.0
    @State private var editing = false

    var body: some View {
        let lo = b.lo
        let hi = max(b.hi, b.lo + 0.0001)
        return Slider(value: Binding(get: { v }, set: { new in
            v = new
            setValue(b.id, new)
        }), in: lo...hi, onEditingChanged: { editing = $0 })
        .tint(Color.accentColor)
        .frame(width: b.box.w)
        .opacity(b.box.o)
        .position(b.box.center)
        .onAppear { v = b.val }
        .onChange(of: b.val) { _, new in if !editing { v = new } }
    }
}

/// Menú del «+» en vidrio, con SF Symbols. Se coloca donde la web abrió el suyo.
struct NativeMenuPanel: View {
    let m: NativeMenu
    let perform: (WebAction) -> Void
    @State private var shown = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(m.items) { it in
                if it.sep {
                    Divider().padding(.horizontal, 18).padding(.vertical, 6)
                } else {
                    row(it)
                }
            }
        }
        .padding(.vertical, 8)
        .frame(width: m.box.w)
        .modifier(GlassBackground(shape: RoundedRectangle(cornerRadius: 30, style: .continuous)))
        .scaleEffect(shown ? 1 : 0.85, anchor: m.up ? .bottomTrailing : .topTrailing)
        .opacity(shown ? 1 : 0)
        .padding(.leading, m.box.x)
        .padding(m.up ? .bottom : .top, m.up ? max(0, m.vh - (m.box.y + m.box.h)) : m.box.y)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: m.up ? .bottomLeading : .topLeading)
        .onAppear { withAnimation(.smooth(duration: 0.28)) { shown = true } }
    }

    private func row(_ it: MenuItem) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            perform(.nid(it.id))
        } label: {
            HStack(spacing: 14) {
                Image(systemName: it.symbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(it.title).font(.system(size: 17)).foregroundStyle(Color.primary)
                    Text(it.sub).font(.system(size: 13)).foregroundStyle(Color.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
