#!/usr/bin/env bash
# Deja una Mac nueva lista para trabajar en la app nativa de Plata.
# Uso (una sola vez):  bash swift/tools/setup-mac.sh
set -euo pipefail
cd "$(dirname "$0")/.."

echo "→ Comprobando Xcode…"
xcodebuild -version >/dev/null 2>&1 || { echo "Falta Xcode: instálalo desde la App Store, ábrelo una vez y acepta la licencia."; exit 1; }
sudo xcodebuild -license accept 2>/dev/null || true
xcodebuild -runFirstLaunch 2>/dev/null || true

echo "→ Comprobando XcodeGen…"
if ! command -v xcodegen >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then brew install xcodegen
  else echo "Falta Homebrew (https://brew.sh). Instálalo y vuelve a correr este script."; exit 1; fi
fi

echo "→ Probando el núcleo (PlataCore)…"
(cd PlataCore && swift test 2>&1 | tail -5)

echo "→ Generando el proyecto…"
(cd PlataApp && xcodegen)

echo "→ Compilando para el simulador…"
(cd PlataApp && xcodebuild build -project Plata.xcodeproj -scheme Plata \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -3)

echo "✓ Listo. Abre swift/PlataApp/Plata.xcodeproj y dale ▶."
