"""Compila la app: junta src/app.html + traducciones + iconos + fuentes en UN solo archivo.
Uso:  python3 dev/app/build.py        ->  dev/app/out/finanzas.html
      CHANNEL=alpha python3 ...        ->  icono blanco (finanzas-alpha.html)
Después cópialo a app/index.html (ver dev/README.md)."""
import base64, pathlib, json, os, re

root = pathlib.Path(__file__).resolve().parent
src, assets = root / "src", root / "assets"
CHANNEL = os.environ.get("CHANNEL", "beta")
icon = assets / ("icon-alpha-180.png" if CHANNEL == "alpha" else "icon-180.png")
b64 = lambda p: base64.b64encode(p.read_bytes()).decode()

html = (src / "app.html").read_text(encoding="utf-8")
rows = []
for f in sorted((src / "tr").glob("*.txt")):
    for ln in f.read_text(encoding="utf-8").split("\n"):
        ln = ln.strip()
        if not ln or ln.startswith("#"): continue
        parts = [x.strip() for x in ln.split(" ¦ ")]
        if len(parts) < 6: parts += [""] * (6 - len(parts))
        rows.append(parts[:6])  # es ¦ en ¦ ja ¦ it ¦ fr ¦ hr
i18n = (src / "i18n.js").read_text(encoding="utf-8").replace("__TR_DATA__", json.dumps(rows, ensure_ascii=False))
i18n += "\n" + (src / "i18n_phr.js").read_text(encoding="utf-8") + "\n" + (src / "i18n_demo.js").read_text(encoding="utf-8")
html = html.replace("__BUILD__", re.search(r"const APP_BUILD = (\d+)", html).group(1))  # el número de la pantalla de inicio sale de APP_BUILD
for key, name in (("I18N", None), ("SF", "icons_sf.js"), ("DEMOS", "demo_profiles.js"), ("WORLD", "worldmap.js"), ("RMX", "icons_rmx.js")):
    html = html.replace("/*__%s__*/" % key, i18n if name is None else (src / name).read_text(encoding="utf-8"))
html = html.replace("__INTER_B64__", b64(assets / "inter-latin-wght-normal.woff2"))
html = html.replace("__CARDNUM_B64__", b64(assets / "cardnum.woff2"))
html = html.replace("__ICON_B64__", b64(icon))
out = root / "out"; out.mkdir(exist_ok=True)
dest = out / ("finanzas-alpha.html" if CHANNEL == "alpha" else "finanzas.html")
dest.write_text(html, encoding="utf-8")
print(dest, round(dest.stat().st_size / 1024), "KB")
