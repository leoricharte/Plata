#!/usr/bin/env python3
"""Extrae los textos literales de la app (con interpolaciones) y los normaliza: \\(expr) -> {0}, {1}...
Uso: scan_literals.py <carpeta-swift> > literales.tsv  (archivo<TAB>plantilla)"""
import re, sys, glob, os

def scan(src):
    """Devuelve [(plantilla, [expresiones])] de cada literal de una sola linea (ignora los de varias lineas)."""
    out = []; i = 0; n = len(src)
    while i < n:
        c = src[i]
        if c == '/' and src[i:i+2] == '//':
            j = src.find('\n', i); i = n if j < 0 else j; continue
        if c == '/' and src[i:i+2] == '/*':
            j = src.find('*/', i); i = n if j < 0 else j + 2; continue
        if c == '"':
            if src[i:i+3] == '"""':
                j = src.find('"""', i + 3); i = n if j < 0 else j + 3; continue
            res = parse(src, i)
            if res is None: i += 1; continue
            tpl, exprs, end = res
            out.append((tpl, exprs)); i = end; continue
        i += 1
    return out

def parse(src, i):
    """Lee un literal desde la comilla de apertura. Devuelve (plantilla, expresiones, índice tras el cierre)."""
    j = i + 1; n = len(src); buf = []; exprs = []
    while j < n:
        c = src[j]
        if c == '\n': return None
        if c == '\\':
            d = src[j+1] if j + 1 < n else ''
            if d == '(':
                k = j + 2; depth = 1; e = []
                while k < n and depth:
                    ch = src[k]
                    if ch == '"':   # cadena dentro de la interpolación
                        r = parse(src, k)
                        if r is None: return None
                        e.append(src[k:r[2]]); k = r[2]; continue
                    if ch == '(': depth += 1
                    elif ch == ')':
                        depth -= 1
                        if depth == 0: break
                    e.append(ch); k += 1
                exprs.append(''.join(e).strip()); buf.append('{%d}' % (len(exprs) - 1)); j = k + 1; continue
            m = {'n': '\n', 't': '\t', '"': '"', '\\': '\\', "'": "'", '0': '\0'}
            if d == 'u':
                m2 = re.match(r'\\u\{([0-9a-fA-F]+)\}', src[j:])
                if m2: buf.append(chr(int(m2.group(1), 16))); j += len(m2.group(0)); continue
            buf.append(m.get(d, d)); j += 2; continue
        if c == '"': return ''.join(buf), exprs, j + 1
        buf.append(c); j += 1
    return None

def human(t):
    """¿Parece texto para personas? (no claves, símbolos SF, ids ni formatos)"""
    if not re.search(r'[A-Za-zÁÉÍÓÚáéíóúñÑ]{2}', t): return False
    if re.match(r'^[a-z][A-Za-z0-9._\-]*$', t): return False
    if re.match(r'^[A-Za-z0-9_]+\.[a-z]+$', t): return False
    if t.startswith(('#', 'http', 'net.', 'plata.', 'data:', '%', '^')): return False
    if re.match(r'^[A-Z]{3}$', t): return False       # códigos de moneda
    if re.match(r'^[\w\-{}]+$', t) and '_' in t: return False
    return True

if __name__ == '__main__':
    root = sys.argv[1]
    seen = set()
    for f in sorted(glob.glob(os.path.join(root, '*.swift'))):
        for tpl, ex in scan(open(f, encoding='utf8').read()):
            if not human(tpl) or (os.path.basename(f), tpl) in seen: continue
            seen.add((os.path.basename(f), tpl))
            print(f'{os.path.basename(f)}\t{tpl.encode("unicode_escape").decode("ascii") if False else tpl.replace(chr(10), chr(92)+"n")}')
