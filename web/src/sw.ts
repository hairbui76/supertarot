/// <reference lib="webworker" />
/**
 * The service worker, built by @vite-pwa/astro with `injectManifest`.
 *
 * Pages go to the network first. The first PWA build served every page from
 * its precache, which kept a returning reader on the old site after a deploy
 * until the browser happened to fetch a new sw.js - and Cloudflare lets the
 * browser keep sw.js for four hours. A reference site must show the current
 * meanings whenever it is online, so the caches are only a fallback here.
 *
 * Everything else - hashed CSS and JS, icons - is safe cache-first: a new
 * deploy gives those new URLs.
 */
import { clientsClaim } from 'workbox-core';
import { CacheableResponsePlugin } from 'workbox-cacheable-response';
import { ExpirationPlugin } from 'workbox-expiration';
import {
  cleanupOutdatedCaches,
  matchPrecache,
  PrecacheFallbackPlugin,
  precacheAndRoute,
} from 'workbox-precaching';
import { registerRoute } from 'workbox-routing';
import { CacheFirst } from 'workbox-strategies';

declare const self: ServiceWorkerGlobalScope & {
  __WB_MANIFEST: Array<{ url: string; revision: string | null } | string>;
};

const PAGES = 'pages';
/** How long a slow network gets before a cached copy is shown instead. */
const NETWORK_TIMEOUT_MS = 4000;

const scope = new URL(self.registration.scope);

/**
 * @vite-pwa/astro precaches a page under its directory URL (/vi/spread/), but
 * look up the index.html form too in case a future version stops rewriting.
 */
async function matchPrecachedPage(url: URL): Promise<Response | undefined> {
  return (
    (await matchPrecache(url.pathname)) ??
    (url.pathname.endsWith('/')
      ? await matchPrecache(`${url.pathname}index.html`)
      : undefined)
  );
}

async function fromCache(url: URL): Promise<Response | undefined> {
  // The pages cache holds the newest copy seen online; the precache holds the
  // build the service worker was installed with, and covers pages never
  // visited.
  const cache = await caches.open(PAGES);
  return (await cache.match(url.href)) ?? (await matchPrecachedPage(url));
}

async function fromNetwork(url: URL): Promise<Response> {
  // no-cache revalidates with the server rather than trusting the ten-minute
  // max-age GitHub Pages sends, so a deploy shows up on the next page load.
  const response = await fetch(url.href, {
    cache: 'no-cache',
    credentials: 'same-origin',
  });
  if (response.redirected) {
    // e.g. /vi -> /vi/. A navigation cannot be answered with a followed
    // redirect, so hand the browser the redirect itself.
    return Response.redirect(response.url, 302);
  }
  if (response.ok) {
    const cache = await caches.open(PAGES);
    await cache.put(url.href, response.clone());
  }
  return response;
}

async function page(request: Request): Promise<Response> {
  const url = new URL(request.url);
  const network = fromNetwork(url);

  const timedOut = new Promise<'timeout'>((resolve) =>
    setTimeout(() => resolve('timeout'), NETWORK_TIMEOUT_MS),
  );
  try {
    const first = await Promise.race([network, timedOut]);
    if (first !== 'timeout') {
      return first;
    }
    // Slow network: show a cached copy if there is one, otherwise keep waiting.
    return (await fromCache(url)) ?? (await network);
  } catch {
    // Offline.
    return (await fromCache(url)) ?? Response.error();
  }
}

// Registered before the precache route, so it wins for navigations.
registerRoute(({ request }) => request.mode === 'navigate', ({ request }) => page(request));

cleanupOutdatedCaches();
precacheAndRoute(self.__WB_MANIFEST, { directoryIndex: 'index.html' });

// Card art is 6.6 MB of JPEG, so it is not precached: each image is cached the
// first time it is seen, and a card never viewed shows a drawn placeholder
// while offline.
registerRoute(
  ({ request, url }) =>
    request.destination === 'image' && url.pathname.includes('/cards/'),
  new CacheFirst({
    cacheName: 'card-art',
    plugins: [
      new CacheableResponsePlugin({ statuses: [0, 200] }),
      new ExpirationPlugin({
        // The full deck, with headroom for renamed files across deploys.
        maxEntries: 120,
        maxAgeSeconds: 60 * 60 * 24 * 90,
      }),
      new PrecacheFallbackPlugin({
        fallbackURL: new URL('card-offline.svg', scope).pathname,
      }),
    ],
  }),
);

// A new deploy's worker takes over at once rather than waiting for every tab
// to close.
self.skipWaiting();
clientsClaim();
