import SwiftUI
import UniformTypeIdentifiers
import PlataCore

/// La pantalla completa de Plata Cloud: correo → código → frase → recorrido, y también ver la frase, borrar datos o la cuenta,
/// reemplazar la nube con un archivo y esperar la aprobación de otro dispositivo (`clSheet` de la web).
struct CloudFlowHost: View {
    @Environment(CloudModel.self) private var cloud
    var body: some View {
        if let f = cloud.flow { CloudFlowView(flow: f) } else { Color.clear }
    }
}

struct CloudFlowView: View {
    @Bindable var flow: CloudFlow
    @Environment(CloudModel.self) private var cloud
    @Environment(AppModel.self) private var model

    @State private var email = ""
    @State private var code = ""
    @State private var phrase = ""
    @State private var answers = ["", "", ""]
    @State private var wait = 0
    @State private var counting = 0
    @State private var picking = false
    @State private var pickForTour = false
    @FocusState private var focus: Bool

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            switch flow.step {
            case .tour: CloudTourView(flow: flow, pick: { pickForTour = true; picking = true })
            case .first: FirstPickView()
            default: page
            }
        }
        .fileImporter(isPresented: $picking, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            if let d = try? Data(contentsOf: url) { cloud.fileChosen(d, tour: pickForTour) } else { cloud.say("No pude leer ese archivo de perfil") }
        }
        .onChange(of: flow.step) { _, _ in code = ""; phrase = ""; answers = ["", "", ""]; counting = 0 }
        .onAppear { email = flow.email }
    }

    // MARK: andamio

    private var page: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { cloud.closeFlow() } label: {
                    Image(systemName: "xmark").font(.system(size: 17, weight: .semibold)).foregroundStyle(.primary)
                        .frame(width: 44, height: 44).modifier(GlassCircle())
                }
                .buttonStyle(.plain).opacity(flow.locked ? 0.35 : 1).disabled(flow.locked)
                .accessibilityLabel("Cerrar")
            }
            .padding(.horizontal, 16).padding(.top, 8)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if flow.step == .email || flow.step == .nolist || flow.step == .listed || flow.step == .linkwait {
                        CloudMark(height: 70).padding(.top, 4).padding(.bottom, 4).frame(maxWidth: .infinity)
                    }
                    content
                }
                .padding(.horizontal, 24).padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            VStack(spacing: 10) { footer }
                .padding(.horizontal, 24).padding(.bottom, 12).padding(.top, 8)
        }
    }

    private func head(_ title: String, _ sub: Text? = nil) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.inter(32, .bold)).tracking(-0.8).fixedSize(horizontal: false, vertical: true)
            if let sub { sub.font(.inter(16)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
        }
        .padding(.top, 14).padding(.bottom, 14)
    }

    private func err() -> some View {
        Text(flow.err).font(.inter(13)).foregroundStyle(Brand.lossText).frame(minHeight: 18, alignment: .leading).padding(.top, 8)
    }

    private func field(_ placeholder: String, text: Binding<String>, email: Bool = false, code: Bool = false) -> some View {
        let kb: UIKeyboardType = email ? .emailAddress : (code ? .numberPad : .asciiCapable)
        let tct: UITextContentType? = email ? .emailAddress : (code ? .oneTimeCode : nil)
        return TextField(placeholder, text: text)
            .font(.inter(code ? 28 : 18, code ? .bold : .regular))
            .multilineTextAlignment(code ? .center : .leading)
            .keyboardType(kb)
            .textContentType(tct)
            .textInputAutocapitalization(.never).autocorrectionDisabled()
            .focused($focus)
            .padding(.horizontal, 16).frame(minHeight: 56)
            .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.top, 8)
    }

    private func mail() -> some View {
        Text(verbatim: flow.email).font(.inter(17, .semibold)).padding(.horizontal, 16).frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func words() -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(Array(flow.words.enumerated()), id: \.offset) { i, w in
                HStack(spacing: 10) {
                    Text(verbatim: "\(i + 1)").font(.inter(13)).foregroundStyle(.secondary).frame(width: 18, alignment: .trailing)
                    Text(verbatim: w).font(.inter(18, .bold))
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14).frame(minHeight: 52)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color(.separator).opacity(0.5)))
            }
        }
        .padding(.top, 10)
    }

    private func quizFields() -> some View {
        VStack(spacing: 0) {
            ForEach(Array(flow.pos.enumerated()), id: \.offset) { i, p in
                field(Tr.t("Palabra") + " \(p + 1)", text: Binding(get: { answers.indices.contains(i) ? answers[i] : "" }, set: { if answers.indices.contains(i) { answers[i] = $0 } }))
            }
        }
    }

    private func go(_ title: String, _ kind: CloudButtonStyle.Kind = .primary, disabled: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if flow.busy { ProgressView().tint(kind == .alt ? Color.primary : Color.white) } else { Text(title) }
        }
        .buttonStyle(CloudButtonStyle(kind: kind)).disabled(flow.busy || disabled)
    }

    private func alt(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(title, action: action).buttonStyle(CloudButtonStyle(kind: .alt)).disabled(flow.busy)
    }

    // MARK: pasos

    @ViewBuilder private var content: some View {
        switch flow.step {
        case .email:
            head("Plata Cloud", Text("Escribe tu correo. Si ya tienes acceso, te mandamos un código para entrar, sin contraseña. Si aún no, te apuntamos a la lista de espera."))
            field("correo@ejemplo.com", text: $email, email: true)
            err()
        case .nolist:
            head("Plata Cloud es solo por invitación", Text("Todavía estamos en marcha blanca y vamos abriendo cupos de a poco. Este correo aún no tiene acceso, pero puedes apuntarte a la lista de espera y te avisamos cuando te toque."))
            mail(); err()
        case .listed:
            head(flow.fresh ? "Listo, estás en la lista" : "Ya estás en la lista de espera", Text("Te avisaremos por correo cuando abramos tu cupo. No tienes que hacer nada más. Si recibes una invitación, vuelve aquí y entra con este mismo correo."))
            mail()
        case .linkwait:
            head("Aprueba desde otro dispositivo", Text(flow.linkCode.isEmpty ? "Abre Plata en un dispositivo donde ya tengas sesión: en el Resumen verás la solicitud. En unos segundos aparecerá un código aquí y allá. También te mandamos un aviso por correo." : "En tu otro dispositivo apareció un código. Apruébalo solo si es exactamente este:"))
            if !flow.linkCode.isEmpty {
                Text(verbatim: String(flow.linkCode.prefix(3)) + " " + String(flow.linkCode.suffix(3)))
                    .font(.system(size: 54, weight: .bold, design: .rounded)).monospacedDigit().frame(maxWidth: .infinity).padding(.vertical, 16)
            }
            HStack(spacing: 10) { ProgressView(); Text(flow.linkCode.isEmpty ? "Esperando al otro dispositivo…" : "Esperando aprobación…").font(.inter(15)).foregroundStyle(.secondary) }
                .frame(maxWidth: .infinity).padding(.top, 8)
            err()
        case .code:
            head("Revisa tu correo", Text("Te enviamos un código. Vence en 10 minutos. Si no llega, revisa spam."))
            mail()
            field("000 000", text: $code, code: true).onChange(of: code) { _, v in let d = String(v.filter(\.isNumber).prefix(6)); if d != v { code = d } }
            err()
        case .newkey:
            head("Tu frase de recuperación", Text("Estas 12 palabras son la llave de tus datos. ") + Text("Nadie más puede recuperarlas, ni nosotros.").bold() + Text(" Anótalas en papel y guárdalas en un lugar seguro. Si pierdes tus dispositivos y la frase, tus datos de la nube no se podrán abrir."))
            words()
        case .quiz:
            head("Confírmala", Text("Para asegurarnos de que la anotaste, escribe estas palabras."))
            quizFields(); err()
        case .enter:
            head("Escribe tu frase", Text("Esta cuenta ya existe. Escribe las 12 palabras de tu frase de recuperación para abrir tus datos en este dispositivo."))
            field("palabra1 palabra2 palabra3 …", text: $phrase)
            Text("Sabemos que es algo tedioso, pero así tus datos se quedan cifrados y seguros: solo tú puedes abrirlos.").font(.inter(13)).foregroundStyle(.secondary).padding(.top, 10)
            err()
        case .show:
            head("Tu frase de recuperación", Text("Guárdala en papel y no la compartas con nadie."))
            words()
        case .delcode:
            head("Confirma el borrado", Text("Enviamos un código a tu correo para confirmar. Escríbelo para borrar tu cuenta de Plata Cloud."))
            Text("Esto borrará tu cuenta y toda tu copia en la nube. No lo hagas si no deseas perder tus datos.").font(.inter(14, .heavy)).foregroundStyle(Brand.lossText)
            codeField()
        case .replaceauth:
            head("¿¡Quién anda ahí!?", Text("Enviamos un código a tu correo. Escríbelo para poder reemplazar tu copia en la nube con un archivo de perfil."))
            codeField()
        case .wipeauth:
            head("¿¡Quién anda ahí!?", Text("Enviamos un código a tu correo. Escríbelo para borrar tus datos también de la nube."))
            Text("Esto vaciará tu copia en la nube y tus otros dispositivos. No se puede deshacer.").font(.inter(14, .heavy)).foregroundStyle(Brand.lossText)
            codeField()
        case .wipeq:
            if counting > 0 {
                head("Borrando en \(counting) s…", Text("Se borrarán los datos de tu nube. Toca Cancelar si fue sin querer."))
            } else {
                head("Confirma que eres tú", Text("Para borrar los datos de tu nube, escribe estas palabras de tu frase de recuperación."))
                quizFields(); err()
            }
        case .replacepick:
            head("Elige tu archivo", Text("Código confirmado. Ahora elige el archivo de perfil con el que quieres reemplazar tu copia en la nube."))
            Text("Esto borrará tu última sincronización. No lo hagas si no deseas perder tus datos.").font(.inter(14, .heavy)).foregroundStyle(Brand.lossText)
            err()
        case .preview:
            head("¿Reconoces a esta persona?", Text("Revisa que sea el correcto antes de subirlo. Reemplazará lo que tienes en la nube."))
            if let p = flow.pend { CloudPreview(pend: p) }
            err()
        case .done:
            head("Listo", Text("Tu cuenta está lista. Tus datos se sincronizan cifrados entre tus dispositivos."))
        case .tour, .first:
            EmptyView()
        }
    }

    private func codeField() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            field("000 000", text: $code, code: true).onChange(of: code) { _, v in let d = String(v.filter(\.isNumber).prefix(6)); if d != v { code = d } }
            err()
        }
    }

    @ViewBuilder private var footer: some View {
        switch flow.step {
        case .email:
            go("Enviarme el código") { cloud.sendCode(email) }
            alt("Pedir aprobación desde otro dispositivo") { cloud.startLink(email) }
        case .nolist:
            go("Unirme a la lista de espera") { cloud.joinWaitlist() }
            alt("Usar otro correo") { cloud.backToEmail() }
        case .listed:
            go("Entendido") { cloud.closeFlow() }
            alt("Usar otro correo") { cloud.backToEmail() }
        case .linkwait:
            alt("Usar el código del correo") { cloud.cancelLink() }
            alt("Cancelar") { cloud.cancelLink() }
        case .code:
            go("Entrar") { cloud.verify(code) }
            alt("Enviar otro código") { cloud.sendCode(flow.email, resend: true) }
        case .newkey:
            Button(action: { cloud.phraseSaved() }) { Text(wait > 0 ? Tr.t("Ya las guardé") + " (\(wait))" : Tr.t("Ya las guardé")) }
                .buttonStyle(CloudButtonStyle()).disabled(wait > 0)
                .task(id: flow.step) {
                    wait = 5; flow.locked = true
                    while wait > 0 { try? await Task.sleep(for: .seconds(1)); wait -= 1 }
                    flow.locked = false
                }
        case .quiz:
            go("Confirmar") { cloud.confirmQuiz(answers) }
            alt("Ver la frase otra vez") { cloud.backToPhrase() }
        case .enter:
            go("Abrir mis datos") { cloud.enterPhrase(phrase) }
        case .show:
            alt("Cerrar") { cloud.closeFlow() }
        case .delcode:
            go("Borrar mi cuenta", .danger) { cloud.deleteAccount(code) }
            alt("Cancelar") { cloud.closeFlow() }
        case .replaceauth:
            go("Continuar") { cloud.checkReplaceCode(code) }
            alt("Cancelar") { cloud.closeFlow() }
        case .wipeauth:
            go("Borrar mis datos", .danger) { cloud.wipeWithCode(code) { cloud.wipeRun?(); cloud.wipeRun = nil } }
            alt("Cancelar") { cloud.closeFlow() }
        case .wipeq:
            if counting > 0 {
                alt("Cancelar") { counting = 0; cloud.closeFlow() }
                    .task(id: counting) {
                        guard counting > 0 else { return }
                        try? await Task.sleep(for: .seconds(1))
                        guard counting > 0 else { return }
                        counting -= 1
                        if counting == 0 { await cloud.wipeCloudNow() }
                    }
            } else {
                go("Borrar datos de la nube", .danger) { if cloud.wipeQuizOK(answers) { counting = 5 } }
                alt("Cancelar") { cloud.closeFlow() }
            }
        case .replacepick:
            go("Elegir archivo", .danger) { pickForTour = false; picking = true }
            alt("Cancelar") { cloud.closeFlow() }
        case .preview:
            if flow.pend?.mode == .tour || flow.promote {
                go(flow.promote ? "Sí, subir esta copia" : "Sí, subir este archivo") { cloud.uploadPending() }
                alt(flow.promote ? "Cancelar" : "Cancelar") { flow.promote ? cloud.closeFlow() : cloud.previewBack() }
            } else {
                go("Sí, subir este archivo") { cloud.uploadPending() }
                alt("Elegir otro archivo") { pickForTour = false; picking = true }
                alt("Cancelar") { cloud.previewBack() }
            }
        case .done:
            go("Entendido") { cloud.closeFlow() }
        case .tour, .first:
            EmptyView()
        }
    }
}

