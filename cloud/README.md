# Plata Cloud (servidor)

Cloudflare Worker de Plata: Plata Cloud (cuentas y copia cifrada), lista de espera, análisis de uso y casos de Nazca.

- Código: `src/index.js` (esta carpeta es la versión de la lista de espera) y `../dev/worker/worker.js` (el servidor completo).
- Configuración: `wrangler.toml`. El identificador del KV de ejemplo (`REEMPLAZA_CON_EL_ID_DE_KV`) se reemplaza al desplegar. Los secretos no van en el repositorio: `npx wrangler secret put ADMIN_TOKEN` y `npx wrangler secret put RL_SALT`.
- Qué guarda y qué no: [dev/docs/WORKER.md](../dev/docs/WORKER.md) y la [hoja técnica de seguridad](https://plataapp.net/arquitectura-seguridad.html).
