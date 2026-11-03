#!/usr/bin/env python3
"""Genera dev/app/src/js/37-lanzamiento-datos.js con la geometría y el recorrido de la animación de arranque del iPhone, leyéndolos directo de
swift/PlataApp/Plata/PlataLaunchAnimation.swift (rama swift-nativo): así la de Android es EXACTAMENTE la misma y no hay números copiados a mano.
Uso: python3 android/scripts/gen-lanzamiento.py /ruta/a/PlataLaunchAnimation.swift      (el archivo generado se versiona; no hace falta correrlo en el CI)"""
import re, sys, json, os
src = open(sys.argv[1], encoding="utf-8").read()
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "dev", "app", "src", "js", "37-lanzamiento-datos.js")
N = r"(-?\d+(?:\.\d+)?)"
CMD = re.compile(r"p\.move\(to: CGPoint\(x: %s, y: %s\)\)|p\.addLine\(to: CGPoint\(x: %s, y: %s\)\)|p\.addCurve\(to: CGPoint\(x: %s, y: %s\), control1: CGPoint\(x: %s, y: %s\), control2: CGPoint\(x: %s, y: %s\)\)|p\.closeSubpath\(\)" % ((N,) * 10))
def d_of(block):
    out = []
    for m in CMD.finditer(block):
        g = m.groups()
        if g[0] is not None: out.append("M%s %s" % (g[0], g[1]))
        elif g[2] is not None: out.append("L%s %s" % (g[2], g[3]))
        elif g[4] is not None: out.append("C%s %s %s %s %s %s" % (g[6], g[7], g[8], g[9], g[4], g[5]))
        else: out.append("Z")
    return "".join(out)
def block(name):
    i = src.index("static let %s: Path = {" % name); j = src.index("}()", i); return src[i:j]
logo, arrow, head = d_of(block("logo")), d_of(block("arrow")), d_of(block("headPoly"))
i = src.index("static let letterPaths"); j = src.index("/// Punta de flecha", i); lp = src[i:j]
letters = []
for m in re.finditer(r"\(path: \{(.*?)\}\(\), pivot: CGPoint\(x: %s, y: %s\), t0: %s\)" % (N, N, N), lp, re.S):
    letters.append({"d": d_of(m.group(1)), "pivot": [float(m.group(2)), float(m.group(3))], "t0": float(m.group(4))})
hp = re.search(r"static let headPivot = CGPoint\(x: %s, y: %s\)" % (N, N), src)
def table(name):
    m = re.search(r"static let %s: \[Double\] = \[(.*?)\n    \]" % name, src, re.S)
    return [float(x) for x in re.findall(r"-?\d+(?:\.\d+)?(?:e-?\d+)?", m.group(1))]
path = {"x": table("x"), "y": table("y"), "t": table("t"), "count": int(re.search(r"static let count = (\d+)", src).group(1)), "duration": float(re.search(r"static let duration = ([\d.]+)", src).group(1))}
assert len(letters) == 5 and all(len(path[k]) == path["count"] + 1 for k in "xyt"), (len(letters), [len(path[k]) for k in "xyt"])
assert logo.count("M") >= 1 and arrow and head
sz = re.search(r"static let size = CGSize\(width: %s, height: %s\)" % (N, N), src)
data = {"size": [float(sz.group(1)), float(sz.group(2))], "logo": logo, "arrow": arrow, "head": head, "headPivot": [float(hp.group(1)), float(hp.group(2))], "letters": letters, "path": path}
rnd = lambda o: json.dumps(o, ensure_ascii=False, separators=(",", ":"))
open(OUT, "w", encoding="utf-8").write("/* GENERADO por android/scripts/gen-lanzamiento.py desde PlataLaunchAnimation.swift (rama swift-nativo). No editar a mano.\n   Geometría (coordenadas del logo, 532.49 x 211.4) y recorrido de la animación de arranque: la flecha sube como una piedra rebotando y las letras hacen pop. */\nconst LANZ_DATA = " + rnd(data) + ";\n")
print("ok:", len(logo), "caracteres de logo,", len(letters), "letras,", path["count"], "muestras →", os.path.relpath(OUT))
