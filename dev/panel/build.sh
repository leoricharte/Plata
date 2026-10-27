#!/bin/sh
# Empaqueta el motor de Nazca para la pestaña Nazca del panel privado: nazca/engine.js (los mismos archivos que usa la app, en el mismo orden) + pdf.js.
# Córrelo cada vez que cambie un lector, antes de copiar dev/panel/ al repo privado. Lo generado no se sube a este repo (ver .gitignore).
set -e
cd "$(dirname "$0")/../.."
mkdir -p dev/panel/nazca
python3 - <<'PY'
import re, pathlib
src = pathlib.Path("dev/app/build.py").read_text(encoding="utf-8")
m = re.search(r'for n in \(([^)]*)\)\)\)', src)
names = re.findall(r'"([^"]+\.js)"', m.group(1))
base = pathlib.Path("dev/app/src/core/nazca")
out = "\n".join((base / n).read_text(encoding="utf-8") for n in names)
pathlib.Path("dev/panel/nazca/engine.js").write_text(out, encoding="utf-8")
print("engine.js:", len(names), "archivos")
PY
cp dev/vendor/pdfjs/pdf.mjs dev/vendor/pdfjs/pdf.worker.mjs dev/vendor/pdfjs/LICENSE dev/panel/nazca/
echo "listo: dev/panel/nazca/"
