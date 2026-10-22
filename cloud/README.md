# Plata Cloud · lista de espera

Primer pedazo del servicio de Plata Cloud: un Cloudflare Worker que recibe correos de la lista de espera de la marcha blanca.
Guarda solo correo, fecha, origen (`app` o `landing`), idioma y plataforma. No recibe ni guarda datos financieros.

## Puesta en marcha (una vez)

1. Crea una cuenta gratuita en cloudflare.com y añade el dominio `plataapp.net`. Cambia los nameservers en tu registrador por los que te indique Cloudflare y espera a que diga "Active". Copia primero los registros DNS que ya existen (los de GitHub Pages) para no romper el sitio.
2. En una terminal, dentro de esta carpeta `cloud/`:
   ```
   npx wrangler login
   npx wrangler kv namespace create WAITLIST
   ```
   Copia el `id` que imprime y pégalo en `wrangler.toml`, reemplazando `REEMPLAZA_CON_EL_ID_DE_KV`.
3. Crea los secretos (te pedirá el valor de cada uno; usa cadenas largas y aleatorias):
   ```
   npx wrangler secret put ADMIN_TOKEN
   npx wrangler secret put RL_SALT
   ```
4. Publica:
   ```
   npx wrangler deploy
   ```
   Con `custom_domain = true`, Cloudflare crea solo el registro DNS de `api.plataapp.net` y el certificado.
5. Comprueba: abrir `https://api.plataapp.net/health` debe responder `{"ok":true}`.
6. Avisa para activar los formularios en la app y en la landing (hoy están ocultos hasta configurar la dirección del servicio).

## Ver la lista

```
curl -H "Authorization: Bearer TU_ADMIN_TOKEN" https://api.plataapp.net/waitlist/export
```

## Borrar a alguien de la lista

Desde la carpeta `cloud/`: `npx wrangler kv key delete --binding=WAITLIST "w:correo@ejemplo.com"`

## Qué hace y qué no

- Solo acepta peticiones desde `https://plataapp.net` y `https://www.plataapp.net`.
- Máximo 5 solicitudes por hora por dirección IP (se guarda un hash, no la IP).
- Campo señuelo anti-bots (`website`): si viene lleno se ignora en silencio.
- Responde igual si el correo ya estaba en la lista, para no revelar quién se apuntó.
- Cuerpo máximo de 1 KB.

## Costo

Plan gratuito de Workers y KV: sobra para una lista de espera. Confirma las tarifas vigentes en Cloudflare.
