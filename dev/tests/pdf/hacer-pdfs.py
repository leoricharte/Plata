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
    print("listo")
