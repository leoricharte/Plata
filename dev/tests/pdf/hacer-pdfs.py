#!/usr/bin/env python3
"""Genera los PDF INVENTADOS que usa dev/tests/nazca-pdf.mjs (nombres, cuentas y montos falsos; ningún dato real).
Imitan el diseño del "Estado de Cuenta de Ahorros Cuenta Digital BCP": mismas posiciones de columnas, fechas sin año (30SET), monto sin signo
(cargo o abono según la columna), marcas * y 1, y TOTAL MOVIMIENTO / SALDO al final.
Uso:  python3 dev/tests/pdf/hacer-pdfs.py      (necesita reportlab y qpdf; los PDF ya generados están en esta carpeta, no hace falta correrlo)"""
import subprocess, pathlib
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A4, letter

OUT = pathlib.Path(__file__).parent
ROWS_PER_PAGE = 16
C_RIGHT, A_RIGHT = 426, 563          # borde derecho de los montos de cargos y de abonos
def m(x): return f"{x:,.2f}"

def bcp(path, periodo, saldo_ant, filas, moneda="SOLES", nombre="PEREZ LOPEZ MARIA ELENA", cuenta="194-12345678-0-45", total_cargos_impreso=None):
    """filas: (proc, valor, descripcion, 'c'|'a', monto, marca)"""
    cargos = round(sum(f[4] for f in filas if f[3] == 'c'), 2)
    abonos = round(sum(f[4] for f in filas if f[3] == 'a'), 2)
    final = round(saldo_ant + abonos - cargos, 2)
    paginas = [filas[i:i + ROWS_PER_PAGE] for i in range(0, len(filas), ROWS_PER_PAGE)] or [[]]
    c = canvas.Canvas(str(path), pagesize=A4)
    c.setTitle("Estado de cuenta de prueba (inventado)")
    for n, pag in enumerate(paginas, 1):
        c.setFont("Helvetica-Bold", 8); c.drawString(29, 768, "Estado de Cuenta de Ahorros Cuenta Digital BCP")
        c.setFont("Helvetica", 6)
        c.drawString(394, 751, "PAGINA"); c.drawString(489, 748, str(n)); c.drawString(511, 748, "DE"); c.drawString(561, 748, str(len(paginas)))
        c.drawString(31, 734, nombre); c.drawString(374, 737, "CODIGO DE CUENTA"); c.drawString(505, 737, "MONEDA")
        c.drawString(345, 717, cuenta); c.drawString(491, 717, moneda)
        c.drawString(31, 706, "AV. EJEMPLO 123"); c.drawString(31, 692, "MIRAFLORES-LIMA"); c.drawString(31, 678, "LIMA-01")
        c.drawString(411, 685, "FECHA DE ESTADO DE CUENTA")
        c.drawString(363, 666, "DEL"); c.drawString(399, 666, periodo[0]); c.drawString(471, 666, "AL"); c.drawString(500, 666, periodo[1])
        c.setFont("Helvetica-Bold", 5.5)
        c.drawString(33, 631, "FECHA PROC."); c.drawString(80, 631, "FECHA VALOR"); c.drawString(182, 631, "DESCRIPCION")
        c.drawString(343, 631, "CARGOS / DEBE"); c.drawString(485, 631, "ABONOS / HABER")
        c.setFont("Helvetica", 6.5)
        y = 612
        if n == 1:
            c.drawString(123, y, "SALDO ANTERIOR"); c.drawRightString(A_RIGHT, y, m(saldo_ant)); y -= 11.3
        for proc, valor, desc, tipo, monto, marca in pag:
            c.drawString(37, y, proc)
            c.drawString(80, y, f"{valor} {desc}")                 # como en el PDF real: fecha valor y descripción en un solo texto
            if marca: c.drawString(282, y, marca)
            c.drawRightString(C_RIGHT if tipo == 'c' else A_RIGHT, y, m(monto)); y -= 11.3
        if n == len(paginas):
            c.drawString(125, 173, "TOTAL MOVIMIENTO")
            c.drawRightString(431, 176, m(cargos if total_cargos_impreso is None else total_cargos_impreso)); c.drawRightString(565, 176, m(abonos))
            c.drawRightString(562, 152, m(final)); c.drawString(125, 147, "SALDO")
        c.drawString(31, 132, "la cuenta y aprobado el saldo. Si tienes alguna duda o reclamo no dudes en contactarnos en nuestras Oficinas.")
        c.drawString(119, 118, "MENSAJE AL CLIENTE")
        c.showPage()
    c.save()
    return cargos, abonos, final

def interbank(path, periodo, mes_inicio, saldo_ant, filas, producto="CUENTA SIMPLE SOLES", cuenta="123-4567890123", total_gastos_impreso=None, fin="27/03"):
    """Imita el "ESTADO DE CUENTA" de ahorros de Interbank: fecha completa, monto con signo (+ ingreso, - gasto), saldo contable por fila,
    EMPEZASTE ... CON / SALDO CONTABLE AL ... y una última página-guía con movimientos de EJEMPLO que no se deben leer.
    filas: (dd/mm/aaaa, concepto, monto con signo)"""
    ing = round(sum(f[2] for f in filas if f[2] > 0), 2); gas = round(-sum(f[2] for f in filas if f[2] < 0), 2)
    final = round(saldo_ant + ing - gas, 2)
    def sg(v): return ("+" if v > 0 else "-") + m(abs(v))
    c = canvas.Canvas(str(path), pagesize=A4); c.setTitle("Estado de cuenta de prueba (inventado)")
    c.setFont("Helvetica-Bold", 9); c.drawRightString(536, 774, "ESTADO DE CUENTA"); c.drawRightString(536, 760, producto)
    c.setFont("Helvetica", 8); c.drawRightString(536, 746, cuenta); c.drawRightString(536, 732, periodo)
    c.drawString(60, 698, "Perez Lopez Maria Elena"); c.drawString(60, 683, "DNI 10000000"); c.drawString(60, 672, "Tu cuenta fue aperturada el 01/01/2020")
    c.setFont("Helvetica-Bold", 9); c.drawString(60, 638, "DETALLE DE MOVIMIENTOS")
    c.setFont("Helvetica-Bold", 7.5); c.drawString(60, 611, "Fecha"); c.drawString(179, 611, "Concepto"); c.drawRightString(347, 611, "Ingresos"); c.drawRightString(428, 611, "Gastos"); c.drawRightString(534, 611, "Saldo Contable")
    c.setFont("Helvetica", 8)
    y = 582; c.drawString(60, y, f"EMPEZASTE {mes_inicio} CON"); c.drawRightString(508, y, m(saldo_ant)); y -= 28.3
    saldo = saldo_ant
    for fecha, concepto, monto in filas:
        saldo = round(saldo + monto, 2)
        c.drawString(60, y, fecha); c.drawString(125, y, concepto)
        c.drawRightString(341 if monto > 0 else 425, y, sg(monto)); c.drawRightString(508, y, m(saldo)); y -= 28.3
    c.setFont("Helvetica-Bold", 8); c.drawString(60, y, f"SALDO CONTABLE AL {fin}")
    c.drawRightString(345, y, sg(ing)); c.drawRightString(427, y, "-" + m(gas if total_gastos_impreso is None else total_gastos_impreso)); c.drawRightString(510, y, m(final))
    c.setFont("Helvetica", 8); c.drawString(37, 252, "Realiza GRATIS tus consultas, pagos y transferencias bancarias/interbancarias las 24 horas del día,")
    c.drawString(113, 105, "En Interbank nos preocupamos por tu seguridad."); c.drawString(37, 227, "Ahorra con tu Alcancía Virtual, es fácil, inmediato y seguro desde tu Interbank APP.")
    c.showPage()
    # página-guía: explica el estado de cuenta con un EJEMPLO (otra persona, otra fecha, saldos que no cuadran): no se debe leer
    c.setFont("Helvetica-Bold", 16); c.drawString(43, 535, "Te ayudamos a conocer"); c.drawString(43, 505, "tu Estado de Cuenta:")
    c.setFont("Helvetica-Bold", 8); c.drawRightString(530, 407, "ESTADO DE CUENTA"); c.drawRightString(530, 400, "CUENTA SIMPLE SOLES"); c.drawRightString(530, 393, "100-7000590278"); c.drawRightString(530, 386, "DEL 1 AL 30 DE NOVIEMBRE")
    c.setFont("Helvetica", 7); c.drawString(336, 375, "Maria Vara de Gamarra"); c.drawString(339, 352, "DETALLE DE MOVIMIENTOS")
    c.drawString(341, 341, "Fecha"); c.drawString(395, 341, "Concepto"); c.drawRightString(470, 341, "Ingresos"); c.drawRightString(494, 341, "Gastos"); c.drawRightString(522, 341, "Saldo")
    c.drawString(339, 326, "EMPEZASTE OCTUBRE CON"); c.drawRightString(526, 326, "4,560.41")
    for i, (cc, mo, sd) in enumerate((("Transf PLIN", "+27.20", "4,545.40"), ("Planilla", "+2,650.20", "6,890.79"), ("Pago mi TC", "-47.20", "6,890.79"))):
        yy = 315 - 10 * i; c.drawString(339, yy, "03/10/2021"); c.drawString(376, yy, cc); c.drawRightString(492, yy, mo); c.drawRightString(525, yy, sd)
    c.drawString(339, 194, "SALDO CONTABLE AL 29/10"); c.drawRightString(468, 194, "+2,670.20"); c.drawRightString(494, 194, "-472.70"); c.drawRightString(525, 194, "6,890.79")
    c.drawString(65, 390, "Este es el CICLO DE CONSUMO. Te mostramos los movimientos realizados entre estas fechas."); c.drawString(360, 84, "En Interbank nos preocupamos por tu seguridad.")
    c.showPage(); c.save()
    return ing, gas, final

