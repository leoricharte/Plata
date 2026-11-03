# Plata para Android

La app de Android es **la misma web de Plata empaquetada con [Capacitor](https://capacitorjs.com)**: lleva dentro los archivos de `web.plataapp.net` (funciona sin conexión) y, además, habla con el sistema para lo que el navegador no puede: huella o rostro, avisos locales, guardar y compartir archivos y recibir capturas desde «Compartir». La interfaz es la de la web; no se estiliza como Material.

Todo lo propio de Android solo corre **dentro de esa app** (cuando existe `window.Capacitor`). En el navegador, en la PWA y en el iPhone no cambia nada.

## Qué espeja de la app de iPhone

| iPhone (nativa) | Android (empaquetada) |
|---|---|
| Face ID / Touch ID sobre el PIN | Huella o rostro sobre el PIN (`BiometricPrompt`). El PIN sigue de respaldo. Se activa en Ajustes → Bloqueo con PIN. |
| Avisos locales (`Reminders.swift`) | Los mismos: días sin anotar, pagos y cobros de mañana, nota del mes y half-time. Se programan en el teléfono, sin servidor ni Firebase. Ajustes → Avisos. |
| Animación de arranque (la flecha rebota como piedra y las letras hacen «pop») | La misma: sus datos salen del Swift (`android/scripts/gen-lanzamiento.py`) y se dibuja en un canvas. El splash nativo es solo el fondo verde, sin imagen, como la pantalla de arranque del iPhone; al terminar, la animación se desvanece (el iPhone hace además un zoom del logo, que aquí es un fundido simple). Verde de marca en claro y verde bosque en oscuro. |
| «Compartir» hacia Plata (capturas, PDF, CSV, Excel, texto de constancias) | Igual, desde cualquier app. Plata aparece en la hoja de compartir. |
| Guardar archivos y exportar | Se guardan en la caché y se abre «Compartir» (WebView no descarga `blob:`). |
| Enlace del evento del calendario | `https://web.plataapp.net/?ev=…` abre ese evento (necesita el paso de **assetlinks.json**, abajo). |
| Widgets y Apple Watch | **No.** Los widgets de Android son código nativo (Kotlin/Glance); quedan para otra versión. |

## Cómo se compila

Todo en GitHub Actions (aquí no hace falta tener Android Studio): **Actions → Android → Run workflow**. Deja dos archivos para descargar:

- `plata-release.aab`: el que se sube a Google Play (firmado si están los 4 secretos; si no, sale **sin firmar** y solo sirve para comprobar que compila).
- `plata-debug.apk`: para instalarlo directo en tu teléfono y probar (activa «instalar apps desconocidas» para tu navegador o el administrador de archivos).

El proyecto de Android **no se versiona**: `npx cap add android` lo genera y `android/scripts/prepare.mjs` lo parcha (ícono, splash, permisos, plugin propio, firma). La receta está en `android/` (`capacitor.config.json`, `native/`, `resources/`, `scripts/`).

La versión sale sola: `versionName` = `5.0.<APP_BUILD>` y `versionCode` = número de ejecución del workflow + 100 (siempre sube, que es lo que pide Play).

### Para correrlo en tu computadora (opcional)
```
sh dev/web/build.sh
cd android && npm install && rm -rf www && cp -r ../dist-web www
npx cap add android && node scripts/prepare.mjs && npx cap sync android
cd android && ./gradlew assembleDebug          # el APK queda en app/build/outputs/apk/debug/
```
Necesita Node 22, Java 21 y el SDK de Android.

## La llave de subida (una sola vez)

Play firma la app final con su propia llave (Play App Signing). Tú firmas lo que **subes** con una **llave de subida**. Créala y **guarda el archivo y las contraseñas en un lugar seguro**: si la pierdes, hay que pedirle a Google que la restablezca.

```
keytool -genkeypair -v -keystore plata-subida.jks -alias plata -keyalg RSA -keysize 2048 -validity 10000
base64 -w0 plata-subida.jks        # en Mac: base64 -i plata-subida.jks | tr -d '\n'
```

Secretos en GitHub (Settings → Secrets and variables → Actions):

| Secreto | Qué es |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | la salida del `base64` de arriba |
| `ANDROID_KEYSTORE_PASSWORD` | la contraseña del archivo `.jks` |
| `ANDROID_KEY_ALIAS` | `plata` (o el alias que pusiste) |
| `ANDROID_KEY_PASSWORD` | la contraseña de la llave |

## Subir a Google Play

1. **Play Console → Crear app.** Nombre «Plata», idioma español, tipo *App*, gratis. El identificador del paquete es **`net.plataapp.plata`** (el mismo del iPhone): no se puede cambiar después.
2. **Pruebas.** Empieza por *Pruebas internas* (hasta 100 personas, sin revisión) con el `.aab`. Si tu cuenta de desarrollador es personal y nueva, Google puede exigir una **prueba cerrada con al menos 12 testers durante 14 días** antes de pasar a producción: revisa *Panel → Hacer pruebas y lanzar*.
3. **Ficha.** Ícono 512×512 y gráfico de funciones 1024×500 ya están en `android/play/`. Las capturas de pantalla las tomas del teléfono (mínimo 2). Categoría: *Finanzas*.
4. **Política de privacidad:** `https://plataapp.net/transparencia.html`.
5. **Seguridad de los datos** (respuestas que corresponden a cómo funciona Plata; revísalas tú antes de enviar):
   - Los datos financieros **se quedan en el dispositivo**; Plata no los recopila.
   - **Plata Cloud es opcional.** Si la activas: correo electrónico (para la cuenta) y una **copia cifrada de extremo a extremo**, que el servidor no puede leer. No se comparte con terceros.
   - Sin publicidad, sin analítica, sin rastreadores.
   - Los datos viajan cifrados (HTTPS). Se puede borrar la cuenta y la copia desde la app (Perfil → Plata Cloud → Borrar mi cuenta).
6. **Declaración de funciones financieras:** Play pide declarar el tipo de app financiera. Plata es de *gestión financiera personal* (presupuesto y seguimiento): no ofrece préstamos, pagos ni transferencias de dinero.
7. **Permisos que verá Google:** notificaciones (los avisos), biometría (la huella), internet (Plata Cloud y sus textos). Nada de contactos, ubicación, cámara ni micrófono.

## Para que el enlace del calendario abra la app (assetlinks.json)

Android solo abre `https://web.plataapp.net/…` en la app si el sitio demuestra que es suyo. Cuando Play te dé la **huella SHA-256 de la llave de firma de la app** (Play Console → Integridad de la app → Firma de la app), publica este archivo en **`https://web.plataapp.net/.well-known/assetlinks.json`** (hay una plantilla en `android/assetlinks.plantilla.json`). Sin él, todo funciona igual, pero el enlace del evento se abre en el navegador.

## Lo que probar en el teléfono con el APK

1. Abre la app: pantalla verde lisa y enseguida la animación de Plata (unos 2 segundos); no debe salir ninguna aleta de «Ábrela en tu navegador».
2. Ajustes → Bloqueo con PIN → crea un PIN → **Huella o rostro: activada**. Cierra y abre: debe pedir la huella y, si cancelas, el PIN.
3. Ajustes → **Avisos**: enciende uno; Android pide permiso de notificaciones. Comprueba que llega alguno (por ejemplo, lleva el reloj del teléfono al día anterior de un pago).
4. Perfil → guardar archivo: se abre la hoja de compartir con el JSON.
5. En otra app, comparte una captura de un banco a Plata: pregunta si es constancia o movimientos.
6. Proyección → un evento → **Añadir al calendario**: abre el `.ics` en el calendario.
7. Cuenta de Plata Cloud: entra con tu correo (el origen de la app es `https://web.plataapp.net`, el que ya acepta el servidor).

## Nivel de API que exige Google Play

Desde el **31 de agosto de 2026**, las apps nuevas y las actualizaciones deben apuntar a **Android 16 (API 36)** o más. Plata usa Capacitor 8 (que apunta a la 36) y el CI **falla** si el APK queda por debajo (`PLATA_TARGET_MIN` en `android/scripts/check-apk.py`). Cada año, hacia agosto, Google sube ese número: sube también Capacitor y ese valor.

Con la 36, la app dibuja bajo las barras del sistema (de borde a borde) y el sistema reserva los márgenes con las variables `env(safe-area-inset-*)`, que la web ya usa por el iPhone. **Mira la primera pantalla en el teléfono** para confirmar que ni la barra de estado ni la de navegación tapan nada.

## Límites conocidos

- **Widgets:** no hay (ver arriba).
- **Avisos:** Android puede retrasarlos unos minutos (usan alarmas no exactas a propósito: las exactas exigen una declaración especial a Google).
- **Sin Firebase / push remotas:** los avisos son locales, coherente con el cifrado de extremo a extremo.
- **Actualizaciones:** la web va dentro de la app, así que cada cambio de la web llega con una nueva versión en Play (se compila otra vez con el workflow).
- No se ha probado en un teléfono real desde donde se escribió: usa el APK y avisa de lo que falle.
