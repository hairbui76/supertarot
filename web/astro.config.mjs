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
      // A new deploy's worker takes over by itself (src/sw.ts skips waiting);
      // there is no reload prompt.
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
      // The worker is hand-written in src/sw.ts: pages go network-first,
      // which generateSW cannot express alongside a precache of those pages.
      strategies: 'injectManifest',
      srcDir: 'src',
      filename: 'sw.ts',
      injectManifest: {
        // Every page is precached, so the whole reference works offline after
        // the first visit: ~1.9 MB over the wire, since the HTML gzips from
        // 7.6 MB. Card art is left out - 6.6 MB of JPEG does not compress -
        // and is cached at runtime as cards are viewed instead.
        globPatterns: ['**/*.{html,css,js,png,svg,webmanifest,txt,xml}'],
        globIgnores: ['cards/**', 'sw.js'],
        // The quiz and spread pages inline the whole deck, ~1.2 MB each.
        maximumFileSizeToCacheInBytes: 3 * 1024 * 1024,
      },
    }),
  ],
  // Every page is prerendered: the site is a reference book, not an app, and
  // there is no backend to talk to.
  output: 'static',
});