IB_MARZO = [
    ("02/03/2026", "TRANSF WEB/APP", +150.00), ("03/03/2026", "PLIN RECIBIDO", +40.00), ("05/03/2026", "Netflix", -44.90), ("09/03/2026", "Planilla", +1850.50),
    ("10/03/2026", "WONG SURCO", -214.90), ("12/03/2026", "TELLO 2 CDL", -6.60), ("15/03/2026", "TRANSF WEB/APP", -300.00), ("20/03/2026", "Spotify", -21.90), ("24/03/2026", "PPA PAGOS", +95.96),
]
IB_ENERO = [("30/12/2025", "TRANSF WEB/APP", -20.00), ("02/01/2026", "PLIN RECIBIDO", +35.00), ("15/01/2026", "Planilla", +1850.50), ("20/01/2026", "Apple", -35.38)]

MARZO = [
    ("28FEB", "28FEB", "ABON PLIN-Ana Gomez", 'a', 70.00, "*"),
    ("28FEB", "28FEB", "TRAN.CTAS.PROP.BM", 'a', 500.00, "*"),
    ("28FEB", "28FEB", "Pago YAPE a 190001", 'c', 370.00, ""),
    ("01MAR", "01MAR", "OXXO MIRAFLORES", 'c', 1.70, ""),
    ("01MAR", "01MAR", "DLC*Rappi", 'c', 12.00, ""),
    ("02MAR", "02MAR", "PLAZA VEA SURCO", 'c', 3.30, ""),
    ("03MAR", "03MAR", "CREDITO YAPE", 'a', 50.00, ""),
    ("03MAR", "03MAR", "RETIRO EFECTIVO", 'c', 40.00, ""),
    ("04MAR", "04MAR", "Pago YAPE de 19002", 'a', 19.00, ""),
    ("04MAR", "04MAR", "Pago YAPE a 190004", 'c', 19.00, ""),
    ("06MAR", "06MAR", "PYU*UBER", 'c', 7.40, ""),
    ("06MAR", "06MAR", "EXT PYU*UBER", 'a', 7.40, "*"),
    ("07MAR", "07MAR", "TAMBO SURCO", 'c', 7.00, ""),
    ("09MAR", "09MAR", "SUELDO MARZO", 'a', 1850.50, ""),
    ("10MAR", "10MAR", "E WONG SURCO", 'c', 214.90, ""),
    ("12MAR", "12MAR", "Pago YAPE de 19005", 'a', 2.50, ""),
    ("15MAR", "15MAR", "TRAN.CTAS.PROP.BM", 'c', 300.00, "*"),
    ("18MAR", "18MAR", "NETFLIX.COM", 'c', 44.90, ""),
    ("21MAR", "21MAR", "Pago YAPE a 190006", 'c', 15.60, ""),
    ("25MAR", "25MAR", "PLIN-CARLOS DIAZ", 'c', 120.00, ""),
    ("31MAR", "15MAR", "MANTEN.TD.ORO MAR", 'c', 4.50, "*"),
    ("31MAR", "31MAR", "MANT. CUENTA MAR26", 'c', 0.00, "1"),
]
ENERO = [
    ("31DIC", "31DIC", "Pago YAPE a 190010", 'c', 25.00, ""),
    ("31DIC", "31DIC", "ABON PLIN-Luis Ramos", 'a', 60.00, "*"),
    ("02ENE", "02ENE", "OXXO MIRAFLORES", 'c', 8.90, ""),
    ("15ENE", "15ENE", "SUELDO ENERO", 'a', 1850.50, ""),
    ("20ENE", "20ENE", "SPOTIFY", 'c', 21.90, ""),
    ("31ENE", "15ENE", "MANTEN.TD.ORO ENE", 'c', 4.50, "*"),
]

MALICIOSO = [
    ("02MAR", "02MAR", "<img src=x onerror=alert(1)>", 'c', 5.00, ""),
    ("03MAR", "03MAR", "</script><script>alert(2)</script>", 'c', 6.00, ""),
    ("04MAR", "04MAR", "SUELDO", 'a', 100.00, ""),
]

def falso(path, banco, titulo, filas, cols, pie):
    """Estado de cuenta de un banco que Nazca NO conoce. Todo es inventado y dice "DOCUMENTO DE PRUEBA". filas: (columnas de fecha..., descripción, monto)"""
    c = canvas.Canvas(str(path), pagesize=A4); c.setTitle(banco + " - documento de prueba (inventado)")
    c.setFont("Helvetica-Bold", 14); c.drawString(40, 790, banco); c.setFont("Helvetica", 9); c.drawString(40, 774, titulo)
    c.setFillColorRGB(.8, 0, 0); c.setFont("Helvetica-Bold", 9); c.drawString(40, 758, "DOCUMENTO DE PRUEBA - DATOS INVENTADOS - NO ES UN ESTADO DE CUENTA REAL"); c.setFillColorRGB(0, 0, 0)
    c.setFont("Helvetica", 8); y = 720
    for x, t in cols: c.drawString(x, y, t)
    y -= 16
    for f in filas:
        for (x, _), v in zip(cols[:-1], f[:-1]): c.drawString(x, y, v)
        c.drawRightString(cols[-1][0] + 60, y, f[-1]); y -= 13
    c.drawString(40, y - 20, pie); c.showPage(); c.save()

def capital_one(path, desde, hasta, filas, previo, ultimos="4242", total_compras_impreso=None, vence="Apr 25, 2026"):
    """Estado INVENTADO de tarjeta Capital One (no copia el diseño real). filas: (fecha op, fecha post, descripción, monto) con compras (+) y pagos (-)."""
    compras = round(sum(f[3] for f in filas if f[3] > 0), 2); pagos = round(-sum(f[3] for f in filas if f[3] < 0), 2)
    nuevo = round(previo + compras - pagos, 2)
    d = lambda v: ("-" if v < 0 else "") + "$" + f"{abs(v):,.2f}"
    c = canvas.Canvas(str(path), pagesize=A4); c.setTitle("Capital One - documento de prueba (inventado)")
    c.setFont("Helvetica-Bold", 16); c.drawString(40, 790, "Capital One"); c.setFont("Helvetica", 9); c.drawString(40, 774, "Platinum Mastercard (PRUEBA)")
    c.setFillColorRGB(.8, 0, 0); c.setFont("Helvetica-Bold", 8.5); c.drawString(40, 760, "DOCUMENTO DE PRUEBA - DATOS INVENTADOS - NO ES UN ESTADO DE CUENTA REAL"); c.setFillColorRGB(0, 0, 0)
    c.setFont("Helvetica", 9); c.drawString(40, 740, f"Statement period: {desde} - {hasta}"); c.drawString(40, 727, f"Account ending in {ultimos}")
    y = 700; c.setFont("Helvetica-Bold", 9); c.drawString(40, y, "Account Summary"); c.setFont("Helvetica", 9); y -= 15
    for k, v in (("Previous Balance", d(previo)), ("Payments", d(-pagos)), ("Purchases", d(total_compras_impreso if total_compras_impreso is not None else compras)), ("Fees Charged", d(0)), ("New Balance", d(nuevo))):
        c.drawString(40, y, k); c.drawRightString(260, y, v); y -= 13
    c.setFont("Helvetica", 9); c.drawString(300, 700 - 15, f"Credit Limit $3,000.00"); c.drawString(300, 700 - 28, "Purchase APR 24.99%"); c.drawString(300, 700 - 41, f"Minimum Payment Due {d(max(25.0, round(nuevo * .03, 2)))}"); c.drawString(300, 700 - 54, f"Payment Due Date {vence}")
    y -= 14; c.setFont("Helvetica-Bold", 8)
    for x, t in ((40, "Trans Date"), (110, "Post Date"), (180, "Description"), (480, "Amount")): c.drawString(x, y, t)
    y -= 15; c.setFont("Helvetica", 8)
    for f1, f2, desc, monto in filas:
        c.drawString(40, y, f1); c.drawString(110, y, f2); c.drawString(180, y, desc); c.drawRightString(540, y, d(monto)); y -= 13
    c.showPage(); c.save()
    return nuevo

