# Plata nativa en Swift

Versión nativa de Plata para Apple (iPhone, iPad, Mac y Apple Watch). Convive con la app web: **los mismos archivos y la misma nube**.

## Qué hay

`PlataCore/` es un Swift Package **sin interfaz**: el "órgano" que comparten todas las pantallas nativas. Está probado contra la web, no solo contra sí mismo.

| Archivo | Qué hace | Equivale en la web |
|---|---|---|
| `JSONValue.swift` | JSON sin esquema. Lo que Swift no conoce se conserva al leer y escribir. | `JSON.parse` / `stringify` |
| `Profile.swift` | El perfil (`version: 3`), `hasData`, `normalized()`, modelos de lectura (`Account`, `Transaction`). | `EMPTY`, `migrate`, `hasDataOf` |
| `Phrase.swift` + `Wordlist.swift` | Frase de 12 palabras ↔ semilla de 128 bits. | `PCC.toPhrase` / `fromPhrase` |
| `CloudCrypto.swift` + `Gzip.swift` | HKDF-SHA256, AES-GCM-256, gzip. Abre y crea las copias de la nube. | `PCC.seal` / `open` |
| `Merge.swift` | Combinación de perfiles de 3 vías (saldos por diferencia, lápidas). | `mergeData` |
| `CloudAPI.swift` | Cliente del servidor (`/auth`, `/me/key`, `/sync`). | `clFetch` |
| `SyncEngine.swift` | Motor de sincronización. Dice a la interfaz qué hacer (`apply`, `needsChoice`, `loggedOut`…). | `clSync`, `clFirstPick` |
| `LocalDate.swift` | Fecha de calendario con el desborde de `new Date(y, m, d)`. | `pd`, `iso`, `addDays` |
| `Engine.swift` + `Currencies.swift` | Resumen del mes, eventos futuros, proyección, impacto de simulaciones, pendientes y simulador de deuda. | `calc`, `genEvents`, `projection`, `dailySeries`, `simImpact`, `pendingItems`, `payoff` |
| `SessionStore.swift` | Semilla y token en el **Llavero**; estado y base en disco; `ProfileStore` para el perfil. | `localStorage` |

## Compatibilidad (lo importante)

- **Archivo de perfil:** es el mismo JSON de la web (`dev/docs/DATOS.md`). Un archivo exportado en la web se importa en Swift y al revés. Los campos desconocidos se conservan.
- **Nube:** mismo cifrado, mismas rutas, misma frase de 12 palabras. Una cuenta creada en la web se abre en iOS con su frase, y al revés.
- **Servidor:** no hay que cambiarlo. Una app nativa no manda el encabezado `Origin`, y el Worker solo rechaza orígenes de navegador que no estén en su lista. (Esto es distinto del híbrido, que sí necesitaba `plata://localhost` en `ORIGINS`.)
- **Pruebas contra la web:** `tools/gen-vectors.mjs` ejecuta el código real de `app.html` (cifrado y `mergeData`) y escribe los vectores en `Tests/PlataCoreTests/Fixtures/`. Swift debe dar exactamente lo mismo.

Si cambias el cifrado, el formato del perfil o `mergeData` en la web, regenera los vectores y corre las pruebas:

```
node swift/tools/gen-vectors.mjs        # cifrado y combinación
node swift/tools/gen-engine-vectors.mjs # motor de cálculo (y Currencies.swift)
cd swift/PlataCore && swift test
```

(`swift test` corre en la Mac; también se puede abrir `PlataCore/Package.swift` en Xcode y usar ⌘U.)

## Lo que falta (por orden)

1. Compilar y pasar las pruebas en la Mac (este código se escribió sin compilador).
2. `migrate()` completo: el saneado de textos, colores e iconos de la web (`safeProfile`).
3. Motor de cálculo: hecho (`Engine`), probado contra 70 perfiles. Falta el motor de puntaje e insights (`monthScore`, `insightsModel`).
4. Pantallas SwiftUI: Resumen, Movimientos, Ajustes; después Presupuesto, Proyección y Deuda.
5. Inicio de sesión en la nube (pantallas) y aprobación desde otro dispositivo (`/link/*`).
6. Importación de CSV/PDF del banco (Nazca) y las 6 lenguas.

## Dos puntos que conviene saber

- **Orden de claves:** la web compara perfiles con `JSON.stringify`, que depende del orden de las claves; Swift compara el contenido sin importar el orden. Solo puede dar menos "cambios" falsos, nunca más.
- **Posible bug en la web (`clFirstPick`, opción "Combinar los dos"):** sube la copia sin el número de revisión cifrado dentro (`clPut(f.rev, m)` sin `next`). Otro dispositivo que la abra la rechaza como sospechosa. El motor de Swift (`chooseMerge`) sí lo manda. Conviene corregir la web aparte: guardar `next` en `CL.first` y pasarlo a `clPut`.
