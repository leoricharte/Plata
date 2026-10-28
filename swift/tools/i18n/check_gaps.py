#!/usr/bin/env python3
"""Lista los textos literales de la app que el diccionario aún no traduce (usa tr_ref.py).
Uso: check_gaps.py [carpeta-swift]   (por defecto swift/PlataApp/Plata)"""
import os, re, sys, glob
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tr_ref
from scan_literals import scan, human

HERE = os.path.dirname(os.path.abspath(__file__))
root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "..", "PlataApp", "Plata")
tr_ref.NAMES[:] = []

FILLS = [lambda i: "5", lambda i: "$1,200", lambda i: "octubre", lambda i: "28 oct", lambda i: "días", lambda i: "Comida"]

def ok(tpl):
    if "{" not in tpl:
        return tr_ref.t(tpl) != tpl
    # una plantilla con huecos: prueba varios rellenos (número, dinero, mes, fecha, palabra)
    for f in FILLS:
        s = re.sub(r"\{(\d+)\}", lambda m: f(int(m[1])), tpl)
        if tr_ref.t(s) != s:
            return True
    return False

seen = set()
for f in sorted(glob.glob(os.path.join(root, "*.swift"))):
    b = os.path.basename(f)
    for tpl, ex in scan(open(f, encoding="utf8").read()):
        if not human(tpl) or tpl in seen: continue
        seen.add(tpl)
        t = tpl.strip()
        if not t or ok(t): continue
        print(b + "\t" + tpl.replace("\n", "\\n"))