def capital_one_nuevo(path, filas, previo=172.30, interes=6.91, ultimos="4242", impreso_nuevo=None):
    """Estado INVENTADO con el diseño que usan hoy los estados de Capital One (Quicksilver/Savor): periodo sin título "Statement period", resumen con
    "Transactions +", "Other Credits", "Interest Charged" y "New Balance =", e importes del pago mínimo en la línea de abajo. filas: (op, post, desc, monto) con compras (+) y pagos/créditos (-)."""
    compras = round(sum(f[3] for f in filas if f[3] > 0 and not f[2].startswith("CREDIT")), 2)
    otros = round(-sum(f[3] for f in filas if f[2].startswith("CREDIT")), 2); pagos = round(-sum(f[3] for f in filas if f[3] < 0 and not f[2].startswith("CREDIT")), 2)
    nuevo = round(previo - pagos - otros + compras + interes, 2)
    d = lambda v: ("- " if v < 0 else "") + "$" + f"{abs(v):,.2f}"
    c = canvas.Canvas(str(path), pagesize=(612, 792)); c.setTitle("Capital One - documento de prueba (inventado)")
    c.setFont("Helvetica-Bold", 9); c.drawString(25, 775, "Capital One"); c.setFillColorRGB(.8, 0, 0); c.drawString(120, 775, "DOCUMENTO DE PRUEBA - DATOS INVENTADOS"); c.setFillColorRGB(0, 0, 0)
    c.setFont("Helvetica", 9); c.drawString(349, 754, f"Ejemplo Card | World Elite Mastercard ending in {ultimos}"); c.drawString(393, 744, "Jun 16, 2026 - Jul 16, 2026"); c.drawString(503, 744, "|"); c.drawString(510, 744, "31 days in Billing Cycle")
    c.setFont("Helvetica-Bold", 9); c.drawString(104, 716, "Payment Information"); c.drawString(410, 716, "Account Summary"); c.setFont("Helvetica", 9)
    c.drawString(25, 699, "Payment Due Date"); c.drawString(25, 679, "Aug 10, 2026")
    for y, k, v in ((699, "Previous Balance", d(previo)), (679, "Payments", d(-pagos)), (661, "Other Credits", d(-otros)), (643, "Transactions", "+ " + d(compras)), (608, "Fees Charged", "+ $0.00"), (590, "Interest Charged", "+ " + d(interes)), (572, "New Balance", "= " + d(impreso_nuevo if impreso_nuevo is not None else nuevo)), (551, "Credit Limit", "$300.00")):
        c.drawString(322, y, k); c.drawRightString(580, y, v)
    c.drawString(25, 625, "New Balance"); c.drawString(166, 625, "Minimum Payment Due"); c.drawString(25, 604, d(nuevo)); c.drawString(166, 604, "$25.00")
    c.drawString(29, 107, "Payment Due Date:"); c.drawString(109, 107, "Aug 10, 2026"); c.drawString(219, 107, f"Account ending in {ultimos}")
    c.showPage()
    c.setFont("Helvetica", 9); c.drawString(349, 754, f"Ejemplo Card | World Elite Mastercard ending in {ultimos}"); c.drawString(393, 744, "Jun 16, 2026 - Jul 16, 2026")
    y = 678; c.setFont("Helvetica-Bold", 8); c.drawString(45, y, "TITULAR PRUEBA #" + ultimos + ": Payments, Credits and Adjustments"); y -= 17
    for x, t in ((45, "Trans Date"), (105, "Post Date"), (164, "Description"), (560, "Amount")): c.drawString(x, y, t)
    y -= 17; c.setFont("Helvetica", 8)
    pag = [f for f in filas if f[3] < 0]; comp = [f for f in filas if f[3] > 0]
    for f in pag: c.drawString(45, y, f[0]); c.drawString(105, y, f[1]); c.drawString(164, y, f[2]); c.drawRightString(580, y, d(f[3])); y -= 17
    y -= 10; c.setFont("Helvetica-Bold", 8); c.drawString(45, y, "TITULAR PRUEBA #" + ultimos + ": Transactions"); y -= 17; c.setFont("Helvetica", 8)
    for f in comp: c.drawString(45, y, f[0]); c.drawString(105, y, f[1]); c.drawString(164, y, f[2]); c.drawRightString(580, y, d(f[3])); y -= 17
    c.drawString(45, y - 10, "Total Transactions for This Period"); c.drawRightString(580, y - 10, d(compras))
    c.showPage(); c.setFont("Helvetica", 8); c.drawString(47, 662, "Purchases"); c.drawString(212, 662, "28.99% P"); c.drawString(391, 662, "$0.00"); c.save()
    return nuevo

CO_NUEVO = [("Jun 16", "Jun 16", "CREDIT-CASH BACK REWARD", -0.28), ("Jun 17", "Jun 17", "CAPITAL ONE MOBILE PYMT", -195.81), ("Jun 19", "Jun 19", "CAPITAL ONE MOBILE PYMT", -55.00),
    ("Jun 15", "Jun 16", "TIENDA EJEMPLO ONLINE NY", 5.99), ("Jun 16", "Jun 17", "SUPER DEMO 227 NY", 12.20), ("Jun 25", "Jun 26", "TRANSPORTE DEMO WHITE PLAINS NY", 98.59), ("Jul 11", "Jul 11", "MARKET PRUEBA SEATTLE WA", 21.55)]

CO_MARZO = [("Mar 3", "Mar 4", "AMAZON MKTPLACE PMTS", 23.99), ("Mar 5", "Mar 6", "UBER *TRIP HELP.UBER.COM", 14.50), ("Mar 9", "Mar 10", "WHOLEFDS MKT #10234", 67.12),
    ("Mar 12", "Mar 12", "NETFLIX.COM", 15.49), ("Mar 15", "Mar 16", "SHELL OIL 57444", 41.30), ("Mar 18", "Mar 18", "CAPITAL ONE MOBILE PYMT", -150.00), ("Mar 21", "Mar 22", "SPOTIFY USA", 11.99)]
CO_ABRIL = [("Apr 2", "Apr 3", "TRADER JOE'S #552", 54.80), ("Apr 6", "Apr 7", "LYFT *RIDE", 18.25), ("Apr 10", "Apr 11", "TARGET 00012345", 82.40), ("Apr 14", "Apr 14", "CAPITAL ONE MOBILE PYMT", -100.00),
    ("Apr 19", "Apr 20", "STARBUCKS STORE 1234", 6.75), ("Apr 24", "Apr 25", "AMZN Mktp US*2K4", -12.99)]
BANCO_ZETA = [("05 mar 2026", "CAFETERIA CENTRAL", "-12.90"), ("08 mar 2026", "ABONO POR TRANSFERENCIA", "400.00"), ("14 mar 2026", "PAGO TARJETA", "-150.00"), ("20 mar 2026", "GASOLINERA DEMO", "-35.60")]

def tabla(path, banco, cols, filas, con_encabezado=True):
    """Tabla con columnas (x, título, alineación 'l'|'r') para probar el lector genérico con distintos diseños. Todo inventado."""
    c = canvas.Canvas(str(path), pagesize=A4); c.setTitle(banco + " - documento de prueba (inventado)")
    c.setFont("Helvetica-Bold", 14); c.drawString(40, 790, banco); c.setFillColorRGB(.8, 0, 0); c.setFont("Helvetica-Bold", 9); c.drawString(40, 770, "DOCUMENTO DE PRUEBA - DATOS INVENTADOS"); c.setFillColorRGB(0, 0, 0)
    c.setFont("Helvetica", 8); y = 720
    if con_encabezado:
        c.setFont("Helvetica-Bold", 8)
        for x, t, a in cols: (c.drawRightString if a == 'r' else c.drawString)(x, y, t)
        y -= 16; c.setFont("Helvetica", 8)
    for f in filas:
        for (x, _, a), v in zip(cols, f):
            if v: (c.drawRightString if a == 'r' else c.drawString)(x, y, v)
        y -= 13
    c.showPage(); c.save()

