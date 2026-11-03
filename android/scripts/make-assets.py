#!/usr/bin/env python3
"""Genera los recursos gráficos de la app de Android a partir de los archivos de press/ (el logo de Plata):
  - ícono adaptable (primer plano con la P blanca) y íconos clásicos,
  - imagen de arranque (splash) para Android 12+ y para versiones anteriores,
  - ícono y gráfico de la ficha de Google Play.
Se corre a mano cuando cambia el logo:  python3 android/scripts/make-assets.py   (necesita Pillow y playwright con chromium)."""
import io, os, sys
from PIL import Image, ImageDraw, ImageChops

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "android", "resources")
PLAY = os.path.join(ROOT, "android", "play")
GREEN = (34, 181, 115, 255)

def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True); img.save(path, optimize=True)

# ---- la P blanca del ícono (se saca del PNG de 1024: lo blanco pasa a opaco) ----
icon = Image.open(os.path.join(ROOT, "press", "plata-icono-1024.png")).convert("RGB")
r, g, b = icon.split()
white = ImageChops.darker(ImageChops.darker(r, g), b)                    # el menor de R, G y B: alto solo donde es blanco
alpha = white.point(lambda v: 0 if v < 190 else (255 if v > 235 else int((v - 190) / 45 * 255)))
mark = Image.new("RGBA", icon.size, (255, 255, 255, 0)); mark.putalpha(alpha)
mark = mark.crop(mark.getbbox())                                          # solo la marca, sin márgenes

def fit(img, w):                                                          # escala a un ancho dado
    return img.resize((w, max(1, round(img.height * w / img.width))), Image.LANCZOS)

# ---- ícono adaptable: lienzo de 108 dp con la marca dentro de la zona segura (66 dp) ----
for name, px in (("mdpi", 108), ("hdpi", 162), ("xhdpi", 216), ("xxhdpi", 324), ("xxxhdpi", 432)):
    canvas = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    m = fit(mark, round(px * 0.44))
    canvas.alpha_composite(m, ((px - m.width) // 2, (px - m.height) // 2))
    save(canvas, os.path.join(OUT, f"mipmap-{name}", "ic_launcher_foreground.png"))

# ---- ícono de las notificaciones: la P blanca sobre transparente (Android la pinta en el color de acento) ----
for name, px in (("mdpi", 24), ("hdpi", 36), ("xhdpi", 48), ("xxhdpi", 72), ("xxxhdpi", 96)):
    canvas = Image.new("RGBA", (px, px), (0, 0, 0, 0)); m = fit(mark, round(px * 0.86))
    canvas.alpha_composite(m, ((px - m.width) // 2, (px - m.height) // 2))
    save(canvas, os.path.join(OUT, f"drawable-{name}", "ic_stat_plata.png"))

# ---- íconos clásicos (Android 7 y anteriores) ----
for name, px in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)):
    sq = icon.convert("RGBA").resize((px, px), Image.LANCZOS)
    save(sq, os.path.join(OUT, f"mipmap-{name}", "ic_launcher.png"))
    mask = Image.new("L", (px * 4, px * 4), 0); ImageDraw.Draw(mask).ellipse((0, 0, px * 4 - 1, px * 4 - 1), fill=255)
    rd = sq.copy(); rd.putalpha(mask.resize((px, px), Image.LANCZOS)); save(rd, os.path.join(OUT, f"mipmap-{name}", "ic_launcher_round.png"))

# ---- el logo completo en blanco (SVG de press/) a PNG con Chromium ----
from playwright.sync_api import sync_playwright
svg = open(os.path.join(ROOT, "press", "plata-blanco.svg"), encoding="utf-8").read()
def render_logo(width_px):
    h = round(width_px * 207.43 / 532.49)
    html = f'<html><body style="margin:0;background:transparent">{svg.replace("<svg ", f"<svg width=\"{width_px}\" height=\"{h}\" ", 1)}</body></html>'
    with sync_playwright() as p:
        br = p.chromium.launch(); pg = br.new_page(viewport={"width": width_px, "height": h})
        pg.set_content(html); png = pg.screenshot(omit_background=True, clip={"x": 0, "y": 0, "width": width_px, "height": h}); br.close()
    return Image.open(io.BytesIO(png)).convert("RGBA")
logo = render_logo(1200)

# ---- splash de Android 12+: ícono animado de 288 dp (960 px) con el logo dentro del círculo seguro de 192 dp ----
sp = Image.new("RGBA", (960, 960), (0, 0, 0, 0)); lg = fit(logo, 540); sp.alpha_composite(lg, ((960 - lg.width) // 2, (960 - lg.height) // 2))
save(sp, os.path.join(OUT, "drawable-nodpi", "splash_icon.png"))

# ---- splash de versiones anteriores: fondo verde con el logo, vertical y horizontal ----
for name, size, w in (("port", (1080, 1920), 520), ("land", (1920, 1080), 520)):
    im = Image.new("RGBA", size, GREEN); lg = fit(logo, w); im.alpha_composite(lg, ((size[0] - lg.width) // 2, (size[1] - lg.height) // 2))
    save(im.convert("RGB"), os.path.join(OUT, "splash", f"splash-{name}.png"))

# ---- Google Play: ícono de 512 y gráfico de funciones de 1024 x 500 ----
save(icon.resize((512, 512), Image.LANCZOS).convert("RGB"), os.path.join(PLAY, "icono-512.png"))
fg = Image.new("RGBA", (1024, 500), GREEN); lg = fit(logo, 560); fg.alpha_composite(lg, ((1024 - lg.width) // 2, (500 - lg.height) // 2))
save(fg.convert("RGB"), os.path.join(PLAY, "grafico-funciones-1024x500.png"))
print("recursos listos en", os.path.relpath(OUT, ROOT), "y", os.path.relpath(PLAY, ROOT))
