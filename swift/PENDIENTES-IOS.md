# Plata iOS (SwiftUI nativo) — estado y pendientes

Documento para pasarle a otra IA o a otra persona. Actualizado: 28 oct 2026.

## Contexto

- Repo `leoricharte/Plata`, rama **`swift-nativo`**. App en `swift/PlataApp` (target `Plata`), núcleo en `swift/PlataCore` (Swift Package).
- La web `dev/app/src/app.html` es la **base y la referencia**: la app nativa debe ser un port casi 1:1 (textos, orden, tamaños, espaciados, colores, «personalidad»). Solo los iconos pasan a SF Symbols.
- Idiomas objetivo: **español e inglés** únicamente (hoy todo está en español, escrito a mano en el código).
- El perfil es un JSON sin esquema (v3). `PlataCore` lo maneja con `JSONValue` y replica el motor de la web (calc, projection, simImpact, payoff, genEvents, etc.), verificado contra la web. `AppModel` (`@Observable`) hace `commit {}` (sella con `SyncStamper` y guarda).
- Piso iOS 18. En iOS 26+ se usa Liquid Glass; la barra de pestañas es la **nativa del sistema** (`TabView` con `Tab`). El «+» está en la barra de herramientas superior (`AddMenuButton`).
- Proyecto con **XcodeGen**: al añadir archivos nuevos, correr `cd swift/PlataApp && xcodegen`. Setup de una Mac nueva: `bash swift/tools/setup-mac.sh`.
- CI: `.github/workflows/swift.yml` compila la app y corre las pruebas de `PlataCore` en macOS en cada push a `swift-nativo`.
- Valores de diseño de la web: radio de tarjeta 26 (scard 22), acento `#22B573`, texto verde `#138A55`, `.lbl` 15 gris, tile 46 radio 13, h1 34 bold con tracking −0.035em, fondo de hojas `#F4F4F8`, botón primario 54 pt negro en píldora, `.seg` cápsula, campo `.mini` 40 pt radio 12, `.linkrow` mín. 44 en color acento. Ayudas de formato: `fmt`=`f.whole`, `fmt2`=`f.exact`, `dlabel`=`Spanish.dateShort`.

## Ya hecho

Resumen (KPIs, próximos ingresos/gastos, mes, presupuesto, categorías, cuentas, «Más»), Movimientos, detalle de movimiento (editar/eliminar), Mes (nota, filtro, paginación), Presupuesto (anillo, límites, servicios), Proyección (calendario, gráfica, ingresos/gastos previstos, trabajos, simulaciones), Ahorro (anillo, metas, aportar), Cuentas (débito, crédito, intereses), Ajustes y Perfil, splash verde, barra del sistema.
Hojas: movimiento nuevo/editar, transferir, ingreso previsto, gasto previsto, pago de crédito previsto, trabajo, simular gasto/pago (activar, ejecutar), meta de ahorro, aportar.

## Pendientes

### Formularios y acciones (muchos botones muestran hoy «Llega en la siguiente versión»)
1. **Cuenta de débito**: crear/editar/eliminar (nombre, últimos 4, tipo corriente/ahorros/efectivo, rendimiento, moneda, saldo, color, icono) y ocultar.
2. **Tarjeta o préstamo**: crear/editar/eliminar (tipo, límite, interés anual, pago mensual, día de pago, saldo adeudado, color, icono).
3. **Servicios y suscripciones**: crear/editar/eliminar (nombre, día de cobro, cuenta, moneda, monto).
4. **Categorías y límites**: crear/renombrar/eliminar categoría (color, icono, límite mensual) y **sets de presupuesto** (`bsets`).
5. **Posponer** un ingreso/gasto previsto o pendiente, y **confirmar** lo «Por confirmar» (confirmar, ajustar monto, adelantar).
6. **Pago de crédito real** (registrar pago desde la pantalla de tarjeta) y **simular pago extra** de deuda.
7. **Acciones de fila**: deslizar para editar/eliminar, menús de **ordenar** (cuentas, tarjetas, categorías) y filtros (anillo de deuda).
8. Detalle de movimiento: «Posponer», extras de trabajo, pares de transferencia.
9. Editar meta: historial de aportes (`log`), consejos bajo cada meta (`savingInsight`).

### Pantallas y bloques del Resumen
10. **Insights**: banners, evaluación mensual F→S, «half-time», revisión, tendencias, consejos por pantalla (presupuesto, ahorro, deuda).
11. **Franja de Plata Cloud** (sincronización) en Resumen; pantalla y flujo de Plata Cloud (cuenta, sincronizar, conflictos; `Merge` ya existe en el núcleo).
12. **Widgets / vistas personalizables** del Resumen (`WIDGETS` de la web) si se decide portarlos.
13. **Novedades**, **Opinión**, **Transparencia** (hoy apuntan a «soon»).
14. **Ahorro**: resto de la web si falta algo (revisar `renderAhorro`).

### Datos, importación y ajustes
15. **Importar de Nazca** (flujo por banco: BCP, Interbank, etc.) y otros importadores.
16. **Cambio de moneda principal** (flujo completo), monedas activas, tipo de cambio.
17. Perfil: **Idioma**, **Tema** (claro/oscuro/auto), **Tutorial**, avatar/color.
18. Cargar/guardar archivo de perfil (hay base), exportar, borrar todo, perfiles demo.
19. Bienvenida / onboarding (`showWelcome`, niveles de tutorial).
20. Notificaciones / recordatorios (si se decide).

### Calidad visual y plataforma
21. **Inglés**: extraer todos los textos a `Localizable.xcstrings`; revisar fechas, plurales y moneda.
22. Revisión visual 1:1 contra la web pantalla por pantalla (espaciados, tamaños, pesos tipográficos, colores en modo oscuro).
23. Etiquetas curvas del anillo (la web las dibuja curvadas), logos de bancos, logo «Estudio 22» en Ajustes.
24. Pestañas en pantallas empujadas: ocultar barra en Presupuesto/Proyección/Ahorro/Cuentas si empujan detalles (hoy solo Resumen usa `path`).
25. Accesibilidad (VoiceOver, Dynamic Type, contraste) y soporte iPad (si aplica).
26. Rendimiento y pruebas: más pruebas en `PlataCore` para las funciones nuevas de `ProfileEditor` (transferencia, previstos, trabajo, simulaciones, metas), pruebas de UI básicas.

### Publicación
27. Firma: `DEVELOPMENT_TEAM` en `project.yml`, Bundle ID `net.plataapp.plata`, iconos, capturas.
28. TestFlight y App Store (cuenta Apple Developer ya iniciada), política de privacidad, ficha.

## Cómo trabajar
- Siempre abrir primero la parte equivalente en `dev/app/src/app.html` y copiar textos, orden y medidas.
- Lógica de negocio en `PlataCore` (con pruebas), no en las vistas.
- Después de cada cambio: push a `swift-nativo` y mirar el resultado del workflow `Swift` en GitHub Actions.