VARIANTES = {
  "banco-eta.pdf": ("Banco Eta (PRUEBA)", [(40, "Fecha", 'l'), (110, "Descripción", 'l'), (380, "Cargo", 'r'), (450, "Abono", 'r'), (540, "Saldo", 'r')],
    [("02/03/2026", "COMPRA SUPERMERCADO", "85.40", "", "914.60"), ("04/03/2026", "DEPOSITO SUELDO", "", "2,500.00", "3,414.60"), ("09/03/2026", "PAGO SERVICIOS", "120.00", "", "3,294.60")]),
  "banco-theta.pdf": ("Banco Theta (PRUEBA)", [(40, "Date", 'l'), (130, "Details", 'l'), (420, "Amount", 'r'), (520, "Balance", 'r')],
    [("Mar 3, 2026", "COFFEE SHOP", "(4.50)", "495.50"), ("Mar 4, 2026", "PAYROLL DEPOSIT", "1,200.00", "1,695.50"), ("Mar 11, 2026", "ELECTRIC BILL", "(96.20)", "1,599.30")]),
  "banco-iota.pdf": ("Banco Iota (PRUEBA)", [(40, "Fecha", 'l'), (120, "Descripción", 'l'), (290, "Tipo", 'l'), (410, "Monto", 'r'), (480, "Monto neto", 'r'), (545, "Fecha valor", 'r')],
    [("3/15/2026", "Pago de nómina", "Depósito", "$1,000.00", "$1,000.00", "3/15/2026"), ("3/16/2026", "Tienda Demo", "Compra", "-$35.00", "-$35.00", "3/17/2026"), ("3/20/2026", "Cargo mensual", "Comisión", "-$4.99", "-$4.99", "3/20/2026")]),
  "banco-kappa.pdf": ("Banco Kappa (PRUEBA)", [(40, "", 'l'), (120, "", 'l'), (420, "", 'r'), (540, "", 'r')],
    [("03-mar-26", "COMPRA TIENDA LIMA", "S/ 45.00-", "S/ 1,200.00"), ("05-mar-26", "ABONO TRANSFERENCIA", "S/ 300.00", "S/ 1,500.00"), ("10-mar-26", "PAGO LUZ DEL SUR", "S/ 88.30-", "S/ 1,411.70")]),
  "banco-lambda.pdf": ("Banco Lambda (PRUEBA)", [(40, "Datum", 'l'), (120, "Verwendungszweck", 'l'), (500, "Betrag", 'r')],
    [("2026-03-05", "Supermarkt Berlin", "-1.234,56"), ("2026-03-06", "Gehalt", "2.450,00"), ("2026-03-09", "Miete", "-800,00")]),
}

def chime(path, filas, previo=0.00, fin_extra=0.0):
    """Estado INVENTADO de cuenta corriente Chime (mismo orden de columnas y textos que el real; ningún dato real). filas: (fecha m/d/aaaa, descripción, tipo, monto, detalle|None)."""
    dep = round(sum(f[3] for f in filas if f[2] == "Deposit"), 2); fee = round(sum(f[3] for f in filas if f[2] == "Fee"), 2)
    pur = round(sum(f[3] for f in filas if f[2] in ("Purchase", "Direct Debit")), 2); tra = round(sum(f[3] for f in filas if f[2] == "Transfer"), 2)
    fin = round(previo + sum(f[3] for f in filas) + fin_extra, 2)
    d = lambda v: ("-" if v < 0 else "") + "$" + f"{abs(v):,.2f}"
    c = canvas.Canvas(str(path), pagesize=A4); c.setTitle("Chime - documento de prueba (inventado)")
    c.setFont("Helvetica", 7); c.drawString(510, 775, "Member Services"); c.drawString(510, 764, "(000) 000-0000")
    c.setFont("Helvetica", 8); c.drawString(29, 731, "Persona de Prueba"); c.drawString(29, 720, "1 Calle Ejemplo, 1"); c.drawString(29, 710, "Ciudad Ejemplo, NY 10000")
    c.setFont("Helvetica-Bold", 11); c.drawString(29, 657, "Checking Account Statement"); c.setFont("Helvetica", 8)
    c.drawString(29, 634, "Account number"); c.drawString(29, 623, "123456789012345"); c.drawString(29, 602, "Statement period"); c.drawString(29, 591, "March 2026"); c.drawString(92, 591, "(March 01, 2026 - March 31, 2026)")
    c.drawString(29, 573, "Issued by The Bancorp Bank, N.A., Member FDIC"); c.setFillColorRGB(.8, 0, 0); c.drawString(29, 560, "DOCUMENTO DE PRUEBA - DATOS INVENTADOS"); c.setFillColorRGB(0, 0, 0)
    c.setFont("Helvetica-Bold", 9); c.drawString(29, 529, "Summary"); c.setFont("Helvetica", 8); y = 512
    for k, v in ((f"Beginning balance on March 01, 2026", d(previo)), ("Deposits", d(dep)), ("ATM Withdrawals", d(0)), ("Purchases", d(pur)), ("Adjustments", d(0)), ("Transfers", d(tra)), ("Round Up Transfers", d(0)), ("Fees", d(fee)), ("SpotMe Tips", d(0)), ("Ending balance on March 31, 2026", d(fin))):
        c.drawString(29, y, k); c.drawString(215, y, v); y -= 15
    c.setFont("Helvetica-Bold", 9); c.drawString(29, 322, "Transactions"); c.setFont("Helvetica-Bold", 6.5)
    for x, t in ((32, "TRANSACTION DATE"), (122, "DESCRIPTION"), (291, "TYPE"), (386, "AMOUNT"), (434, "NET AMOUNT"), (482, "SETTLEMENT DATE")): c.drawString(x, 304, t)
    c.setFont("Helvetica", 7); y = 287
    for fecha, desc, tipo, monto, det in filas:
        c.drawString(32, y, fecha); c.drawString(122, y, desc); c.drawString(291, y, tipo); c.drawString(390, y, d(monto)); c.drawString(452, y, d(monto)); c.drawString(482, y, fecha); y -= 16
        if det: c.drawString(122, y + 6, det); y -= 8
    c.showPage(); c.save()

CHIME_FILAS = [("3/02/2026", "Empresa Demo, Payroll", "Deposit", 1200.00, "EMPRESA DEMO"), ("3/02/2026", "Moved to Secured Deposit Account", "Transfer", -1200.00, None), ("3/05/2026", "Tienda Ejemplo", "Purchase", -35.50, "TIENDA EJEMPLO CIUDAD NYUS"),
    ("3/05/2026", "Moved from Secured Deposit Account", "Transfer", 35.50, None), ("3/12/2026", "Outbound Instant Transfer Fee", "Fee", -2.50, None), ("3/12/2026", "Moved from Secured Deposit Account", "Transfer", 2.50, None),
    ("3/20/2026", "Direct Debit: Servicio Demo, Payment", "Direct Debit", -20.00, "SERVICIO DEMO,PAYMENT"), ("3/20/2026", "Moved from Secured Deposit Account", "Transfer", 20.00, None)]

