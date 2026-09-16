// @ts-check
import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

// CI passes the real origin and base from actions/configure-pages, so the
// build follows whatever Pages is actually serving. With a custom domain the
// site sits at the root and `base_path` comes back empty, which is why these
// use `||` rather than `??`: an empty string has to fall through to '/'.
// The fallbacks only matter for local builds and previews.
const site = process.env.SITE_URL || 'https://tarot.hairbui76.id.vn';
const base = process.env.BASE_PATH || '/';

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
