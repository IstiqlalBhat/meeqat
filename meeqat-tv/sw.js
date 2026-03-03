/* ============================================
   Meeqat TV - Service Worker
   Offline-first caching strategy
   ============================================ */

const STATIC_CACHE = 'meeqat-tv-static-v9';
const DATA_CACHE = 'meeqat-tv-data-v9';

// Static assets to precache
const STATIC_ASSETS = [
  '/',
  '/index.html',
  '/css/styles.css',
  '/js/app.js',
  '/js/api.js',
  '/manifest.json'
];

// Install - precache static assets
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(STATIC_CACHE).then(cache => {
      return cache.addAll(STATIC_ASSETS);
    }).then(() => self.skipWaiting())
  );
});

// Activate - clean up ALL old caches
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys => {
      return Promise.all(
        keys.filter(key => key !== STATIC_CACHE && key !== DATA_CACHE)
          .map(key => caches.delete(key))
      );
    }).then(() => self.clients.claim())
  );
});

// Fetch - strategy depends on request type
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);

  // API requests: Network-first, cache fallback
  if (url.pathname.startsWith('/api/')) {
    event.respondWith(networkFirstWithCache(event.request));
    return;
  }

  // Static assets from our origin: Cache-first, network fallback
  if (url.origin === self.location.origin) {
    event.respondWith(cacheFirstWithNetwork(event.request));
    return;
  }

  // External resources (fonts, CDN): Stale-while-revalidate
  event.respondWith(staleWhileRevalidate(event.request));
});

// ---- Caching Strategies ----

// Network-first with cache fallback (for API data)
async function networkFirstWithCache(request) {
  try {
    const response = await fetch(request);
    if (response.ok) {
      const cache = await caches.open(DATA_CACHE);
      cache.put(request, response.clone());
    }
    return response;
  } catch {
    const cached = await caches.match(request);
    if (cached) return cached;
    return new Response(JSON.stringify({ error: 'Offline', cached: false }), {
      status: 503,
      headers: { 'Content-Type': 'application/json' }
    });
  }
}

// Cache-first with network fallback (for static assets)
async function cacheFirstWithNetwork(request) {
  const cached = await caches.match(request);
  if (cached) return cached;

  try {
    const response = await fetch(request);
    if (response.ok) {
      const cache = await caches.open(STATIC_CACHE);
      cache.put(request, response.clone());
    }
    return response;
  } catch {
    // Return offline fallback for HTML requests
    if (request.headers.get('Accept')?.includes('text/html')) {
      return caches.match('/index.html');
    }
    return new Response('Offline', { status: 503 });
  }
}

// Stale-while-revalidate (for external resources)
async function staleWhileRevalidate(request) {
  const cached = await caches.match(request);

  const fetchPromise = fetch(request).then(response => {
    if (response.ok) {
      const cache = caches.open(STATIC_CACHE);
      cache.then(c => c.put(request, response.clone()));
    }
    return response;
  }).catch(() => cached);

  return cached || fetchPromise;
}

// Periodic cache cleanup
self.addEventListener('message', event => {
  if (event.data === 'CLEAN_CACHE') {
    caches.open(DATA_CACHE).then(cache => {
      cache.keys().then(keys => {
        if (keys.length > 50) {
          keys.slice(0, keys.length - 50).forEach(key => cache.delete(key));
        }
      });
    });
  }
});