def seen(path, creditos, compras, interes=3.10, previo=100.00, extra_impreso=0.0):
    """Estado INVENTADO de tarjeta Seen (mismo orden de secciones y textos que el real; ningún dato real). creditos/compras: (fecha mm/dd/aaaa, descripción, monto positivo)."""
    pagos = round(sum(c[2] for c in creditos if "Payment" in c[1]), 2); otros = round(sum(c[2] for c in creditos if "Payment" not in c[1]), 2)
    buy = round(sum(c[2] for c in compras), 2); fin = round(previo - pagos - otros + buy + interes + extra_impreso, 2)
    d = lambda v: f"${v:,.2f}"
    c = canvas.Canvas(str(path), pagesize=letter); c.setTitle("Seen - documento de prueba (inventado)")
    c.setFont("Helvetica-Bold", 10); c.drawString(513, 749, "Seen Credit Card"); c.setFont("Helvetica", 7); c.drawString(324, 736, "PERSONA DE PRUEBA"); c.drawString(506, 736, "- Account Number *0000")
    c.setFont("Helvetica-Bold", 13); c.drawString(138, 731, "Credit Card Statement"); c.setFont("Helvetica", 7); c.drawString(434, 722, "Bill Period: 03/05/2026 - 04/04/2026")
    c.setFillColorRGB(.8, 0, 0); c.drawString(25, 760, "DOCUMENTO DE PRUEBA - DATOS INVENTADOS"); c.setFillColorRGB(0, 0, 0)
    c.setFont("Helvetica-Bold", 8); c.drawString(418, 694, "Account Summary"); c.setFont("Helvetica", 7)
    for k, v, y in (("Previous Balance", d(previo), 679), ("Payments", d(pagos), 664), ("Other Credits", d(otros), 649), ("Purchases", d(buy), 634), ("Interest Charged", d(interes), 618), ("Fee Charged", d(0), 603), ("New Balance", d(fin), 583), ("Credit Limit", "$500.00", 563), ("Credit Limit Available", d(500 - fin), 548)):
        c.drawString(418, y, k); c.drawRightString(595, y, v)
    c.drawString(27, 489, "Minimum Payment Due"); c.drawString(27, 300, "Card Account Number"); c.drawString(163, 300, "Statement Date"); c.drawString(262, 300, "New Balance"); c.drawString(348, 300, "Minimum Amount Due"); c.drawString(485, 300, "Payment Due Date")
    c.drawString(27, 285, "*0000"); c.drawString(163, 285, "04/05/2026"); c.drawString(262, 285, d(fin)); c.drawString(348, 285, "$25.00"); c.drawString(485, 285, "05/03/2026"); c.showPage()
    c.setFont("Helvetica-Bold", 10); c.drawString(510, 746, "Seen Credit Card"); c.setFont("Helvetica-Bold", 12); c.drawString(89, 729, "Account Activity"); c.setFont("Helvetica", 7)
    for x, t in ((20, "Posted Date"), (136, "Transaction Date"), (258, "Description"), (442, "Card Ending In"), (560, "Amount")): c.drawString(x, 661, t)
    y = 643; c.setFont("Helvetica-Bold", 7); c.drawString(20, y, "Payments, Refunds, and Other Credits"); c.setFont("Helvetica", 7); y -= 17
    for f, desc, m in creditos: c.drawString(20, y, f); c.drawString(136, y, f); c.drawString(258, y, desc); c.drawString(442, y, "*0000"); c.drawRightString(595, y, d(m)); y -= 17
    c.drawString(311, y, "Total Payments, Refunds, And Other Credits For This Period:"); c.drawRightString(595, y, d(pagos + otros)); y -= 18
    c.setFont("Helvetica-Bold", 7); c.drawString(20, y, "Purchases"); c.setFont("Helvetica", 7); y -= 17
    for f, desc, m in compras: c.drawString(20, y, f); c.drawString(136, y, f); c.drawString(258, y, desc); c.drawString(442, y, "*0000"); c.drawRightString(595, y, d(m)); y -= 17
    c.drawString(426, y, "Total Purchases For This Period:"); c.drawRightString(595, y, d(buy)); y -= 20
    c.setFont("Helvetica-Bold", 7); c.drawString(296, y, "Fees"); c.setFont("Helvetica", 7); y -= 16; c.drawString(258, y, "None during this statement period"); y -= 18
    c.setFont("Helvetica-Bold", 7); c.drawString(270, y, "Interest Charged"); c.setFont("Helvetica", 7); y -= 17; c.drawString(258, y, "Interest Charge on Purchases"); c.drawRightString(595, y, d(interes)); c.showPage()
    c.setFont("Helvetica-Bold", 8); c.drawString(23, 682, "Interest Charge Calculation"); c.setFont("Helvetica", 7)
    c.drawString(70, 588, "Purchases"); c.drawString(207, 588, "29.99% (Fixed)"); c.drawString(363, 588, "$100.00"); c.drawString(511, 588, d(interes)); c.showPage(); c.save()

SEEN_CR = [("03/10/2026", "Cash Rewards Redemption", 0.50), ("03/20/2026", "Debit Card Payment from *1111", 40.00)]
SEEN_BUY = [("03/08/2026", "TIENDA EJEMPLO NEW YORK NYUSA", 21.30), ("03/15/2026", "SERVICIO DEMO 8000000000 CAUSA", 25.00), ("03/28/2026", "CAFE DEMO LAKE CITY UTUSA", 9.99)]

def tarjeta(path, banco, cues, cols, filas):
    """Tarjeta de crédito de un banco que Nazca NO conoce, con las pistas típicas (límite, pago mínimo, fecha de pago, tasa). Todo inventado."""
    c = canvas.Canvas(str(path), pagesize=A4); c.setTitle(banco + " - documento de prueba (inventado)")
    c.setFont("Helvetica-Bold", 14); c.drawString(40, 790, banco); c.setFillColorRGB(.8, 0, 0); c.setFont("Helvetica-Bold", 9); c.drawString(40, 772, "DOCUMENTO DE PRUEBA - DATOS INVENTADOS"); c.setFillColorRGB(0, 0, 0)
    c.setFont("Helvetica", 8); y = 750
    for t in cues: c.drawString(40, y, t); y -= 12
    y -= 14; c.setFont("Helvetica-Bold", 8)
    for x, t, a in cols: (c.drawRightString if a == 'r' else c.drawString)(x, y, t)
    y -= 16; c.setFont("Helvetica", 8)
    for f in filas:
        for (x, _, a), v in zip(cols, f): (c.drawRightString if a == 'r' else c.drawString)(x, y, v)
        y -= 13
    c.showPage(); c.save()

def bofa(path, depositos, atm, otras, previo=100.00, extra_impreso=0.0):
    """Estado INVENTADO de cuenta de cheques Bank of America en español (mismos textos y columnas que el real; ningún dato real). Filas: (mm/dd/aa, descripción, monto)."""
    dep = round(sum(f[2] for f in depositos), 2); a = round(sum(f[2] for f in atm), 2); o = round(sum(f[2] for f in otras), 2); fin = round(previo + dep + a + o + extra_impreso, 2)
    d = lambda v: ("-" if v < 0 else "") + f"{abs(v):,.2f}"
    c = canvas.Canvas(str(path), pagesize=letter); c.setTitle("Bank of America - documento de prueba (inventado)")
    c.setFont("Helvetica", 7); c.drawString(400, 694, "Informacion de atencion al cliente"); c.drawString(400, 627, "bankofamerica.com"); c.drawString(400, 607, "Bank of America, N.A.")
    c.drawString(45, 627, "PERSONA DE PRUEBA"); c.setFillColorRGB(.8, 0, 0); c.drawString(45, 650, "DOCUMENTO DE PRUEBA - DATOS INVENTADOS"); c.setFillColorRGB(0, 0, 0)
    c.setFont("Helvetica-Bold", 10); c.drawString(36, 472, "Su Adv SafeBalance Banking"); c.setFont("Helvetica", 8); c.drawString(36, 454, "para el 23 de marzo del 2026 al 20 de abril del 2026"); c.drawString(378, 454, "Número de cuenta: 1234 5678 9012")
    c.setFont("Helvetica-Bold", 9); c.drawString(36, 410, "Resumen de la cuenta"); c.setFont("Helvetica", 8)
    for k, v, y in (("Saldo inicial al 23 de marzo del 2026", "$" + d(previo), 393), ("Depósitos y otros agregados", d(dep), 375), ("Sustracciones de tarjeta de cajero automático", d(a), 356), ("Otras sustracciones", d(o), 329), ("Cargos por servicio", "-0.00", 311), ("Saldo final al 20 de abril del 2026", "$" + d(fin if extra_impreso == 0 else fin), 291)):
        c.drawString(36, y, k); c.drawString(310, y, v)
    c.showPage(); c.showPage()
    c.setFont("Helvetica-Bold", 9); y = 660; c.drawString(36, y, "Depósitos y otros agregados"); c.setFont("Helvetica", 7); y -= 12
    for x, t in ((36, "Fecha"), (91, "Descripción"), (546, "Cantidad")): c.drawString(x, y, t)
    y -= 12
    for f, desc, m in depositos: c.drawString(36, y, f); c.drawString(91, y, desc); c.drawRightString(570, y, d(m)); y -= 12; c.drawString(91, y, "ID:0000000000 PPD"); y -= 12
    c.drawString(36, y, "Total de depósitos y otros agregados"); c.drawString(530, y, "$" + d(dep)); y -= 30
    c.setFont("Helvetica-Bold", 9); c.drawString(36, y, "Retiros y otras sustracciones"); y -= 14; c.setFont("Helvetica", 7); c.drawString(36, y, "Sustracciones de tarjeta de cajero automático (ATM) y de débito"); y -= 12
    for x, t in ((36, "Fecha"), (91, "Descripción"), (546, "Cantidad")): c.drawString(x, y, t)
    y -= 12
    for f, desc, m in atm: c.drawString(36, y, f); c.drawString(91, y, "PURCHASE"); c.drawString(141, y, desc); c.drawRightString(570, y, d(m)); y -= 12
    c.drawString(36, y, "Total de sustracciones de tarjeta de cajero automático (ATM) y de débito"); c.drawString(526, y, "-$" + d(abs(a))); y -= 30
    c.setFont("Helvetica-Bold", 9); c.drawString(36, y, "Otras sustracciones"); y -= 14; c.setFont("Helvetica", 7)
    for x, t in ((36, "Fecha"), (91, "Descripción"), (546, "Cantidad")): c.drawString(x, y, t)
    y -= 12
    for f, desc, m in otras: c.drawString(36, y, f); c.drawString(91, y, desc); c.drawRightString(570, y, d(m)); y -= 12
    c.drawString(36, y, "Total de otras sustracciones"); c.drawString(526, y, "-$" + d(abs(o))); c.showPage(); c.save()

