# Plata iOS (SwiftUI nativo) — estado y pendientes

Documento para pasarle a otra IA o a otra persona. Actualizado: 29 oct 2026. Avance estimado: **~85 %** del port. Es una estimación: lo que más falta es revisión visual 1:1, pruebas con datos y capturas reales, y unir `main` con esta rama.

## ESTADO ACTUAL (29 oct 2026, noche)

**Rama `swift-nativo`: CI en verde** (build 48 y el commit de Apple Music; pruebas de `PlataCore`, `xcodebuild` de la app, Watch, widgets y extensión). Avance estimado del port: **~85 %**.

### Hecho desde la última versión de este documento (lo hizo otra sesión de Claude, builds 24 a 48)
- **Nazca lee PDF con el mismo pdf.js que la web** dentro de un WKWebView oculto y sin red (`Nazca/PDF/NazcaPDFWeb.swift`, carpeta `PlataCore/Sources/PlataCore/pdfjs/`, se sincroniza con `swift/tools/sync-pdfjs.sh`). PDFKit queda de respaldo. Con eso se resolvió el fallo de Apple Card, BBVA y BCP ahorros (ya no hay prueba roja).
- **Constancias de Yape y Plin** (web + iOS): lector `NazcaConstancia` con vectores contra la web (`tools/gen-nazca-constancia.mjs`, `dev/tests/constancias.json`), importar pegando o con **Compartir** (extensión `PlataShare`, bandeja `ConstanciaInbox` por el App Group `group.net.plataapp.plata`, la app la recoge en `processConstanciaInbox`), OCR **en el dispositivo** con Vision (`SharedConstancia/ConstanciaOCR.swift`), pregunta «¿Enviaste o te llegó?», Plin por defecto a la cuenta Yape/Plin más usada, BBVA «Envío a contactos» y Plin «Enviado a… - Yape».
- Revisión (pantalla, banner, fila) compila y su motor coincide con la web. Falta probarla a mano.
- Apple Music con su nueva identidad (nota negra sobre blanco; las marcas pueden traer color de glifo `fg` en `Brands.json`).

### Pendiente de Yape / Plin
1. **Probar la extensión «Compartir» en un iPhone real** (hace falta el App ID `net.plataapp.plata.share` con el App Group; la firma automática de Xcode lo crea, y el workflow de TestFlight usa `-allowProvisioningUpdates`).
2. **Probar el OCR con capturas reales** (Vision en iOS y Tesseract en la web). Solo se probó con imágenes sintéticas y con textos inventados.
3. Wireframe del flujo de importar constancias: el otro agente lo dejó sin hacer; no hay rastro en el repo.

### Atención: `main` y `swift-nativo` se separaron
`main` está 31 commits adelante (web hasta el build 483: OCR de capturas con Tesseract, PIN, traducciones en JSON, Apple Music…) y `swift-nativo` 219 (iOS, y la web de Nazca/constancias también se tocó aquí). Un `git merge` entre ambas hoy da conflictos en `.gitignore`, `README.md`, `dev/app/src/app.html` y `dev/web/sw.js`. Conviene unirlas pronto, antes de que la web siga divergiendo; `dev/app/src/app.html` de `swift-nativo` es la referencia del port, y hoy está atrasada respecto a `main`.

### Pendiente en general
- Revisión visual 1:1 contra la web (necesita ojos y capturas), etiquetas curvas del anillo, VoiceOver / Dynamic Type, metadatos y capturas para App Store.
- **TestFlight desde GitHub**: crear 3 secretos (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`) en GitHub → Settings → Secrets and variables → Actions. Es del usuario. Sin ellos solo se instala con ▶ en Xcode.
- **Web:** unir `main` con `swift-nativo` (ver arriba) y desplegar el worker si cambió.
- Si se toca la web: subir `APP_BUILD` y `CACHE` en `dev/web/sw.js`.

### Cómo se trabaja aquí (importante)
- **No hay Swift local**: todo se verifica con el workflow `Swift` (`macos-26`). Para leer por qué falló: `gh api repos/leoricharte/Plata/actions/runs/<id>/jobs` y `gh api repos/leoricharte/Plata/check-runs/<job_id>/annotations` (los logs completos dan «Forbidden»). Un push cancela la corrida en curso (concurrency), así que no hay que empujar mientras se espera un resultado.
- **Vectores dorados:** `swift/tools/gen-*.mjs` ejecutan el JS real de la web y escriben `PlataCore/Tests/PlataCoreTests/Fixtures/*.json`. Los `*.json` están ignorados en `.gitignore`: cualquier JSON nuevo que deba vivir en el repo necesita su excepción (`!ruta`). Eso ya falló dos veces (logos de Cloud en iOS y traducciones `tr/*.json` en la web).
- **Inglés:** `swift/tools/i18n/extras_en.txt` (`es ¦ en`) + `python3 swift/tools/i18n/gen_en.py`; `check_gaps.py` lista lo que falta.
- **Preferencias del usuario (fundador/diseñador de producto, habla español, programa con IA):** responder en español, directo y corto. Cuando dice «break» o «pausa»: commit + push y darle `cd ~/Plata && git pull && cd swift/PlataApp && xcodegen` (luego ▶ en Xcode) **con el porcentaje de avance del port y cómo va**, con cifras honestas.
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
3. **Nazca con estados de cuenta reales**: ya lee con pdf.js (ver «ESTADO ACTUAL»); falta probarlo con PDFs reales del usuario.
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
