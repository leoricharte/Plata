# Plata iOS (SwiftUI nativo) — estado y pendientes

Documento para pasarle a otra IA o a otra persona. Actualizado: 29 oct 2026. Avance estimado: **~75 %** del port (una cifra anterior de ~90 % estaba inflada: faltaba Revisión y Nazca no lee PDFs reales). Es una estimación: lo que más falta es el arreglo de lectura de PDF, la revisión visual y pruebas con datos reales.

## ESTADO AL PAUSAR (lo primero que hay que leer)

**Rama `swift-nativo`, todo subido. Último CI (29 oct, versión 5.0 build 9): verde**, incluida la prueba de PDF que antes fallaba. Lo que sigue sin confirmarse es la lectura de estados de cuenta reales en un iPhone (Apple Card, BBVA, BCP ahorros). Texto histórico de la pausa del 28 oct, ya resuelto en CI: la prueba `NazcaPDFReadersTests.testReadersOnPdfKitText` estaba en rojo.

### 1. Nazca y los PDF reales en iPhone (en curso: se cambió el lector)

PDFKit entrega las posiciones de las letras desfasadas en varios PDF reales (Apple Card, BBVA, BCP ahorros), así que los detectores no encontraban nada. En vez de seguir arreglando PDFKit, la app ahora lee los PDF con **el mismo código de la web**: pdf.js + `nazca-pdf.js` dentro de un WKWebView oculto (`PlataCore/.../Nazca/PDF/NazcaPDFWeb.swift`). PDFKit queda solo como respaldo si el lector web no está disponible.

- **Una sola fuente:** `swift/tools/sync-pdfjs.sh` copia `dev/vendor/pdfjs/*` y `dev/app/src/core/nazca/pdf.js` a `PlataCore/Sources/PlataCore/pdfjs/`. La CI corre `sync-pdfjs.sh --check` y falla si las copias se desvían. **Si cambias el lector de PDF en la web, corre el script y sube las copias.**
- **Seguridad:** esquema propio `plata-pdf://` (sin red), CSP `default-src 'none'` sin scripts en línea, regla de contenido que bloquea http/https, almacenamiento no persistente, navegación cerrada y una vista nueva por PDF. La clave del PDF solo se usa para abrirlo.
- **Verificado:** en un navegador, la misma página lee los 59 PDF de prueba con resultados idénticos a la web (textos y posiciones) y sin pedir nada a la red. **Falta confirmar en CI** (WKWebView real en macOS): `testWebBridgeIsIdenticalToTheWeb` y `testReadersOnWebBridgeText`. Si fallan por cargar módulos desde el esquema propio, ver `pdfjs/boot.js`. Después, probar en el teléfono con el PDF real de Apple Card.

