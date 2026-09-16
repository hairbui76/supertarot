# SuperTarot Web

*Đọc bản [Tiếng Việt](README.vi.md).*

A static Astro site that publishes the tarot card meanings for anyone with a
browser. It is deployed to GitHub Pages on every push to `main`.

**No AI.** Q&A and answer grading live in the Android app, because they need an
API key and a provider call. The web build only does what works offline and for
free: browse, search, and draw.

## What it does

| Page | What it is |
| --- | --- |
| `/<lang>/` | Hero, the five suits in traditional deck order, and a searchable grid of all 78 cards. |
| `/<lang>/suit/<suit>/` | One suit, Ace through King. |
| `/<lang>/card/<slug>/` | A card: art, correspondences, concise meaning, description, symbols, and the full upright and reversed halves. Prerendered, so it is indexable. |
| `/<lang>/draw/` | Draw one card and one facet, with a hint. The reference answer is revealed on request, since there is no grader. |

`<lang>` is `vi` or `en`; every page links to its counterpart with `hreflang`.
The root path redirects to `/vi/`.

The grid shows 1 to 5 cards per row: buttons, or pinch on a touch screen. The
choice, the language and the light/dark preference all persist in
`localStorage`.

## Requirements

- Node 20+
- Python 3.10+ at the repository root, to generate the site inputs

## Build the site inputs

Run from the repository root. **Required** after any change to the tarot data:

```bash
python web/tools/prepare_web_assets.py
```

It writes, all of it gitignored and rebuilt in CI:

- `web/src/data/cards_{en,vi}.json` — 78 cards in deck order, Vietnamese
  backfilled with metadata from English, each with a URL slug and deck index.
- `web/public/cards/*.jpg` — the card art.
- `web/public/{logo,favicon,og}.png` — derived from `mobile/icon/app_icon.png`
  so the site and the Android launcher icon are the same mark. The PNG
  decode/resize is hand-rolled on the standard library rather than pulling in
  an image dependency for three files.

No embedding index: there is no AI here, and search is by card name.

## Develop

```bash
cd web
npm install
npm run dev      # http://localhost:4321/
npm test         # the draw logic
npm run check    # astro check
npm run build    # static output into web/dist
npm run preview
```

## Deployment

`.github/workflows/pages.yml` builds and deploys on every push to `main`.

`site` and `base` come from `actions/configure-pages` at build time rather than
being hard-coded, because the account serves Pages from a custom domain. The
local fallback in `astro.config.mjs` only matters for `npm run build` on a
laptop.

`robots.txt` is generated from `Astro.site` for the same reason: a hard-coded
sitemap URL would point at the wrong origin.

## Shared logic

`src/lib/study.ts` is a port of `learning/study.py`, and matches
`mobile/lib/src/services/study_service.dart`: the same facet order, the same
question and hint wording, and the same no-repeat 78-card cycle.

`test/study.test.ts` covers the property that a screenshot cannot show — that a
card never repeats before the cycle is exhausted, and that the cycle counter
rolls over afterwards.

## Design

Neubrutalism, as specified in `DESIGN.md` at the repository root: 3px borders,
hard 4px offset shadows with no blur, flat high-saturation fills, no gradients,
heavy uppercase labels. Tokens live in `src/styles/global.css`, and dark mode
flips the border and shadow colour to near-white because a black border is
invisible on a dark background.

Icons are inline SVG in `src/lib/icons.ts`, never emoji. The five suit marks
are drawn as paths there too, mirroring the app's `suit_glyph.dart`.
