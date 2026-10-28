# Plata para iOS

La **misma app web** (`dev/app/src/app.html`, compilada a un solo HTML) dentro de un cascarón SwiftUI. La web no se toca: lo único nativo es la barra de pestañas, el botón «+» y el engranaje, que en iOS 26 y 27 son **Liquid Glass real** y en iOS 18–25 son vidrio esmerilado.

- **Piso:** iOS 18. Compilar con **Xcode 27** (SDK de iOS 27; desde abril de 2027 Apple lo exige para subir).
- **Solo iPhone** en esta primera versión.

## Compilar en la Mac

```
brew install xcodegen
git clone https://github.com/leoricharte/Plata && cd Plata
sh ios/sync-web.sh            # compila la web y la copia a ios/Plata/Web (repetir si cambia la web)
cd ios && xcodegen            # genera Plata.xcodeproj
open Plata.xcodeproj
```

En Xcode: target **Plata** → Signing & Capabilities → elige tu Team. Si tu App ID no es `net.plataapp.plata`, cámbialo ahí (o en `project.yml`). Para probar en tu iPhone con iOS 27 hace falta Xcode 27; para subir a TestFlight: Product → Archive.

## Cómo está armado

| Archivo | Qué hace |
|---|---|
| `Plata/AppSchemeHandler.swift` | Sirve la web empaquetada en `plata://localhost/` (origen estable, nada remoto). |
| `Plata/Bridge.js` | Se inyecta en la web. Oculta (con `visibility`) la barra, «+» y engranaje de la web, informa a Swift dónde están y con qué opacidad, y espeja `localStorage` a un archivo nativo. |
| `Plata/WebModel.swift` | Dueño del `WKWebView`: puente, descargas (hoja de compartir), enlaces externos a Safari, `alert`/`confirm`. |
| `Plata/NativeBar.swift` | La barra de vidrio. Se coloca donde la web tiene sus controles y los «toca» con `window.__plataGo`. |
| `Plata/NativeStore.swift` | Copia de seguridad de `finanzas.*` y `plata.*` por si iOS vacía el almacenamiento web. Se restaura solo si la web arranca sin perfil. |

Como la barra sigue el CSS de la web (posición, opacidad, «compact»), cuando cambias la lógica de cuándo se muestra la barra en `app.html`, la barra nativa lo sigue sin tocar Swift. Los nombres de las pestañas salen de la web, así que respetan los 6 idiomas.

## Iconos

La barra nativa usa **SF Symbols** (decisión para iOS). Los Remix Icon de la web quedan extraídos en `ios/Plata/Assets.xcassets` por si se quiere volver: cambia `NativeIcons.useSFSymbols` a `false` en `Plata/WebState.swift`. Dentro del contenido web siguen siendo Remix, porque el mismo HTML corre en Android y Windows.

## Pendiente antes de publicar

1. **Plata Cloud:** el Worker solo acepta orígenes de su lista `ORIGINS` (`dev/worker/worker.js`). Hay que agregar `'plata://localhost'` y redesplegar; sin eso la sincronización falla desde iOS (el resto de la app funciona).
2. **Cuestionario de cifrado en App Store Connect:** la app cifra en el dispositivo (Plata Cloud), así que hay que responder la declaración de cumplimiento de exportación.
3. **Privacidad de la app** (etiquetas de App Store Connect) y capturas de pantalla.
4. **Apple Watch:** es un target nativo aparte; no está en este cascarón.

## Qué probar primero (no se pudo compilar ni ejecutar al armarlo)

Este código se escribió sin Xcode ni simulador, así que es la primera cosa que hay que correr:

- Que compile con Xcode 27 (los modificadores `glassEffect` / `GlassEffectContainer` solo existen en el SDK 26+; están dentro de `#available`).
- Que la barra nativa quede alineada con la de la web (si ves doble barra o un desfase, mira en Safari → Develop → tu iPhone si `#tabbar` está oculto).
- Cambiar de pestaña, «+», engranaje y los estados donde la web oculta la barra (Cuenta, Movimientos, hojas abiertas).
- Exportar el archivo de perfil (debe salir la hoja de compartir) e importar un CSV y un PDF (pdf.js corre como worker desde `plata://localhost/nazca/`).
- Cerrar y abrir la app: los datos siguen; borrar todo desde la app: no «resucitan».
- Que NO aparezca el aviso «Ábrela en tu navegador».
