#!/bin/sh
# Copia la app web compilada al proyecto de iOS (ios/Plata/Web) y deja el número de compilación en ios/Build.xcconfig.
# Úsalo cada vez que cambie la app web, antes de compilar en Xcode.
set -e
cd "$(dirname "$0")/.."
python3 dev/app/build.py
rm -rf ios/Plata/Web && mkdir -p ios/Plata/Web/nazca
cp dev/app/out/finanzas.html ios/Plata/Web/index.html
# pdf.js (lector de PDF de Nazca): la app lo carga de nazca/ solo al importar un PDF
cp dev/vendor/pdfjs/pdf.mjs dev/vendor/pdfjs/pdf.worker.mjs dev/vendor/pdfjs/LICENSE ios/Plata/Web/nazca/
BUILD=$(grep -o 'const APP_BUILD = [0-9]*' dev/app/src/app.html | grep -o '[0-9]*$')
echo "CURRENT_PROJECT_VERSION = $BUILD" > ios/Build.xcconfig
echo "ios/Plata/Web listo (compilación $BUILD)"
