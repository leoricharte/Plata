# Plata iOS (SwiftUI nativo) — estado y pendientes

Documento para pasarle a otra IA o a otra persona. Actualizado: 28 oct 2026. Avance estimado: **~90 %** del port. Es una estimación: lo que más falta es revisión visual y pruebas con datos reales.

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

1. **Plata Cloud**: ya está escrito (entrar, frase en español/inglés, sincronizar, elegir qué conservar, aprobar dispositivos, borrar datos/cuenta, cargar archivo) y compila en CI, pero **falta probarlo contra el servidor real** (cuenta con invitación) y agregar la lista de palabras en español a la web. Queda fuera de la v1.0 «Mandar archivo a Nazca para que aprenda».
2. **Revisión visual 1:1** contra la web, pantalla por pantalla (espaciados, tamaños, pesos, modo oscuro). Necesita ojos y capturas: nada de esto se puede comprobar desde el CI.
3. **Probar Nazca con estados de cuenta reales** (los 16 lectores de PDF pasan las pruebas contra la web, pero solo con textos de muestra).
4. Detalles de diseño: etiquetas curvas del anillo, logo «Estudio 22» en Ajustes, posición de la persona sin foto y letra de la insignia en el avatar.
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