BOFA_DEP = [("03/25/26", "EMPRESA DEMO DES:PAYROLL ID:000 INDN:PERSONA DE PRUEBA CO", 1000.00), ("03/30/26", "Zelle payment from Persona de Prueba Conf# AAAA", 150.50)]
BOFA_ATM = [("03/26/26", "0325 TIENDA EJEMPLO SAN FRANCISCOCA", -42.10), ("03/27/26", "0326 CAFE DEMO LAKE PLACID NY", -6.50), ("04/02/26", "0401 APPLE.COM/BILL 866-712-7753 CA", -9.99)]
BOFA_OTH = [("04/05/26", "Online Banking transfer to SAV 0000 Confirmation# 1", -200.00)]

def apple_card(path, pagos, compras, interes=12.00, previo=500.00, extra_impreso=0.0):
    """Estado INVENTADO de Apple Card (mismas secciones y textos que el real; ningún dato real). pagos: (mm/dd/aaaa, desc, monto negativo); compras: (mm/dd/aaaa, desc, %, monto)."""
    tp = round(sum(p[2] for p in pagos), 2); tc = round(sum(c[3] for c in compras), 2); fin = round(previo + tp + tc + interes + extra_impreso, 2)
    d = lambda v: ("-" if v < 0 else "") + "$" + f"{abs(v):,.2f}"
    c = canvas.Canvas(str(path), pagesize=letter); c.setTitle("Apple Card - documento de prueba (inventado)")
    c.setFont("Helvetica", 9); c.drawString(481, 706, "Statement"); c.drawString(36, 696, "Apple Card Customer"); c.drawString(36, 686, "Persona de Prueba"); c.drawString(502, 686, "Mar 1 — Mar 31, 2026")
    c.setFillColorRGB(.8, 0, 0); c.drawString(36, 720, "DOCUMENTO DE PRUEBA - DATOS INVENTADOS"); c.setFillColorRGB(0, 0, 0)
    c.drawString(36, 507, "Your March Balance"); c.drawString(220, 507, "Minimum"); c.drawString(402, 507, "Payment"); c.drawString(220, 496, "Payment Due"); c.drawString(402, 496, "Due By")
    c.drawString(36, 469, d(fin)); c.drawString(220, 469, "$25.00"); c.drawString(402, 469, "Apr 30, 2026")
    c.drawString(402, 386, "Previous Monthly Balance"); c.drawRightString(570, 386, d(previo)); c.drawString(402, 363, "Previous Total Balance"); c.drawRightString(570, 363, d(previo)); c.drawString(402, 341, "Total Balance"); c.drawRightString(570, 341, d(fin)); c.showPage()
    c.setFont("Helvetica-Bold", 9); c.drawString(36, 635, "Payments"); c.setFont("Helvetica", 7)
    for x, t in ((37, "Date"), (106, "Description"), (551, "Amount")): c.drawString(x, 616, t)
    y = 599
    for f, desc, m in pagos: c.drawString(36, y, f); c.drawString(105, y, desc); c.drawRightString(570, y, d(m)); y -= 20
    c.drawString(36, y, "Total payments for this period"); c.drawRightString(570, y, d(tp)); y -= 40
    c.setFont("Helvetica-Bold", 9); c.drawString(36, y, "Transactions"); c.setFont("Helvetica", 7); y -= 16
    for x, t in ((37, "Date"), (106, "Description"), (416, "Daily Cash"), (551, "Amount")): c.drawString(x, y, t)
    y -= 18
    for f, desc, pc, m in compras: c.drawString(36, y, f); c.drawString(105, y, desc); c.drawString(415, y, pc); c.drawString(446, y, "$0.10"); c.drawRightString(570, y, d(m)); y -= 20
    c.drawString(36, y, "Total Daily Cash this month"); c.drawString(446, y, "$0.40"); y -= 18; c.drawString(36, y, "Total charges, credits and returns"); c.drawRightString(570, y, d(tc)); c.showPage()
    c.setFont("Helvetica-Bold", 9); c.drawString(36, 634, "Daily Cash"); c.drawString(36, 529, "Interest Charged"); c.setFont("Helvetica", 7); c.drawString(36, 502, "Interest charge"); c.drawRightString(570, 502, d(interes)); c.drawString(36, 485, "Total interest for this month"); c.drawRightString(570, 485, d(interes))
    c.drawString(36, 453, "Interest Charges"); c.drawString(305, 453, "Interest Charge Calculation"); c.drawString(305, 443, "Annual Percentage Rate (APR)"); c.drawString(412, 443, "24.74 %"); c.drawString(441, 443, "(variable)")
    c.drawString(36, 36, "Apple Card is issued by Goldman Sachs Bank USA, Salt Lake City Branch."); c.showPage(); c.save()

AC_PAGOS = [("03/10/2026", "Apple Cash payment", -5.00), ("03/20/2026", "ACH Deposit Internet transfer from account ending in 0000", -100.00)]
AC_COMPRAS = [("03/02/2026", "TIENDA EJEMPLO 1 CALLE DEMO CIUDAD NY USA", "2%", 15.29), ("03/05/2026", "CAFE DEMO 2 CALLE DEMO CIUDAD NY USA", "2%", 7.54), ("03/12/2026", "APPLE.COM/BILL ONE APPLE PARK WAY CUPERTINO CA USA", "3%", 6.99), ("03/18/2026", "DEVOLUCION TIENDA EJEMPLO", "2%", -4.00)]

def community_bank(path, filas, previo=100.00, extra_impreso=0.0):
    """Estado INVENTADO de cuenta corriente Community Bank (mismas columnas y textos que el real; ningún dato real). filas: (mm/dd, descripción, monto con signo)."""
    cr = round(sum(m for _, _, m in filas if m > 0), 2); de = round(-sum(m for _, _, m in filas if m < 0), 2); fin = round(previo + cr - de + extra_impreso, 2)
    c = canvas.Canvas(str(path), pagesize=letter); c.setTitle("Community Bank - documento de prueba (inventado)")
    c.setFont("Helvetica", 8); c.drawString(407, 759, "Page:"); c.drawString(488, 759, "1 of 1"); c.drawString(407, 746, "Statement Date:"); c.drawString(488, 746, "04/18/2026"); c.drawString(407, 733, "Primary Account:"); c.drawString(488, 733, "XXXXXX1234")
    c.setFillColorRGB(.8, 0, 0); c.drawString(72, 719, "DOCUMENTO DE PRUEBA - DATOS INVENTADOS"); c.setFillColorRGB(0, 0, 0)
    c.drawString(198, 597, "PERSONA DE PRUEBA"); c.drawString(198, 587, "1 CALLE DEMO"); c.drawString(198, 577, "CIUDAD NY 10001")
    c.setFont("Helvetica-Bold", 8); c.drawString(43, 361, "CBNA SIMPLY CHECKING"); c.drawString(510, 361, "XXXXXX1234"); c.setFont("Helvetica", 8)
    d = lambda v: f"{v:.2f}"
    for y, lab, v in ((345, "Previous Balance", previo), (322, "Checks/Debits", de), (311, "Service Charge", 0), (299, "Interest Paid", 0), (288, "Ending Balance", fin)): c.drawString(43 if lab != "Checks/Debits" else 86, y, lab); c.drawRightString(290, y, d(v))
    c.drawString(67, 334, str(sum(1 for f in filas if f[2] > 0))); c.drawString(86, 334, "Deposits/Credits"); c.drawRightString(290, 334, d(cr))
    c.drawString(313, 345, "Statement Dates"); c.drawString(476, 345, "3/19/26 thru 4/18/26"); c.drawString(313, 334, "Days in the Statement Period"); c.drawString(559, 334, "31")
    c.setFont("Helvetica-Bold", 8); c.drawString(43, 264, "TRANSACTIONS"); c.setFont("Helvetica", 8)
    for x, t in ((43, "Date"), (90, "Description"), (420, "Credits/Debits"), (537, "Balance")): c.drawString(x, 248, t)
    y = 234; run = previo
    for f, desc, m in filas: run = round(run + m, 2); c.drawString(43, y, f); c.drawString(90, y, desc); c.drawRightString(490, y, d(abs(m))); c.drawRightString(575, y, d(run)); y -= 14
    c.drawString(245, 32, "Branch Phone Number: (000)000-0000"); c.showPage(); c.showPage(); c.save()

