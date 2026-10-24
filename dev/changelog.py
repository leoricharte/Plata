#!/usr/bin/env python3
"""Publica en novedades.html el registro de cambios de la última versión (CHANGELOG.md), firmado por «el equipo de Plata».
Uso: python3 dev/changelog.py [YYYY-MM-DD]   (la fecha por defecto es hoy). Se puede ejecutar de nuevo: actualiza la entrada de esa versión."""
import re, sys, html, datetime, pathlib
root = pathlib.Path(__file__).resolve().parent.parent
log = (root / 'CHANGELOG.md').read_text(encoding='utf-8')
m = re.search(r'^## (.+?)\n(.*?)(?=^## |\Z)', log, re.S | re.M)
name, body = m.group(1).strip(), m.group(2)
items = re.findall(r'^- \*\*(.+?):?\*\* ?(.*)$', body, re.M)
if not items: raise SystemExit('La última versión no tiene cambios listados')
date = sys.argv[1] if len(sys.argv) > 1 else datetime.date.today().isoformat()
MES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre']
y, mo, d = map(int, date.split('-')); long = '%d de %s de %d' % (d, MES[mo - 1], y)
pid = 'changelog-' + re.sub(r'[^a-z0-9]+', '-', name.lower()).strip('-')
E = lambda t: html.escape(re.sub(r'\*\*(.+?)\*\*', r'\1', t), quote=False)
vf = (root / 'dev' / 'verified.svg').read_text(encoding='utf-8').strip()
lis = ''.join('<li><b>%s.</b> %s</li>' % (E(t.rstrip('.')), E(x[:1].upper() + x[1:])) for t, x in items)
art = ('<article class="post" lang="es" data-pid="%s"><div class="by"><time datetime="%s">%s</time><span class="sep">·</span>'
       '<span>escrito por <b class="au">el equipo de Plata</b><i class="vf">%s</i></span><span class="sep" data-es="" data-en="·"></span><span class="esn" data-es="" data-en="Written in Spanish"></span></div>'
       '<h2>%s: registro de cambios</h2>\n<p>Esto es lo que cambió en Plata %s.</p>\n<ul>%s</ul>\n<span class="tag">%s</span><span class="tag">Registro de cambios</span></article>\n') % (pid, date, long, vf, E(name), E(name), lis, E(name))
f = root / 'novedades.html'; s = f.read_text(encoding='utf-8')
old = re.search(r'<article class="post"[^>]*data-pid="%s".*?</article>\n?' % re.escape(pid), s, re.S)
if old: s = s[:old.start()] + art + s[old.end():]
else:
    i = s.index('<article class="post"'); s = s[:i] + art + s[i:]
f.write_text(s, encoding='utf-8'); print('Novedades actualizado:', pid)