// MARK: vista previa del archivo

/// «¿Reconoces a esta persona?»: el nombre, el balance, las cuentas y de dónde viene el archivo.
private struct CloudPreview: View {
    let pend: CloudFlow.Pending

    var body: some View {
        let profile = Profile(raw: pend.raw)
        let e = Engine(profile: profile, today: LocalDate.today())
        let s = pend.raw["settings"]
        let name = [Engine.text(s?["first"]), Engine.text(s?["last"])].map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " ")
        let shown = name.isEmpty ? (Engine.text(s?["nick"]).trimmingCharacters(in: .whitespaces).isEmpty ? Tr.t("Sin nombre") : Engine.text(s?["nick"])) : name
        let accs = e.visibleAccounts
        let f = Fmt(currency: e.primaryCurrency, custom: e.customCurrency)
        let more = max(0, Set(accs.map { Engine.text($0["cur"]).isEmpty ? "USD" : Engine.text($0["cur"]) }).count - 1)
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    Text(verbatim: String(shown.prefix(1)).uppercased()).font(.inter(22, .bold)).foregroundStyle(.white)
                        .frame(width: 52, height: 52).background(Brand.accent, in: Circle())
                    Text(verbatim: shown).font(.inter(20, .bold)).lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 12)
                Divider()
                HStack(alignment: .top) {
                    cell("Balance actual", f.whole(e.totalUSD(accs)))
                    cell("Cuentas", "\(accs.count)")
                    cell("Moneda principal", e.primaryCurrency + (more > 0 ? " +\(more)" : ""))
                }
                .padding(.vertical, 12)
                Divider()
                row("iphone", Text("Guardado por última vez en ") + Text(verbatim: pend.plat.isEmpty ? Tr.t("una plataforma no indicada") : pend.plat).bold())
                row("clock", Text(verbatim: pend.at > 0 ? Date(timeIntervalSince1970: pend.at / 1000).formatted(date: .abbreviated, time: .shortened) : Tr.t("Sin fecha")))
            }
            .padding(.horizontal, 16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            Label { Text("Esta vista previa se abre solo en tu dispositivo y solo después de verificar tu correo, para que confirmes que este archivo es tuyo.") } icon: { Image(systemName: "lock.open") }
                .font(.inter(14)).foregroundStyle(.secondary).padding(.horizontal, 4)
        }
        .padding(.top, 8)
    }

    private func cell(_ l: String, _ v: String) -> some View {
        VStack(spacing: 2) {
            Text(l).font(.inter(13)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
            Text(verbatim: v).font(.inter(18, .bold)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private func row(_ symbol: String, _ t: Text) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(Brand.gainText).frame(width: 22)
            t.font(.inter(14))
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }
}

// MARK: ¿qué conservamos?

struct FirstPickView: View {
    @Environment(CloudModel.self) private var cloud

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CloudMark(height: 34).padding(.top, 56)
            Text("¿Qué conservamos?").font(.inter(32, .bold)).tracking(-0.8).padding(.top, 20)
            Text("Tu cuenta ya tiene datos en la nube y este dispositivo también. Elige cómo seguir.").font(.inter(16)).foregroundStyle(.secondary).padding(.top, 10)
            VStack(spacing: 12) {
                opt(.merge, "arrow.triangle.merge", Color(hex: "#22B573"), "Combinar los dos", "Junta lo de este dispositivo y lo de la nube. Es lo más seguro.", rec: true)
                opt(.remote, "icloud", Color(hex: "#4C8DF6"), "Quedarme con la nube", "Reemplaza los datos de este dispositivo.")
                opt(.local, "iphone", Color(hex: "#B98AE6"), "Quedarme con este dispositivo", "Reemplaza la copia de la nube.")
            }
            .padding(.top, 20)
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func opt(_ how: CloudModel.PickHow, _ symbol: String, _ color: Color, _ title: String, _ sub: String, rec: Bool = false) -> some View {
        Button { cloud.pickFirst(how) } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 48, height: 48).background(color, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title).font(.inter(18, .bold)).multilineTextAlignment(.leading)
                        if rec { Text("Recomendado").font(.inter(11, .bold)).foregroundStyle(Brand.gainText).padding(.horizontal, 8).padding(.vertical, 3).background(Brand.gainBg, in: Capsule()) }
                    }
                    Text(sub).font(.inter(14)).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Color(.separator).opacity(0.5)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: recorrido de bienvenida

struct CloudTourView: View {
    @Bindable var flow: CloudFlow
    var pick: () -> Void
    @Environment(CloudModel.self) private var cloud
    @Environment(AppModel.self) private var model
    @State private var drift = false

    private var titles: [String] { ["", "Local o Cloud", "Tu frase de recuperación", "Tus datos"] }
    private var texts: [String] {
        ["",
         "En modo Local tus datos se quedan solo en este dispositivo. En modo Cloud se sincronizan entre todos los que uses. Puedes cambiar de modo cuando quieras desde tu perfil.",
         "Es la única forma de abrir tus datos en un dispositivo nuevo. Si no la guardaste, puedes verla en el menú de tres puntos de tu perfil.",
         model.profile.hasData ? "Encontramos datos en este dispositivo. Se subirán a tu nube, cifrados, para que los tengas en todos tus dispositivos." : "Tu nube está vacía. Si tienes un archivo de perfil guardado, puedes cargarlo ahora."]
    }

    private var hello: String {
        let g = Engine.text(model.engine.data["settings"]?["gender"])
        return g == "m" ? "Bienvenido a la nube" : g == "f" ? "Bienvenida a la nube" : "Te damos la bienvenida a la nube"
    }

    var body: some View {
        let i = min(flow.tour, 3), last = i == 3
        let s = model.engine.data["settings"]
        let nick = [Engine.text(s?["nick"]), Engine.text(s?["first"])].map { $0.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty } ?? ""
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            GeometryReader { geo in
                ForEach(0..<6, id: \.self) { k in
                    let w: CGFloat = [150, 100, 190, 90, 140, 80][k]
                    CloudMark(kind: .cloud, height: w * 0.38).foregroundStyle(Brand.accent)
                        .opacity([0.3, 0.2, 0.24, 0.18, 0.26, 0.16][k])
                        .offset(x: drift ? geo.size.width + 200 : -220, y: geo.size.height * [0.06, 0.22, 0.4, 0.58, 0.76, 0.9][k] * 0.8)
                        .animation(.linear(duration: [46.0, 70, 90, 58, 80, 64][k]).repeatForever(autoreverses: false), value: drift)
                }
            }
            .allowsHitTesting(false).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                HStack { Spacer(); if !last { Button("Omitir") { cloud.tourEnd() }.font(.inter(14, .semibold)).padding(.horizontal, 14).padding(.vertical, 8).background(Color(.secondarySystemFill), in: Capsule()).foregroundStyle(.primary) } }
                    .padding(.horizontal, 16).padding(.top, 8)
                Spacer()
                CloudMark(height: 46)
                if i == 0 {
                    (Text(hello) + (nick.isEmpty ? Text(verbatim: "") : Text(verbatim: ", ") + Text(verbatim: nick).foregroundColor(Brand.accent)))
                        .font(.inter(30, .bold)).tracking(-0.6).padding(.top, 22)
                    Text("Gracias por unirte a Plata Cloud. Ahora:").font(.inter(16)).foregroundStyle(.secondary).padding(.top, 10)
                    VStack(alignment: .leading, spacing: 12) {
                        feat("Tus datos al día en todos tus dispositivos")
                        feat("Cifrado de punta a punta: ni nosotros podemos leerlos")
                        feat("Sin contraseñas: solo un código en tu correo")
                        feat("Opcional: vuelve a Local cuando quieras")
                    }
                    .padding(.top, 16)
                } else {
                    Text(titles[i]).font(.inter(30, .bold)).tracking(-0.6).padding(.top, 22)
                    Text(texts[i]).font(.inter(16)).foregroundStyle(.secondary).padding(.top, 10)
                }
                HStack(spacing: 6) { ForEach(0..<4, id: \.self) { k in Circle().fill(k == i ? Brand.accent : Color(.tertiarySystemFill)).frame(width: 7, height: 7) } }
                    .frame(maxWidth: .infinity).padding(.top, 20)
                VStack(spacing: 10) {
                    if !last { Button("Siguiente") { withAnimation { cloud.tourNext() } }.buttonStyle(CloudButtonStyle()) }
                    else if model.profile.hasData {
                        Button("Subir mis datos") { cloud.tourEnd() }.buttonStyle(CloudButtonStyle())
                        Button("Cargar un archivo de perfil en su lugar") { pick() }.buttonStyle(CloudButtonStyle(kind: .alt))
                    } else {
                        Button("Configurar mi Plata") { cloud.tourSetup() }.buttonStyle(CloudButtonStyle())
                        Button("Cargar archivo de perfil") { pick() }.buttonStyle(CloudButtonStyle(kind: .alt))
                    }
                }
                .padding(.top, 14)
            }
            .padding(.horizontal, 24).padding(.bottom, 16)
        }
        .onAppear { drift = true }
    }

    private func feat(_ t: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white).frame(width: 24, height: 24).background(Brand.accent, in: Circle())
            Text(t).font(.inter(15))
        }
    }
}
