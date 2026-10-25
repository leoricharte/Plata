# Formato de datos (save file)

El perfil es un JSON, versión **3**, que es lo mismo que se guarda en `localStorage` (`finanzas.v3`), se exporta como archivo y se cifra para Plata Cloud. `migrate()` en `app.html` acepta versiones antiguas (v2) y completa lo que falte.

```jsonc
{
  "version": 3,
  "demo": false,                // true en perfiles de demo
  "settings": { "currency": "USD", "currency2": "PEN", "fx": 3.7,
                "cushion": 400, "variable_weekly": 180, "lang": "es", ... },
  "accounts": [ { "id": "bank", "name": "...", "type": "checking", "cur": "USD", "balance": 0, "color": "#...", "icon": "..." } ],
  "transactions": [ { "id": 1, "date": "2026-10-01", "amount": -41.8, "category": "Comida", "note": "...", "acc": "bank", "est": 1400 } ],
  "history":   [ { "month": "2026-09", "income": 3290, "expense": 2970 } ],
  "cards":     [ { "id": "apple", "kind": "card" | "loan", "name": "...", "cur": "USD", "limit": 2500, "balance": 1180.4, "apr": 27.99, "due_day": 12 } ],
  "recurring": [ { "name": "Alquiler", "amount": -1150, "day": 1 } ],
  "subs":      [ { "id": "nflx", "name": "Netflix", "amount": 15.49, "cur": "USD", "day": 3 } ],
  "cats":      [ { "name": "Comida", "color": "#B98AE6", "icon": "bag" } ]
  "savings": [], "budget": {}, "budgetSets": [], "expected_income": [], "expected_expense": [],
  "planned": [], "jobs": []   // metas de ahorro, límites de presupuesto (y sets por fechas), previstos, simulaciones, trabajos
}
```

Notas:

- Los gastos son negativos y los ingresos positivos. `est` (opcional) es el monto que se esperaba, para comparar con lo real.
- Las fechas son `YYYY-MM-DD` en hora local; los meses `YYYY-MM`.
- `acc` apunta al `id` de una cuenta o tarjeta.
- Las transferencias entre cuentas no cuentan como gasto ni ingreso.
- Para la lista exacta de campos, la referencia es `makeSample()` y `migrate()` en `dev/app/src/app.html`.

## Cifrado para Plata Cloud

Resumen (detalle en `arquitectura-seguridad.html`): una semilla de 128 bits se muestra como 12 palabras; con HKDF-SHA256 se derivan la clave de datos (AES-GCM-256) y una verificación de clave. El blob subido es `versión + indicador gzip + IV de 12 bytes + AES-GCM`. El servidor nunca ve la clave ni el contenido.