CB_FILAS = [("03/20", "Payroll Empresa Demo", 800.00), ("03/25", "Debit Card Purchase Tienda Ejemplo", -45.30), ("04/02", "ATM Withdrawal Calle Demo", -60.00), ("04/10", "Service Charge Fee Refund", 1.50)]

def io_tarjeta(path, abonos, consumos, seguro=1.25, previo=0.00, extra_impreso=0.0):
    """Estado INVENTADO de la tarjeta iO (mismos textos y columnas SOLES/DÓLARES que el real; ningún dato real). abonos/consumos: (dd-MES, descripción, monto positivo)."""
    ab = round(sum(a[2] for a in abonos), 2); co = round(sum(c[2] for c in consumos), 2); tot = round(previo - ab + co + seguro + extra_impreso, 2)
    m2 = lambda v: f"{v:.2f}"
    c = canvas.Canvas(str(path), pagesize=A4); c.setTitle("iO - documento de prueba (inventado)"); W = 595
    c.setFont("Helvetica", 9); c.setFillColorRGB(.8, 0, 0); c.drawString(150, 740, "DOCUMENTO DE PRUEBA - DATOS INVENTADOS"); c.setFillColorRGB(0, 0, 0)
    c.drawString(227, 709, "¡Hola, Persona!"); c.drawString(120, 660, "sobre tu Tarjeta de Crédito"); c.drawString(266, 660, "iO"); c.drawString(281, 660, "del"); c.drawString(299, 660, "29/03/2026"); c.drawString(363, 660, "hasta el"); c.drawString(405, 660, "25/04/2026")
    c.drawString(179, 631, "Número de tarjeta de crédito:"); c.drawString(322, 631, "**** **** **** 1234")
    c.drawString(54, 592, "Tu línea de crédito"); c.drawString(236, 592, "Tu saldo disponible"); c.drawString(419, 592, "Tu línea de crédito utilizada"); c.drawString(54, 580, "actual es:"); c.drawString(236, 580, "al 25/04/2026 es:")
    c.drawString(54, 556, "S/500.00"); c.drawString(236, 556, "S/" + m2(500 - tot)); c.drawString(419, 556, "S/" + m2(tot))
    c.drawString(79, 484, "ÚLTIMO DÍA DE PAGO"); c.drawString(297, 484, "SOLES"); c.drawString(447, 484, "DÓLARES"); c.drawString(272, 464, "Pago total del mes"); c.drawString(430, 464, "Pago total del mes")
    c.drawString(114, 455, "Domingo"); c.drawString(282, 445, "S/" + m2(tot)); c.drawString(449, 445, "$0.00"); c.drawString(101, 436, "12 may 26"); c.drawString(284, 421, "Pago mínimo"); c.drawString(442, 421, "Pago mínimo"); c.drawString(292, 403, "S/25.00"); c.drawString(454, 403, "$0.00")
    c.showPage()
    c.setFont("Helvetica-Bold", 11); c.drawString(196, 769, "Detalle de movimientos"); c.setFont("Helvetica", 9); c.drawString(247, 704, "Ciclo de facturación:"); c.drawString(233, 689, "29/03/2026"); c.drawString(293, 689, "al"); c.drawString(304, 689, "25/04/2026")
    def tabla(y, titulo, filas, neg):
        c.setFont("Helvetica-Bold", 10); c.drawString(211, y, titulo); y -= 26; c.setFont("Helvetica", 8)
        for x, t in ((42, "FECHA"), (170, "DESCRIPCIÓN"), (439, "SOLES"), (513, "DÓLARES")): c.drawString(x, y, t)
        y -= 26
        for f, d, m in filas: c.drawString(42, y, f); c.drawString(170, y, d); c.drawString(447, y, m2(m)); y -= 26
        c.drawString(42, y, "SUBTOTAL"); c.drawString(442, y, m2(sum(f[2] for f in filas))); c.drawString(523, y, "0.00"); return y - 40
    y = tabla(631, "Abonos", abonos, False); y = tabla(y, "Consumos directos (Sin cuotas)", consumos, True)
    c.showPage()
    c.setFont("Helvetica-Bold", 10); c.drawString(198, 778, "Plan de cuotas de los próximos 6 meses"); c.setFont("Helvetica-Bold", 11); c.drawString(185, 636, "Resumen de movimientos"); c.setFont("Helvetica", 9); c.drawString(198, 498, "Tu pago del mes esta compuesto por:")
    c.setFont("Helvetica", 8); c.drawString(62, 471, "DESCRIPCIÓN"); c.drawString(357, 471, "SOLES"); c.drawString(477, 471, "DÓLARES")
    for y, sg, lab, v in ((446, "", "SALDO PENDIENTE DEL MES ANTERIOR", previo), (420, "-", "ABONOS DEL MES ACTUAL", ab), (394, "+", "CONSUMOS DIRECTOS (SIN CUOTAS)", co), (368, "+", "CONSUMOS EN CUOTAS", 0), (342, "+", "INTERÉS COMPENSATORIO", 0), (316, "+", "INTERÉS MORATORIO", 0), (291, "+", "SEGURO DE DESGRAVAMEN", seguro)):
        if sg: c.drawString(48, y, sg)
        c.drawString(59 if sg else 62, y, lab); c.drawString(364, y, m2(v)); c.drawString(488, y, "0.00")
    c.drawString(48, 252, "="); c.drawString(61, 252, "PAGO TOTAL DEL MES"); c.drawString(353, 252, m2(tot)); c.drawString(483, 252, "0.00"); c.drawString(62, 225, "PAGO MÍNIMO DEL MES"); c.drawString(360, 225, "25.00"); c.drawString(483, 225, "0.00")
    c.showPage()
    c.setFont("Helvetica", 8); c.drawString(199, 706, "TASAS"); c.drawString(452, 706, "SOLES"); c.drawString(514, 706, "DÓLARES"); c.drawString(199, 677, "TEA de Interés compensatorio"); c.drawString(457, 677, "32.99%"); c.drawString(531, 677, "32.99%")
    c.showPage(); c.save()

IO_ABONOS = [("06-ABR", "DEVOLUCIÓN DE COMPRA - TIENDA EJEMPLO", 4.50), ("17-ABR", "ABONO CON CASHBACK", 12.30)]
IO_CONSUMOS = [("29-MAR", "CAFE DEMO CENTRO", 12.80), ("30-MAR", "TAXI DEMO PE", 9.60), ("02-ABR", "SUPER DEMO SAN MIGUEL", 85.40), ("11-ABR", "TIENDA EJEMPLO ONLINE", 39.99), ("21-ABR", "FARMACIA DEMO", 17.25)]

CAPITAL_ONE_OLD = [("Mar 3", "Mar 4", "AMAZON MKTPLACE PMTS", "$23.99"), ("Mar 5", "Mar 6", "UBER *TRIP HELP.UBER.COM", "$14.50"), ("Mar 9", "Mar 10", "WHOLEFDS MKT #10234", "$67.12"),
    ("Mar 12", "Mar 12", "NETFLIX.COM", "$15.49"), ("Mar 15", "Mar 16", "SHELL OIL 57444", "$41.30"), ("Mar 18", "Mar 18", "CAPITAL ONE MOBILE PYMT", "-$150.00"), ("Mar 21", "Mar 22", "SPOTIFY USA", "$11.99")]
