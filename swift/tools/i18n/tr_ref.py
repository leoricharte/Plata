#!/usr/bin/env python3
"""Referencia en Python del traductor es→en de la app (Tr.swift), para probar el diccionario sin compilar.
Uso: tr_ref.py "Texto en español"   |   import tr_ref; tr_ref.t("...")"""
import json, re, sys, os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
JSON_PATH = os.path.join(ROOT, "PlataApp", "Plata", "Resources", "tr_en.json")

ES_MON = "enero febrero marzo abril mayo junio julio agosto septiembre octubre noviembre diciembre".split()
ES_MONA = "ene feb mar abr may jun jul ago sep oct nov dic".split()
ES_DOW = "domingo lunes martes miércoles jueves viernes sábado".split()
ES_DOWA = "dom lun mar mié jue vie sáb".split()
EN_MON = "January February March April May June July August September October November December".split()
EN_MONA = "Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec".split()
EN_DOW = "Sunday Monday Tuesday Wednesday Thursday Friday Saturday".split()
EN_DOWA = "Sun Mon Tue Wed Thu Fri Sat".split()

I = re.I
RE_LONG = re.compile(r"\b(%s) (\d{1,2}) de (%s)\b" % ("|".join(ES_DOW), "|".join(ES_MON)), I)
RE_MY = re.compile(r"\b(%s) (\d{4})\b" % "|".join(ES_MON), I)
RE_SD = re.compile(r"\b(%s) (\d{1,2}) (%s)\b(?: (\d{4}))?" % ("|".join(ES_DOWA), "|".join(ES_MONA)), I)
RE_D = re.compile(r"\b(\d{1,2}) (%s)\b(?: (\d{4}))?" % "|".join(ES_MONA), I)
RE_MYA = re.compile(r"\b(%s) (\d{4})\b" % "|".join(ES_MONA), I)
RE_MF = re.compile(r"\b(%s)\b" % "|".join(ES_MON), I)
RE_NUM = re.compile(r"[+−\-]?(?:S/ ?|US\$|CHF ?|KM ?|C\$|A\$|[$€£¥●] ?)?\d(?:[\d.,]*\d)?%?")
PL_SING = {'días': 'día', 'meses': 'mes', 'semanas': 'semana', 'cuentas': 'cuenta', 'ocultas': 'oculta', 'registros': 'registro', 'cambios': 'cambio', 'ingresos': 'ingreso', 'categorías': 'categoría', 'gastos': 'gasto', 'movimientos': 'movimiento', 'metas': 'meta', 'tarjetas': 'tarjeta', 'eventos': 'evento', 'dígitos': 'dígito', 'años': 'año', 'previstos': 'previsto', 'pagos': 'pago'}
RE_PL = re.compile(r"(\{\d+\}) (%s)(?![\wáéíóúñ])" % "|".join(PL_SING), I)

NAMES = []


def idx(arr, w):
    w = w.lower()
    return arr.index(w) if w in arr else -1


def tokenize(s):
    ctx = {"dts": [], "mons": [], "nums": [], "long": None, "my": None, "mya": None, "name": ""}

    def f_long(m): ctx["long"] = [idx(ES_DOW, m[1]), int(m[2]), idx(ES_MON, m[3])]; return "{D}"
    def f_my(m): ctx["my"] = [idx(ES_MON, m[1]), int(m[2])]; return "{Y}"
    def f_sd(m): ctx["dts"].append([idx(ES_DOWA, m[1]), int(m[2]), idx(ES_MONA, m[3]), int(m[4]) if m[4] else 0]); return "{d}"
    def f_d(m): ctx["dts"].append([-1, int(m[1]), idx(ES_MONA, m[2]), int(m[3]) if m[3] else 0]); return "{d}"
    def f_mya(m): ctx["mya"] = [idx(ES_MONA, m[1]), int(m[2])]; return "{y}"
    def f_mf(m): ctx["mons"].append(idx(ES_MON, m[1])); return "{m}"
    k = RE_LONG.sub(f_long, s)
    k = RE_MY.sub(f_my, k)
    k = RE_SD.sub(f_sd, k)
    k = RE_D.sub(f_d, k)
    k = RE_MYA.sub(f_mya, k)
    k = RE_MF.sub(f_mf, k)
    for nm in NAMES:
        re_n = re.compile(r"(^|[^\w])" + re.escape(nm) + r"(?!\w)")
        if re_n.search(k):
            ctx["name"] = nm
            k = re_n.sub(lambda m: m[1] + "{n}", k)
            break

    def f_num(m): ctx["nums"].append(m[0]); return "{%d}" % (len(ctx["nums"]) - 1)
    k = RE_NUM.sub(f_num, k)
    k = RE_PL.sub(lambda m: m[1] + " " + PL_SING[m[2].lower()], k)
    return k, ctx


