import SwiftUI
import PhotosUI
import PlataCore

/// Fila de foto de «Editar perfil» (`photoRowHTML`): el avatar grande y «Añadir/Cambiar foto» · «Quitar».
struct PhotoRow: View {
    @Environment(AppModel.self) private var model
    @State private var picking = false
    @State private var item: PhotosPickerItem?
    @State private var cropSource: CropRequest?

    struct CropRequest: Identifiable {
        let id = UUID()
        var image: UIImage
        var crop: PhotoCrop?
    }

    var body: some View {
        let has = model.avatarImage != nil
        VStack(spacing: 8) {
            Button {
                if has, let src = model.photoSource { cropSource = CropRequest(image: src, crop: model.photoCrop) } else { picking = true }
            } label: {
                AvatarView(size: 128)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Foto de perfil")
            HStack(spacing: 18) {
                Button(has ? "Cambiar foto" : "Añadir foto") { picking = true }
                    .font(.inter(15)).foregroundStyle(Brand.accent)
                if has {
                    Button("Quitar") { model.removePhoto() }
                        .font(.inter(15)).foregroundStyle(Brand.lossText)
                }
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6).padding(.bottom, 14)
        .photosPicker(isPresented: $picking, selection: $item, matching: .images)
        .onChange(of: item) { _, new in
            guard let new else { return }
            Task {
                if let data = try? await new.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                    cropSource = CropRequest(image: PhotoCodec.fitted(img), crop: nil)
                }
                item = nil
            }
        }
        .sheet(item: $cropSource) { req in
            CropEditor(image: req.image, crop: req.crop) { photo, crop in
                if let p = PhotoCodec.dataURL(photo, quality: 0.82), let s = PhotoCodec.dataURL(req.image, quality: 0.85) {
                    model.setPhoto(photo: p, source: s, crop: crop)
                }
            }
        }
    }
}

/// «Ajustar recorte» (`cropOpen`): arrastra para mover y usa el control para acercar.
struct CropEditor: View {
    let image: UIImage
    var crop: PhotoCrop?
    var onDone: (UIImage, PhotoCrop) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var z: Double = 1
    @State private var ox: CGFloat = 0
    @State private var oy: CGFloat = 0
    @State private var start: CGSize?
    @State private var loaded = false

    private let V: CGFloat = 280
    private let P: CGFloat = 236

    private var s0: CGFloat { P / min(image.size.width, image.size.height) }

    private func clamped(_ x: CGFloat, _ y: CGFloat, z: Double) -> (CGFloat, CGFloat) {
        let sc = s0 * CGFloat(z)
        let mx = max(0, (image.size.width * sc - P) / 2), my = max(0, (image.size.height * sc - P) / 2)
        return (max(-mx, min(mx, x)), max(-my, min(my, y)))
    }

    var body: some View {
        let sc = s0 * CGFloat(z)
        VStack(spacing: 0) {
            Text("Ajustar recorte").font(.inter(17, .semibold)).padding(.top, 20)
            ZStack {
                Color(hex: "#111111")
                Image(uiImage: image).resizable()
                    .frame(width: image.size.width * sc, height: image.size.height * sc)
                    .offset(x: ox, y: oy)
                Canvas { ctx, size in
                    var dim = Path(CGRect(origin: .zero, size: size))
                    dim.addEllipse(in: CGRect(x: (V - P) / 2, y: (V - P) / 2, width: P, height: P))
                    ctx.fill(dim, with: .color(.black.opacity(0.55)), style: FillStyle(eoFill: true))
                    ctx.stroke(Path(ellipseIn: CGRect(x: (V - P) / 2 + 1, y: (V - P) / 2 + 1, width: P - 2, height: P - 2)), with: .color(.white.opacity(0.85)), lineWidth: 2)
                }
                .allowsHitTesting(false)
            }
            .frame(width: V, height: V)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(Rectangle())
            .gesture(DragGesture()
                .onChanged { g in
                    let b = start ?? CGSize(width: ox, height: oy)
                    start = b
                    let c = clamped(b.width + g.translation.width, b.height + g.translation.height, z: z)
                    ox = c.0; oy = c.1
                }
                .onEnded { _ in start = nil })
            .padding(.top, 14).padding(.bottom, 12)
            Text("Arrastra para mover y usa el control para acercar.")
                .font(.inter(14)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(.bottom, 8)
            Slider(value: $z, in: 1...4, step: 0.01).tint(Brand.accent).padding(.horizontal, 24).padding(.bottom, 14)
                .accessibilityLabel("Acercar")
                .onChange(of: z) { _, new in
                    let c = clamped(ox, oy, z: new)
                    ox = c.0; oy = c.1
                }
            Divider()
            HStack(spacing: 0) {
                Button("Cancelar") { dismiss() }.frame(maxWidth: .infinity)
                Divider().frame(height: 48)
                Button("Listo") { finish() }.fontWeight(.bold).frame(maxWidth: .infinity)
            }
            .font(.inter(17)).frame(height: 48)
        }
        .frame(maxWidth: .infinity)
        .presentationDetents([.height(520)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(28)
        .presentationBackground(Color(.secondarySystemGroupedBackground))
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let c = crop, c.z >= 1, c.z <= 4 {
                z = c.z
                let k = clamped(CGFloat(c.x) * P, CGFloat(c.y) * P, z: c.z)
                ox = k.0; oy = k.1
            }
        }
    }

    private func finish() {
        let sc = s0 * CGFloat(z)
        let side = P / sc
        let w = image.size.width, h = image.size.height
        let rect = CGRect(x: w / 2 - ox / sc - side / 2, y: h / 2 - oy / sc - side / 2, width: side, height: side)
        let out = PhotoCodec.square(image, from: rect)
        func r3(_ v: CGFloat) -> Double { (Double(v / P) * 1000).rounded() / 1000 }
        onDone(out, PhotoCrop(x: r3(ox), y: r3(oy), z: (z * 100).rounded() / 100))
        dismiss()
    }
}
