#!/usr/bin/env python3
"""Genera los PDF INVENTADOS que usa dev/tests/nazca-pdf.mjs (nombres, cuentas y montos falsos; ningún dato real).
Imitan el diseño del "Estado de Cuenta de Ahorros Cuenta Digital BCP": mismas posiciones de columnas, fechas sin año (30SET), monto sin signo
(cargo o abono según la columna), marcas * y 1, y TOTAL MOVIMIENTO / SALDO al final.
Uso:  python3 dev/tests/pdf/hacer-pdfs.py      (necesita reportlab y qpdf; los PDF ya generados están en esta carpeta, no hace falta correrlo)"""
import subprocess, pathlib
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A4

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

if __name__ == "__main__":
    bcp(OUT / "bcp-ahorros.pdf", ("01/03/26", "31/03/26"), 120.30, MARZO)
    bcp(OUT / "bcp-ahorros-enero.pdf", ("01/01/26", "31/01/26"), 35.10, ENERO)
    bcp(OUT / "bcp-no-cuadra.pdf", ("01/03/26", "31/03/26"), 120.30, MARZO, total_cargos_impreso=1234.56)
    bcp(OUT / "bcp-malicioso.pdf", ("01/03/26", "31/03/26"), 10.00, MALICIOSO)
    subprocess.run(["qpdf", "--encrypt", "12345678", "12345678", "256", "--", str(OUT / "bcp-ahorros.pdf"), str(OUT / "bcp-ahorros-clave.pdf")], check=True)
    # otro banco: mismo tipo de tabla pero no es el BCP
    c = canvas.Canvas(str(OUT / "otro-banco.pdf"), pagesize=A4); c.setFont("Helvetica-Bold", 9); c.drawString(40, 780, "Banco Ejemplo · Estado de cuenta")
    c.setFont("Helvetica", 7); c.drawString(40, 700, "01/03/2026  COMPRA EJEMPLO  -12.50"); c.showPage(); c.save()
    # PDF sin texto (como una foto escaneada): solo un dibujo
    c = canvas.Canvas(str(OUT / "sin-texto.pdf"), pagesize=A4); c.rect(50, 50, 200, 100); c.showPage(); c.save()
    print("listo")