def fmt_short(dw, d, mo, y):
    a = EN_MONA[mo]
    return (EN_DOWA[dw] + ", " if dw >= 0 else "") + ("%s %d, %d" % (a, d, y) if y else "%s %d" % (a, d))


def fill(tpl, ctx):
    def q(m):
        i = int(m[1]); digits = re.sub(r"[^\d]", "", ctx["nums"][i]) if i < len(ctx["nums"]) else ""
        return m[2] if digits and int(digits) == 1 else m[3]
    s = re.sub(r"\{(\d+)\?([^:}]*):([^}]*)\}", q, tpl)
    s = re.sub(r"\{(\d+)\}", lambda m: ctx["nums"][int(m[1])] if int(m[1]) < len(ctx["nums"]) else m[0], s)
    s = s.replace("{n}", ctx["name"])
    def mon(m):
        if not ctx["mons"]: return m[0]
        w = EN_MON[ctx["mons"][0]]
        return w
    s = re.sub(r"\{([mM])\}", mon, s)
    def dt(m):
        i = "defg".index(m[1])
        if i >= len(ctx["dts"]): return m[0]
        return fmt_short(*ctx["dts"][i])
    s = re.sub(r"\{([defg])\}", dt, s)
    if ctx["long"]: s = s.replace("{D}", "%s, %s %d" % (EN_DOW[ctx["long"][0]], EN_MON[ctx["long"][2]], ctx["long"][1]))
    if ctx["mya"]: s = s.replace("{y}", "%s %d" % (EN_MONA[ctx["mya"][0]], ctx["mya"][1]))
    if ctx["my"]: s = s.replace("{Y}", "%s %d" % (EN_MON[ctx["my"][0]], ctx["my"][1]))
    return s


_idx = None


def index():
    global _idx
    if _idx is None:
        ex, lo = {}, {}
        for es, en in json.load(open(JSON_PATH, encoding="utf-8")):
            if not en: continue
            k = es
            if re.search(r"\d", es) and not re.search(r"\{\d+\}", es):
                c = [0]
                def nn(m):
                    c[0] += 1; return "{%d}" % (c[0] - 1)
                k = RE_NUM.sub(nn, es)
            ex[k] = en
            lo.setdefault(es.lower(), en)
        _idx = (ex, lo)
    return _idx


def match_case(src, out):
    a = src[:1]
    if a != a.upper() and a == a.lower(): return out[:1].lower() + out[1:]
    if a != a.lower(): return out[:1].upper() + out[1:]
    return out


def core_tr(core):
    key, ctx = tokenize(core)
    ex, lo = index()
    if key in ex: return fill(ex[key], ctx)
    allcaps = core == core.upper() and core != core.lower()
    v = lo.get(key.lower())
    if v is not None:
        o = fill(v, ctx)
        return o.upper() if allcaps else match_case(core, o)
    if re.fullmatch(r"(\{[dDYym]\}|\s|·|[-–—])+", key): return fill(key, ctx)
    return None


def tr_string(core):
    r = core_tr(core)
    if r is not None: return r
    if re.search(r"[.!]$", core) and len(core) > 3:
        q = core_tr(core[:-1])
        if q is not None: return q + core[-1]
    if core.find(" · ") > 0:
        out, hit = [], False
        for p in core.split(" · "):
            q = tr_string(p)
            if q is not None: hit = True; out.append(q)
            else: out.append(p)
        if hit: return " · ".join(out)
    return None


def t(raw):
    m = re.match(r"^(\s*)([\s\S]*?)(\s*)$", raw)
    if not m[2]: return raw
    core = re.sub(r"\s+", " ", m[2])
    r = tr_string(core)
    return raw if r is None else m[1] + r + m[3]


if __name__ == "__main__":
    for a in sys.argv[1:]:
        print(t(a))
