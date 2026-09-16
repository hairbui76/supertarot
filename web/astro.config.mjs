// @ts-check
import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

// GitHub Pages serves a project site under /<repo>/, so every generated link
// has to carry that prefix. `site` also feeds the sitemap and canonical URLs.
// CI passes the real origin from actions/configure-pages; this fallback is
// only for local builds and previews.
const site = process.env.SITE_URL ?? 'https://haiuet.me';
const base = process.env.BASE_PATH ?? '/supertarot';

export default defineConfig({
  site,
  base,
  trailingSlash: 'always',
  build: {
    // Pages has no server to rewrite extensionless URLs, so emit directories
    // with index.html.
    format: 'directory',
  },
  integrations: [sitemap()],
  // Every page is prerendered: the site is a reference book, not an app, and
  // there is no backend to talk to.
  output: 'static',
});
