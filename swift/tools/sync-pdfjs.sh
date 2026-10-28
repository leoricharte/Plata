#!/usr/bin/env bash
# Copia a la app de iOS EL MISMO lector de PDF de la web (una sola fuente de verdad):
#   dev/vendor/pdfjs/{pdf.mjs,pdf.worker.mjs,LICENSE}  y  dev/app/src/core/nazca/pdf.js  →  PlataCore/Sources/PlataCore/pdfjs/
# Uso:  bash swift/tools/sync-pdfjs.sh          copia
#       bash swift/tools/sync-pdfjs.sh --check  falla si las copias no son idénticas a la web (lo corre la CI)
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
dest="$root/swift/PlataCore/Sources/PlataCore/pdfjs"
pairs=(
  "dev/vendor/pdfjs/pdf.mjs:pdf.mjs"
  "dev/vendor/pdfjs/pdf.worker.mjs:pdf.worker.mjs"
  "dev/vendor/pdfjs/LICENSE:LICENSE"
  "dev/app/src/core/nazca/pdf.js:nazca-pdf.js"
)
mkdir -p "$dest"
bad=0
for p in "${pairs[@]}"; do
  src="$root/${p%%:*}"; out="$dest/${p##*:}"
  if [ "${1:-}" = "--check" ]; then
    cmp -s "$src" "$out" || { echo "DESACTUALIZADO: ${p##*:} (corre bash swift/tools/sync-pdfjs.sh)"; bad=1; }
  else
    cp "$src" "$out"; echo "copiado ${p##*:}"
  fi
done
exit $bad
