// @ts-check
import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';
import AstroPWA from '@vite-pwa/astro';

// CI passes the real origin and base from actions/configure-pages, so the
// build follows whatever Pages is actually serving. With a custom domain the
// site sits at the root and `base_path` comes back empty, which is why these
// use `||` rather than `??`: an empty string has to fall through to '/'.
// The fallbacks only matter for local builds and previews.
const site = process.env.SITE_URL || 'https://tarot.hairbui76.id.vn';
const base = process.env.BASE_PATH || '/';

/** A path under the site base, for manifest and service worker URLs. */
const at = (path = '') => `${base.replace(/\/+$/, '')}/${path}`;

const BEIGE = '#dfc79a';
const PAPER = '#fffbf0';

export default defineConfig({
  site,
  base,
  trailingSlash: 'always',
  build: {
    // Pages has no server to rewrite extensionless URLs, so emit directories
    // with index.html.
    format: 'directory',
  },
  integrations: [
    sitemap({
      // The root and the old /draw/ paths are redirect stubs, not pages worth
      // listing.
      filter: (page) => {
        const path = new URL(page).pathname.replace(base, '/');
        return path !== '/' && !/^\/(vi|en)\/draw\/$/.test(path);
      },
    }),
    AstroPWA({
      // A content site should never show stale meanings: a new deploy takes
      // over on the next navigation instead of waiting for a reload prompt.
      registerType: 'autoUpdate',
      injectRegister: 'script-defer',
      base,
      scope: base,
      manifest: {
        id: at(),
        name: 'SuperTarot',
        short_name: 'SuperTarot',
        description:
          'Tra cứu ý nghĩa 78 lá tarot, bốc bài và kiểm tra, dùng được cả khi offline.',
        lang: 'vi',
        dir: 'ltr',
        // The root redirects to whichever language the reader last used.
        start_url: at(),
        scope: at(),
        display: 'standalone',
        orientation: 'portrait',
        background_color: PAPER,
        theme_color: BEIGE,
        categories: ['education', 'books', 'lifestyle'],
        icons: [
          {
            src: at('icon-192.png'),
            sizes: '192x192',
            type: 'image/png',
            purpose: 'any',
          },
          {
            src: at('icon-512.png'),
            sizes: '512x512',
            type: 'image/png',
            purpose: 'any',
          },
          {
            src: at('icon-maskable-512.png'),
            sizes: '512x512',
            type: 'image/png',
            purpose: 'maskable',
          },
        ],
        shortcuts: [
          {
            name: 'Bốc bài',
            short_name: 'Bốc bài',
            url: at('vi/spread/'),
            icons: [{ src: at('icon-192.png'), sizes: '192x192' }],
          },
          {
            name: 'Kiểm tra',
            short_name: 'Kiểm tra',
            url: at('vi/quiz/'),
            icons: [{ src: at('icon-192.png'), sizes: '192x192' }],
          },
          {
            name: 'Three-card spread',
            short_name: 'Spread',
            url: at('en/spread/'),
            icons: [{ src: at('icon-192.png'), sizes: '192x192' }],
          },
          {
            name: 'Quiz',
            short_name: 'Quiz',
            url: at('en/quiz/'),
            icons: [{ src: at('icon-192.png'), sizes: '192x192' }],
          },
        ],
      },
      workbox: {
        // Every page is precached, so the whole reference works offline after
        // the first visit. That is ~1.9 MB over the wire: the HTML gzips from
        // 7.6 MB to 1.9 MB. Card art is left out of the precache on purpose -
        // 6.6 MB of JPEG does not compress, and would be a heavy first visit on
        // mobile data - and is cached at runtime as cards are viewed instead.
        globPatterns: ['**/*.{html,css,js,png,svg,webmanifest,txt,xml}'],
        globIgnores: ['cards/**'],
        // The quiz and spread pages inline the whole deck, ~1.2 MB each.
        maximumFileSizeToCacheInBytes: 3 * 1024 * 1024,
        directoryIndex: 'index.html',
        // A multi-page site: every route is its own precached document, so a
        // single SPA fallback document would be wrong.
        navigateFallback: null,
        cleanupOutdatedCaches: true,
        runtimeCaching: [
          {
            urlPattern: ({ request, url }) =>
              request.destination === 'image' && url.pathname.includes('/cards/'),
            handler: 'CacheFirst',
            options: {
              cacheName: 'card-art',
              expiration: {
                // The full deck, with headroom for renamed files across deploys.
                maxEntries: 120,
                maxAgeSeconds: 60 * 60 * 24 * 90,
              },
              cacheableResponse: { statuses: [0, 200] },
              // Offline and never viewed: show a drawn placeholder rather than
              // the browser's broken-image icon.
              precacheFallback: { fallbackURL: at('card-offline.svg') },
            },
          },
        ],
      },
    }),
  ],
  // Every page is prerendered: the site is a reference book, not an app, and
  // there is no backend to talk to.
  output: 'static',
});
