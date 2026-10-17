# Finanzas

App web de finanzas personales (presupuesto, proyección, cuentas, ahorro). Un solo `index.html`, sin dependencias ni servidor.

## Publicar en GitHub Pages

1. En GitHub crea un repositorio nuevo (por ejemplo `finanzas`). Puede ser público; los datos **no** se suben: viven en el navegador de cada dispositivo.
2. Sube **todo el contenido de esta carpeta** a la raíz del repo (arrastra los archivos en "Add file → Upload files", incluido `.nojekyll`).
3. En el repo: **Settings → Pages → Build and deployment**: Source = *Deploy from a branch*, Branch = `main`, carpeta `/ (root)` → Save.
4. En 1–2 minutos queda en `https://TU-USUARIO.github.io/finanzas/`.

## Instalar en el iPhone

Abre la URL en **Safari** → botón Compartir → **Añadir a pantalla de inicio**.

## Tus datos

- Se guardan en el almacenamiento del navegador de **ese dispositivo y ese dominio** (la copia de github.io empieza vacía).
- Para pasar datos desde otra copia: allí `Ajustes → Guardar archivo`, y aquí `Ajustes → Cargar archivo`.
- Haz un respaldo (`Guardar archivo`) de vez en cuando: si borras los datos de Safari se pierden.

## Actualizar

Reemplaza `index.html` en el repo. Si no ves el cambio, sube el número de `CACHE` en `sw.js` (`finanzas-v2`, etc.).