BANCO_EQUIS = [("02/03/2026", "SUPERMERCADO LA ESQUINA", "-85.40"), ("04/03/2026", "DEPOSITO SUELDO EMPRESA DEMO", "2,500.00"), ("07/03/2026", "TRANSFERENCIA A JUAN PEREZ", "-300.00"),
    ("11/03/2026", "FARMACIA CENTRAL", "-42.75"), ("16/03/2026", "PAGO LUZ ELECTRICA", "-96.20"), ("23/03/2026", "RETIRO CAJERO", "-200.00")]

if __name__ == "__main__":
    bcp(OUT / "bcp-ahorros.pdf", ("01/03/26", "31/03/26"), 120.30, MARZO)
    bcp(OUT / "bcp-ahorros-enero.pdf", ("01/01/26", "31/01/26"), 35.10, ENERO)
    bcp(OUT / "bcp-no-cuadra.pdf", ("01/03/26", "31/03/26"), 120.30, MARZO, total_cargos_impreso=1234.56)
    bcp(OUT / "bcp-malicioso.pdf", ("01/03/26", "31/03/26"), 10.00, MALICIOSO)
    interbank(OUT / "interbank-ahorros.pdf", "DEL 28 DE FEBRERO AL 27 DE MARZO", "MARZO", 220.40, IB_MARZO)
    interbank(OUT / "interbank-enero.pdf", "DEL 29 DE DICIEMBRE AL 27 DE ENERO", "ENERO", 80.00, IB_ENERO, fin="27/01")
    interbank(OUT / "interbank-no-cuadra.pdf", "DEL 28 DE FEBRERO AL 27 DE MARZO", "MARZO", 220.40, IB_MARZO, total_gastos_impreso=999.99)
    interbank(OUT / "interbank-dolares.pdf", "DEL 1 AL 30 DE NOVIEMBRE", "NOVIEMBRE", 100.00, [("04/11/2026", "TRANSF WEB/APP", +50.00), ("09/11/2026", "Amazon", -19.99)], producto="CUENTA SIMPLE DÓLARES", fin="30/11")
    subprocess.run(["qpdf", "--encrypt", "12345678", "12345678", "256", "--", str(OUT / "bcp-ahorros.pdf"), str(OUT / "bcp-ahorros-clave.pdf")], check=True)
    # otro banco: mismo tipo de tabla pero no es el BCP
    c = canvas.Canvas(str(OUT / "otro-banco.pdf"), pagesize=A4); c.setFont("Helvetica-Bold", 9); c.drawString(40, 780, "Banco Ejemplo · Estado de cuenta")
    c.setFont("Helvetica", 7); c.drawString(40, 700, "01/03/2026  COMPRA EJEMPLO  -12.50"); c.showPage(); c.save()
    # PDF sin texto (como una foto escaneada): solo un dibujo
    c = canvas.Canvas(str(OUT / "sin-texto.pdf"), pagesize=A4); c.rect(50, 50, 200, 100); c.showPage(); c.save()
    n = capital_one(OUT / "capital-one-marzo.pdf", "Mar 1, 2026", "Mar 31, 2026", CO_MARZO, 0.00)
    capital_one(OUT / "capital-one-abril.pdf", "Apr 1, 2026", "Apr 30, 2026", CO_ABRIL, n, vence="May 25, 2026")
    capital_one(OUT / "capital-one-no-cuadra.pdf", "Mar 1, 2026", "Mar 31, 2026", CO_MARZO, 0.00, total_compras_impreso=999.99)
    capital_one_nuevo(OUT / "capital-one-nuevo.pdf", CO_NUEVO)
    capital_one_nuevo(OUT / "capital-one-nuevo-no-cuadra.pdf", CO_NUEVO, impreso_nuevo=999.99)
    falso(OUT / "banco-zeta-falso.pdf", "Banco Zeta (PRUEBA)", "Extracto de movimientos - Marzo 2026", BANCO_ZETA, [(40, "Fecha"), (130, "Detalle"), (430, "Importe")], "Fin del extracto")
    falso(OUT / "banco-equis-falso.pdf", "Banco Equis (PRUEBA)", "Estado de cuenta - Cuenta corriente 000-0000000 - Marzo 2026", BANCO_EQUIS,
          [(40, "Fecha"), (130, "Descripcion"), (430, "Monto")], "Saldo final 1,775.65")
    for nombre, (banco, cols, filas) in VARIANTES.items(): tabla(OUT / nombre, banco, cols, filas, con_encabezado=not nombre.startswith("banco-kappa"))
    chime(OUT / "chime-checking.pdf", CHIME_FILAS)
    chime(OUT / "chime-no-cuadra.pdf", CHIME_FILAS, fin_extra=5.00)
    c = canvas.Canvas(str(OUT / "sin-movimientos.pdf"), pagesize=A4); c.setFont("Helvetica-Bold", 12); c.drawString(40, 780, "Banco Ejemplo - Informacion general"); c.setFont("Helvetica", 8)
    c.drawString(40, 750, "Este documento no trae movimientos, solo texto informativo sobre tu cuenta."); c.showPage(); c.save()
    seen(OUT / "seen-tarjeta.pdf", SEEN_CR, SEEN_BUY)
    seen(OUT / "seen-no-cuadra.pdf", SEEN_CR, SEEN_BUY, extra_impreso=7.00)
    tarjeta(OUT / "tarjeta-omega.pdf", "Omega Bank Visa Card (PRUEBA)", ["Credit Card Statement - Account ending in 7788", "Statement closing date: Apr 5, 2026", "Previous Balance $120.00   New Balance $155.50", "Credit Limit $2,000.00", "Minimum Payment Due $25.00", "Payment Due Date: Apr 30, 2026", "Purchase APR 27.99%"],
        [(40, "Date", 'l'), (120, "Description", 'l'), (540, "Amount", 'r')],
        [("Mar 8", "GROCERY MART #44", "$62.10"), ("Mar 12", "ONLINE STORE", "$18.40"), ("Mar 20", "PAYMENT THANK YOU", "-$100.00"), ("Mar 27", "GAS STATION 12", "$40.00"), ("Apr 2", "RESTAURANT DEMO", "$15.00")])
    tarjeta(OUT / "tarjeta-sigma.pdf", "Banco Sigma - Tarjeta de crédito Visa (PRUEBA)", ["Estado de cuenta de tarjeta de crédito - terminada en 5566", "Fecha de corte: 05/04/2026", "Saldo anterior S/ 300.00   Nuevo saldo S/ 365.00", "Línea de crédito S/ 5,000.00", "Pago mínimo S/ 60.00", "Fecha límite de pago: 25/04/2026", "TEA 49.90%"],
        [(40, "Fecha", 'l'), (120, "Descripción", 'l'), (540, "Importe", 'r')],
        [("08/03/2026", "COMPRA SUPERMERCADO", "-S/ 120.00"), ("15/03/2026", "PAGO RECIBIDO GRACIAS", "S/ 300.00"), ("22/03/2026", "COMPRA FARMACIA", "-S/ 45.00"), ("30/03/2026", "COMPRA RESTAURANTE", "-S/ 80.00")])
    bofa(OUT / "bofa-cheques.pdf", BOFA_DEP, BOFA_ATM, BOFA_OTH)
    bofa(OUT / "bofa-no-cuadra.pdf", BOFA_DEP, BOFA_ATM, BOFA_OTH, extra_impreso=3.00)
    apple_card(OUT / "apple-card.pdf", AC_PAGOS, AC_COMPRAS)
    apple_card(OUT / "apple-card-no-cuadra.pdf", AC_PAGOS, AC_COMPRAS, extra_impreso=3.00)
    community_bank(OUT / "community-bank.pdf", CB_FILAS)
    community_bank(OUT / "community-bank-no-cuadra.pdf", CB_FILAS, extra_impreso=2.00)
    io_tarjeta(OUT / "io-tarjeta.pdf", IO_ABONOS, IO_CONSUMOS)
    io_tarjeta(OUT / "io-no-cuadra.pdf", IO_ABONOS, IO_CONSUMOS, extra_impreso=2.00)
    subprocess.run(["qpdf", "--encrypt", "12345678", "12345678", "256", "--", str(OUT / "io-tarjeta.pdf"), str(OUT / "io-tarjeta-clave.pdf")], check=True)
    print("listo")
