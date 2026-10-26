#!/usr/bin/env python3
"""Genera los Excel INVENTADOS de prueba de Yape (nombres, comercios y montos son de mentira). Uso: python3 dev/tests/xlsx/hacer-xlsx.py
 - yape-reporte.xlsx: igual que el que baja la app (textos en línea, sin sharedStrings).
 - yape-reporte-compartidas.xlsx: mismo contenido hecho con openpyxl (textos compartidos)."""
import zipfile, pathlib
from xml.sax.saxutils import escape
AQUI = pathlib.Path(__file__).parent
FILAS = [  # tipo, origen, destino, monto, mensaje, fecha
 ('PAGASTE', 'Ana Prueba*', 'Tienda Ejemplo SAC', '16.08', '', '20/10/2026 13:10:26'),
 ('TE PAGÓ', 'Luis Demo*', 'Ana Prueba*', '30.00', '', '19/10/2026 11:22:12'),
 ('PAGASTE', 'Ana Prueba*', 'Mario Fic*', '200.00', 'Alquiler de prueba', '19/10/2026 14:22:49'),
 ('TE PAGÓ', 'PLIN - CARLA DEMO', 'ANA PRUEBA DE LOS TESTS', '10.50', '', '18/10/2026 20:18:52'),
 ('PAGASTE', 'ANA PRUEBA DE LOS TESTS', 'DELIVERY EJEMPLO', '32.20', 'Pago por internet: Nº 1775279113188', '06/10/2026 11:58:22'),
 ('TE PAGÓ', 'YP DELIVERY EJEMPLO', 'DELIVERY EJEMPLO', '10.76', 'Devolución Pago por internet: Nº 1775279113188', '06/10/2026 12:55:31'),
 ('PAGASTE', 'Ana Prueba*', 'Rosa Fic*', '1,250.00', '', '01/10/2026 09:00:00'),
]
CAB = ('Tipo de Transacción', 'Origen', 'Destino', 'Monto', 'Mensaje', 'Fecha de operación')
def celda(ref, v):
    return '<c r="%s" t="inlineStr"><is><r><t xml:space="preserve">%s</t></r></is></c>' % (ref, escape(v)) if v != '' else '<c r="%s" t="inlineStr"></c>' % ref
def hoja():
    filas = ['<row r="2">' + celda('A2', 'Reporte de Movimientos') + '</row>', '<row r="3">' + celda('A3', 'DOCUMENTO DE PRUEBA - datos inventados') + '</row>', '<row r="5">' + ''.join(celda('ABCDEF'[i] + '5', c) for i, c in enumerate(CAB)) + '</row>']
    for n, f in enumerate(FILAS, 6): filas.append('<row r="%d">' % n + ''.join(celda('ABCDEF'[i] + str(n), c) for i, c in enumerate(f)) + '</row>')
    return '<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>' + ''.join(filas) + '</sheetData></worksheet>'
def hacer():
    with zipfile.ZipFile(AQUI / 'yape-reporte.xlsx', 'w', zipfile.ZIP_DEFLATED) as z:
        z.writestr('[Content_Types].xml', '<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="xml" ContentType="application/xml"/><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>')
        z.writestr('_rels/.rels', '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>')
        z.writestr('xl/workbook.xml', '<?xml version="1.0"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Movimientos" sheetId="1" r:id="rId1"/></sheets></workbook>')
        z.writestr('xl/_rels/workbook.xml.rels', '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>')
        z.writestr('xl/worksheets/sheet1.xml', hoja())
    try:
        import openpyxl
        wb = openpyxl.Workbook(); ws = wb.active; ws.title = 'Movimientos'
        ws['A2'] = 'Reporte de Movimientos'; ws['A3'] = 'DOCUMENTO DE PRUEBA - datos inventados'; ws.append([]); ws.append([]); ws.append(list(CAB))
        for f in FILAS: ws.append([c if c != '' else None for c in f])
        wb.save(AQUI / 'yape-reporte-compartidas.xlsx')
    except ImportError:
        print('Sin openpyxl: solo se hizo yape-reporte.xlsx')
if __name__ == '__main__': hacer(); print('Listo')
