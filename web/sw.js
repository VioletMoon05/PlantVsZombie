/* The build script replaces this token so a new deployment drops old caches. */
const CACHE_NAME = "pvz-web-__PVZ_CACHE_VERSION__";
const SHELL_FILES = [
  "./",
  "./index.html",
  "./manifest.webmanifest",
  "./wasm_exec.js",
  "./icons/favicon.ico",
  "./icons/android-chrome-192x192.png",
  "./icons/android-chrome-512x512.png",
  "./icons/apple-touch-icon.png"
];

self.addEventListener("install", (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_NAME);
    await cache.addAll(SHELL_FILES);
    await self.skipWaiting();
  })());
});

self.addEventListener("activate", (event) => {
  event.waitUntil((async () => {
    const names = await caches.keys();
    await Promise.all(names
      .filter((name) => name.startsWith("pvz-web-") && name !== CACHE_NAME)
      .map((name) => caches.delete(name)));
    await self.clients.claim();
  })());
});

self.addEventListener("fetch", (event) => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== "GET" || url.origin !== self.location.origin) return;

  const responsePromise = (async () => {
    const cache = await caches.open(CACHE_NAME).catch(() => null);
    const cached = cache ? await cache.match(request).catch(() => null) : null;
    return cached || fetch(request);
  })();

  event.respondWith(responsePromise.catch(async (error) => {
    if (request.mode === "navigate") {
      const cache = await caches.open(CACHE_NAME).catch(() => null);
      const shell = cache ? await cache.match("./index.html").catch(() => null) : null;
      if (shell) return shell;
    }
    throw error;
  }));

  // Register the cache write while the fetch event is still being dispatched.
  event.waitUntil(responsePromise.then(async (response) => {
    if (!response.ok || response.type !== "basic") return;
    const cache = await caches.open(CACHE_NAME).catch(() => null);
    if (cache) await cache.put(request, response.clone()).catch(() => {});
  }).catch(() => {}));
});
