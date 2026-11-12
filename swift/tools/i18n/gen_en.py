#!/usr/bin/env python3
"""Genera PlataApp/Plata/Resources/tr_en.json (pares español → inglés) para el traductor Tr.swift.
Fuentes: los diccionarios de la web (dev/app/src/tr/NN.json, columnas es y en) y extras_en.txt (textos que solo existen en la app nativa;
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
        p = [x.strip().replace("\\n", "\n") for x in ln.split(" ¦ ")]   # «\n» escrito en el archivo es un salto de línea
        if len(p) >= 2 and p[0] and p[1]:
            out.append([p[0], p[1]])
    return out


def singular_keys(data):
    """Una frase escrita con el número puesto («más de 10 años») se busca con el plural ya en singular («más de {0} año»), y con la clave
    tal cual nunca coincidía. Devuelve filas extra con esa forma (sin pisar una fila genérica) y los números de la traducción como marcadores."""
    import re, sys
    sys.path.insert(0, HERE)
    import tr_ref
    have = set()
    lit = []
    for es, en in data:
        if re.search(r"\d", es) and not re.search(r"\{\d+\}", es):
            nums = []
            k = tr_ref.RE_NUM.sub(lambda m: (nums.append(m[0]) or "{%d}" % (len(nums) - 1)), es)
            have.add(k); lit.append((k, en, nums))
        else:
            have.add(es)
    out = []
    for k, en, nums in lit:
        k2 = tr_ref.RE_PL.sub(lambda m: m[1] + " " + tr_ref.PL_SING[m[2].lower()], k)
        if k2 == k or k2 in have:
            continue
        i = [0]; ok = [True]
        def rep(m):
            if i[0] < len(nums) and m[0] == nums[i[0]]:
                i[0] += 1; return "{%d}" % (i[0] - 1)
            ok[0] = False; return m[0]
        v2 = tr_ref.RE_NUM.sub(rep, en)
        out.append([k2, v2 if ok[0] and i[0] == len(nums) else en]); have.add(k2)
    return out


def main():
    data = []
    # la web guarda sus traducciones en tr/NN.json: una fila por frase, [es, en, ja, it, fr, hr] (+ nota opcional)
    for f in sorted(glob.glob(os.path.join(ROOT, "dev", "app", "src", "tr", "[0-9]*.json"))):
        for r in json.load(open(f, encoding="utf-8")):
            if isinstance(r, list) and len(r) >= 2 and str(r[0]).strip() and str(r[1]).strip():
                data.append([str(r[0]).strip(), str(r[1]).strip()])
    n_web = len(data)
    extras = os.path.join(HERE, "extras_en.txt")
    if os.path.exists(extras):
        data += rows(extras)
    data += singular_keys(data)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, separators=(",", ":"))
    print("filas web:", n_web, "· extras:", len(data) - n_web, "→", os.path.normpath(OUT))


main()
