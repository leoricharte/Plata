import SwiftUI
import PlataCore

/// «Perfil» en modo lectura (`profileViewHTML`): avatar con aro e insignia, nombre, notas históricas y datos. «Editar» abre el formulario.
struct ProfileView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let e = model.engine
        let s = e.data["settings"]
        let name = [Engine.text(s?["first"]), Engine.text(s?["last"])].map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " ")
        let shown = s?["showGrades"] != .bool(false)
        let counts = shown ? e.gradeCounts() : []
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    ProfileHero()
                    Text(name.isEmpty ? "Tu perfil" : name).font(.inter(24, .bold)).tracking(-0.5).multilineTextAlignment(.center).padding(.top, 12)
                    if !counts.isEmpty { gradeRow(counts) }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 6).padding(.bottom, 18)

                SCard {
                    ForEach(Array(identityRows(s).enumerated()), id: \.offset) { i, r in
                        SettingRow((r.0), first: i == 0) { value(r.1) }
                    }
                }
                LanguageCard(editable: false)
                ThemeCard()
                SCard {
                    SettingRow("Moneda principal", first: true) { value(currency(e, e.primaryCurrency)) }
                    if !e.secondaryCurrency.isEmpty {
                        SettingRow("Segunda moneda") { value(currency(e, e.secondaryCurrency)) }
                    }
                }
                TutorialCard()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Perfil")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Editar") { model.path.append(.profileEdit) }.font(.inter(17)).foregroundStyle(Brand.accent)
            }
        }
    }

    private func gradeRow(_ counts: [(letter: String, count: Int)]) -> some View {
        HStack(spacing: 18) {
            ForEach(Array(counts.enumerated()), id: \.offset) { _, g in
                HStack(spacing: 8) {
                    GradeTile(letter: g.letter, size: 28)
                    Text("\(g.count)").font(.inter(17, .semibold))
                }
            }
        }
        .padding(.top, 12).padding(.bottom, 2)
    }

    private func identityRows(_ s: JSONValue?) -> [(String, String)] {
        var rows: [(String, String)] = []
        let first = Engine.text(s?["first"]), last = Engine.text(s?["last"]), nick = Engine.text(s?["nick"])
        if !first.isEmpty { rows.append(("Nombre", first)) }
        if !last.isEmpty { rows.append(("Apellido", last)) }
        if !nick.isEmpty { rows.append(("Apodo", nick)) }
        let g = Engine.text(s?["gender"])
        rows.append(("Género", g == "m" ? "Masculino" : (g == "f" ? "Femenino" : "Neutro")))
        return rows
    }

    private func currency(_ e: Engine, _ cur: String) -> String {
        "\(cur) (\(model.fmt.symbol(cur).trimmingCharacters(in: .whitespaces)))"
    }

    private func value(_ t: String) -> some View {
        Text(t).font(.inter(17)).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
    }
}
