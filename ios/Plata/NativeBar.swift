import SwiftUI
import UIKit

/// Vidrio: Liquid Glass real en iOS 26+, vidrio esmerilado (material) en versiones anteriores.
struct GlassBackground<S: Shape>: ViewModifier {
    let shape: S
    var interactive = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(interactive ? Glass.regular.interactive() : Glass.regular, in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
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

    var body: some View {
        GlassGroup {
            ZStack(alignment: .topLeading) {
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
