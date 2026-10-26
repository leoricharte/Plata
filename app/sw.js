/* Service worker de despedida para plataapp.net/app: se da de baja y borra su caché, así el ícono viejo ya no sirve la app antigua. */
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => { e.waitUntil(caches.keys().then((ks) => Promise.all(ks.map((k) => caches.delete(k)))).then(() => self.registration.unregister()).then(() => self.clients.matchAll()).then((cs) => cs.forEach((c) => c.navigate(c.url)))); });