### 2. Pendientes para publicar
- **TestFlight desde GitHub** (`.github/workflows/testflight.yml`): hacen falta 3 secretos en GitHub (Settings → Secrets and variables → Actions) que debe crear el usuario: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` (contenido del `.p8` de una llave de la API de App Store Connect con rol App Manager). Team `8YMVGT4T6Q`, bundle `net.plataapp.plata`, `CURRENT_PROJECT_VERSION` "4". Sin ellos solo se instala con ▶ en Xcode.
- **Web (del usuario):** hacer merge del build 464 de la web a `main` y desplegar el worker. Si se toca la web: `SWATCH` (2 colores) y `APP_BUILD` 465.
- Pulido: etiquetas curvas del anillo, VoiceOver, revisión visual 1:1 contra la web, metadatos y capturas para App Store.

### Estimado de lo que falta (≈ 8–13 h de trabajo, con ciclos de CI de 8–10 min)
Nazca 1–2 h · etiquetas curvas 1–2 h · VoiceOver 2–3 h · revisión visual 1:1 3–5 h (abierto) · metadatos 1 h.

### Cómo se trabaja aquí (importante)
- **No hay Swift local**: todo se verifica con el workflow `Swift` (`macos-26`). Para leer por qué falló: `gh api repos/leoricharte/Plata/actions/runs/<id>/jobs` y `gh api repos/leoricharte/Plata/check-runs/<job_id>/annotations` (los logs completos dan «Forbidden»). Un push cancela la corrida en curso.
- El paso de pruebas usa `pipefail` + `tee test.log`: un fallo se ve de verdad (antes estaba oculto por `| tail`; cualquier afirmación vieja de «las pruebas pasan» era no verificada).
- **Vectores dorados:** `swift/tools/gen-*.mjs` ejecutan el JS real de la web (`web-engine.mjs`, `load({today, entry:[...]})`) y escriben `PlataCore/Tests/PlataCoreTests/Fixtures/*.json`. `.gitignore` ignora `*.json` pero tiene excepción `!swift/**/Fixtures/*.json`.
- **Inglés:** `swift/tools/i18n/extras_en.txt` (`es ¦ en`) + `python3 swift/tools/i18n/gen_en.py`; `check_gaps.py` lista lo que falta. `Tr.t` / `Tr.f`.
- **Revisión** (nuevo): motor `PlataCore/Sources/PlataCore/Review.swift`, acciones `PlataApp/Plata/ReviewActions.swift`, vista `ReviewView.swift`, estado en `AppModel` (`reviewCards`, `reviewAccept`, `reviewDismiss`, …), generador `tools/gen-review-vectors.mjs`, prueba `ReviewTests.swift`. Falta probarla a mano en el teléfono.
- **Preferencias del usuario (fundador/diseñador de producto, habla español, programa con IA):** hablarle en español, directo y corto. Se dice «break» o «pausa» cuando quiere parar: hacer commit + push y darle `cd ~/Plata && git pull && cd swift/PlataApp && xcodegen` (luego ▶ en Xcode), **incluyendo siempre el porcentaje de avance del port y cómo va**, con cifras honestas. Mientras no diga «break», seguir avanzando sin detenerse entre lotes.
- Commits terminan con las líneas `Co-Authored-By` / `Claude-Session` que indique el sistema.

## Contexto

- Repo `leoricharte/Plata`, rama **`swift-nativo`**. App en `swift/PlataApp` (target `Plata`), núcleo en `swift/PlataCore` (Swift Package).
- La web `dev/app/src/app.html` es la **base y la referencia**: la app nativa debe ser un port casi 1:1 (textos, orden, tamaños, espaciados, colores, «personalidad»). Solo los iconos pasan a SF Symbols.
- Idiomas objetivo: **español e inglés** únicamente. El código está en español; el inglés se traduce en ejecución con `Tr.swift` (ver punto 21).
- El perfil es un JSON sin esquema (v3). `PlataCore` lo maneja con `JSONValue` y replica el motor de la web (calc, projection, simImpact, payoff, genEvents, etc.), verificado contra la web. `AppModel` (`@Observable`) hace `commit {}` (sella con `SyncStamper` y guarda).
- Piso iOS 18. En iOS 26+ se usa Liquid Glass; la barra de pestañas es la **nativa del sistema** (`TabView` con `Tab`). El «+» está en la barra de herramientas superior (`AddMenuButton`).
- Proyecto con **XcodeGen**: al añadir archivos nuevos, correr `cd swift/PlataApp && xcodegen`. Setup de una Mac nueva: `bash swift/tools/setup-mac.sh`.
- CI: `.github/workflows/swift.yml` compila la app y corre las pruebas de `PlataCore` en macOS en cada push a `swift-nativo`.
- Valores de diseño de la web: radio de tarjeta 26 (scard 22), acento `#22B573`, texto verde `#138A55`, `.lbl` 15 gris, tile 46 radio 13, h1 34 bold con tracking −0.035em, fondo de hojas `#F4F4F8`, botón primario 54 pt negro en píldora, `.seg` cápsula, campo `.mini` 40 pt radio 12, `.linkrow` mín. 44 en color acento. Ayudas de formato: `fmt`=`f.whole`, `fmt2`=`f.exact`, `dlabel`=`Spanish.dateShort`.

## Ya hecho

Resumen (KPIs, próximos ingresos/gastos, mes, presupuesto, categorías, cuentas, «Más»), Movimientos, detalle de movimiento (editar/eliminar), Mes (nota, filtro, paginación), Presupuesto (anillo, límites, servicios), Proyección (calendario, gráfica, ingresos/gastos previstos, trabajos, simulaciones), Ahorro (anillo, metas, aportar), Cuentas (débito, crédito, intereses), Ajustes y Perfil, splash verde, barra del sistema.
Hojas: movimiento nuevo/editar, transferir, ingreso previsto, gasto previsto, pago de crédito previsto, trabajo, simular gasto/pago (activar, ejecutar), meta de ahorro, aportar, cuenta de débito, tarjeta o préstamo y suscripción (con aviso de datos ligados, ocultar o eliminar todo). Ahorro es pestaña propia. Splash verde con apertura en círculo. Barra de pestañas nativa (Liquid Glass en iOS 26) y «+» en la barra superior.

## Pendientes

Casi todo el contenido de la web ya está portado. Lo que queda:

1. **Plata Cloud**: ya está escrito (entrar, frase en español/inglés, sincronizar, elegir qué conservar, aprobar dispositivos, borrar datos/cuenta, cargar archivo), compila en CI y **el usuario ya lo probó (29 oct 2026)**. Ya no es un pendiente. Queda fuera de la v1.0 «Mandar archivo a Nazca para que aprenda».
2. **Revisión visual 1:1** contra la web, pantalla por pantalla (espaciados, tamaños, pesos, modo oscuro). Necesita ojos y capturas: nada de esto se puede comprobar desde el CI.
3. **Nazca con estados de cuenta reales**: ver «ESTADO AL PAUSAR», punto 1 (en PDFKit real fallan Apple Card, BBVA y BCP ahorros).
4. Detalles de diseño: etiquetas curvas del anillo (el logo «Estudio 22» ya está hecho), posición de la persona sin foto y letra de la insignia en el avatar.
5. Accesibilidad: repasar VoiceOver, Dynamic Type y contraste; iPad si se decide.
6. Más pruebas: UI básicas y las funciones de `ProfileEditor` que aún no tienen.
7. Publicación: capturas, ficha de App Store, política de privacidad. TestFlight ya funciona desde el Mac; `.github/workflows/testflight.yml` lo hace desde GitHub (hace falta crear 3 secretos, ver su encabezado).

Hecho y ya no pendiente (antes figuraba aquí): formularios y hojas (movimiento, transferir, previstos, trabajos, simulaciones, metas, cuentas, tarjetas, suscripciones, sets de presupuesto), Confirmar/Adelantar/Posponer, pago de crédito y simular pago extra, Insights completos (banners, evaluación, avisos de presupuesto, ahorro y deuda), historial de aportes, Novedades/Historia/Créditos/Opinión/Transparencia, cambio de moneda principal, Idioma/Apariencia/Tutorial, carga y borrado de datos y perfiles de demostración, inglés (`Tr.swift`; los números siguen el formato `en-US` como en la web), onboarding, avatar y tutorial guiado.

**Importar de Nazca** (hecho, en el dispositivo): CSV, Excel de Yape y PDF con 16 lectores de banco más una lectura genérica, clave o DNI para BCP e iO, «Leerlo como…», PDF protegidos en lote y logos de banco.

## Cómo trabajar
- Siempre abrir primero la parte equivalente en `dev/app/src/app.html` y copiar textos, orden y medidas.
- Lógica de negocio en `PlataCore` (con pruebas), no en las vistas.
- Después de cada cambio: push a `swift-nativo` y mirar el resultado del workflow `Swift` en GitHub Actions.

## Avatar del perfil (hecho, sin revisar en pantalla)

`Avatar.swift` (aro + insignia con recorte, laurel, héroe del perfil), `ProfilePhoto.swift` (selector de foto y editor de recorte), `ProfileView.swift` (Perfil en modo lectura; «Editar» abre el formulario). Falta revisar a ojo contra la web: posición de la persona sin foto, tamaño de la letra de la insignia y laurel. No incluye Idioma/Apariencia/Tutorial del Perfil ni el widget de bento.
