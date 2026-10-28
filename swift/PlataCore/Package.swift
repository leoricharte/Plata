// swift-tools-version: 6.0
import PackageDescription

// PlataCore: el "órgano" compartido de Plata en Swift. Sin interfaz: formato del perfil, cifrado, combinación y sincronización,
// con los mismos resultados que la web (dev/app/src/app.html). Sirve igual para iPhone, iPad, Mac y Apple Watch.
let package = Package(
    name: "PlataCore",
    platforms: [.iOS(.v18), .macOS(.v15), .watchOS(.v11), .visionOS(.v2)],
    products: [
        .library(name: "PlataCore", targets: ["PlataCore"]),
    ],
    targets: [
        .target(name: "PlataCore"),
        .testTarget(
            name: "PlataCoreTests",
            dependencies: ["PlataCore"],
            resources: [.copy("Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v5]   // concurrencia estricta de Swift 6 más adelante; por ahora modo Swift 5
)
