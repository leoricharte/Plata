#!/usr/bin/env python3
"""Genera PlataApp/Plata/Resources/tr_en.json (pares español → inglés) para el traductor Tr.swift.
Fuentes: los diccionarios de la web (dev/app/src/tr/*.txt, columnas es y en) y extras_en.txt (textos que solo existen en la app nativa;
gana lo que esté en extras). Formato de línea: «es ¦ en». Ejecutar desde cualquier carpeta; vuelve a escribir el JSON."""
import json, os, glob

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(HERE, "..", "..", "PlataApp", "Plata", "Resources", "tr_en.json")


def rows(path):
    out = []
    for ln in open(path, encoding="utf-8").read().split("\n"):
        ln = ln.strip()
        if not ln or ln.startswith("#"):
            continue
        p = [x.strip() for x in ln.split(" ¦ ")]
        if len(p) >= 2 and p[0] and p[1]:
            out.append([p[0], p[1]])
    return out


def main():
    data = []
    for f in sorted(glob.glob(os.path.join(ROOT, "dev", "app", "src", "tr", "*.txt"))):
        data += rows(f)
    n_web = len(data)
    extras = os.path.join(HERE, "extras_en.txt")
    if os.path.exists(extras):
        data += rows(extras)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, separators=(",", ":"))
    print("filas web:", n_web, "· extras:", len(data) - n_web, "→", os.path.normpath(OUT))


main()
