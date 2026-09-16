import type { APIRoute } from 'astro';

// Generated rather than static: the sitemap URL has to follow whatever origin
// Pages is actually serving, which is a custom domain here, not the default
// github.io one.
export const GET: APIRoute = ({ site }) => {
  const sitemap = new URL(
    `${import.meta.env.BASE_URL.replace(/\/+$/, '')}/sitemap-index.xml`,
    site,
  );

  return new Response(
    ['User-agent: *', 'Allow: /', '', `Sitemap: ${sitemap}`, ''].join('\n'),
    { headers: { 'Content-Type': 'text/plain; charset=utf-8' } },
  );
};
