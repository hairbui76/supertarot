---
version: "alpha"
name: "Neubrutalism"
description: "Neubrutalist interface system for the SuperTarot Android app."
colors:
  primary: "#FFEB3B"
  secondary: "#FF5252"
  tertiary: "#2196F3"
  accentGreen: "#3DDC84"
  accentViolet: "#B47CFF"
  neutral: "#000000"
tokens:
  borderWidth: 3px
  shadowOffset: 4px
  shadowBlur: 0
  radius: 8px
typography:
  h1:
    fontFamily: System UI stack
    fontSize: 2.25rem
    fontWeight: 700
  body-md:
    fontFamily: System UI stack
    fontSize: 1rem
    fontWeight: 400
  label-caps:
    fontFamily: System UI stack
    fontSize: 0.75rem
    fontWeight: 500
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.neutral}"
    padding: 12px
---

# Neubrutalism

## Scope

This file describes the visual system for the SuperTarot Android app in
`mobile/`. It is a style reference, not a page blueprint: there is no landing
page, hero, pricing table or marketing footer in this project, and nothing here
should be read as asking for one.

The system is implemented in code, and the code is the source of truth:

- `mobile/lib/src/theme.dart` — `NeuTokens` ThemeExtension holding every value below.
- `mobile/lib/src/widgets/neu.dart` — `NeuBox`, `NeuButton`, `NeuIconButton`, `NeuChip`, `NeuHeading`, `NeuSection`, `NeuField`.
- `mobile/lib/src/widgets/suit_glyph.dart` — the five hand-drawn tarot suit marks.

No screen hard-codes a border or a shadow. If a value here and a value in
`theme.dart` disagree, `theme.dart` wins and this file is stale.

## Overview

Brutalism on the web was always a provocation. Raw HTML, system fonts, zero
polish — it said "I don't care about your expectations." Neubrutalism kept the
attitude but ditched the hostility. It's brutalism that actually wants you to
click the button.

The turning point was Gumroad's 2021 redesign. Sahil Lavingia stripped the
product down to thick black borders, flat primary colors, and offset drop
shadows that looked like someone dragged a rectangle two pixels southeast. It
was loud, playful, and unmistakably intentional. Designers noticed. Within
months, the Figma community had dozens of neubrutalist UI kits climbing the
charts.

What separates it from classic brutalism is warmth. Where brutalism embraced
ugliness as ideology, neubrutalism uses bold geometry as decoration. The borders
are thick but the corners can be rounded. The shadows are hard but the palette
is candy-colored. It's confrontational aesthetics made approachable — punk rock
in a good mood.

- Density: 5/10 — Balanced
- Variance: 4/10 — Moderate
- Motion: 4/10 — Subtle

- **Style:** Bold, Colorful, Raw, Playful
- **Keywords:** Bold borders, black outlines, primary colors, thick shadows, no gradients, flat colors, 45° shadows, playful, Gen Z
- **Era:** 2020s Modern
- **Light/Dark:** ✓ Full / ✓ Full

## Colors

Accents are flat fills, never gradients, and always carry ink-coloured text and
icons on top so contrast stays high.

- **#FFEB3B** — Primary. Default button fill, highlights.
- **#FF5252** — Secondary. Errors, warnings, the Wands suit.
- **#2196F3** — Tertiary. Informational, the Cups suit.
- **#3DDC84** — Added accent. Success and pass states, the Pentacles suit.
- **#B47CFF** — Added accent. The Major Arcana and the browse tab.

The palette gained green and violet beyond the three base accents so the five
tarot suits stay distinguishable. Suits are coloured by element: fire red, water
blue, air yellow, earth green, with violet reserved for the Major Arcana.

Surfaces:

| Role | Light | Dark |
| ---- | ----- | ---- |
| Background | `#FFFBF0` | `#15151A` |
| Raised surface | `#FFFFFF` | `#232330` |
| Border and shadow | `#000000` | `#F2F0E6` |

**Dark mode flips the border and shadow colour to near-white.** A black border
against a dark background is invisible, which would erase the entire style. The
accent fills do not change; a near-white border on saturated yellow still reads.

## Typography

- **Display:** System UI stack (-apple-system, sans-serif) — Weight 900, tight tracking.
- **Body:** System UI stack — Weight 400-600, 1.55 line-height.
- **UI Labels:** System UI stack — Weight 900, uppercase, ~0.8px letter-spacing.
- **Monospace:** JetBrains Mono — code, metadata, technical values.

Scale:

- Display: 24px
- Title: 17px / weight 900
- Body: 15-16px / 1.55
- Label: 11-12.5px / weight 900 / uppercase

Headings and labels are uppercase; body copy is not.

## Layout

- **Spacing rhythm:** Base unit 0.5rem (8px). Screen padding 20px.
- **Section gaps:** 22-30px between blocks inside a scroll view.
- **Card grid:** 1 to 5 columns, pinch-zoomable. Tile height derives from real tile width so artwork is never cropped at any column count.
- **Narrow widths:** Multi-column rows stack rather than overflow. No horizontal scrolling.

## Elevation & Depth

`box-shadow: 4px 4px 0` in the border colour, `border: 3px solid` in the border
colour, no gradients, no blur anywhere.

Depth comes only from the offset shadow. Material elevation, surface tints and
blurred shadows are all switched off in `theme.dart` because any one of them
would soften the silhouette.

- **Physics:** Ease-out, 120-200ms. Smooth and predictable.
- **Hover:** Shadow grows from 4px to 6px over 120ms. Pointer devices only.
- **Press:** The box translates by the shadow offset while the shadow shrinks to zero, so the outer silhouette stays put and the control reads as a physical key.
- **Page transitions:** Fade only (200ms).
- **Performance:** Only transform and opacity animate.

## Shapes

Base corner radius 8px. Small tiles 6px, dense grid tiles 4px, chips fully
rounded (999px). Corners are slightly rounded, not sharp — the warmth is what
separates this from classic brutalism.

Dense elements (chips, compact tiles) drop to a 2px border so the stroke does
not swallow the content.

## Components

- **Primary Button:** 8px radius, accent fill, 3px border, 4px hard shadow. Label weight 900. Press sinks into the shadow. Disabled drops the shadow and fades to 45%.
- **Icon Button:** Square, same treatment, sized 36-52px depending on context.
- **Cards:** 8px radius, raised surface fill, 3px border, 4px hard shadow. Never a blurred shadow.
- **Chips:** Fully rounded, 2px border. Selected fills with an accent; unselected uses the raised surface.
- **Inputs:** Uppercase label above the field, 3px border, 4px hard shadow, no underline and no focus ring — the border already carries the weight.
- **Navigation:** Bottom bar with a 3px top rule. The active item is an accent-filled block with its shadow; inactive items keep a 2px border and no shadow.
- **Section headings:** Accent-filled icon tile beside an uppercase title.
- **Loading:** Linear progress or an inline spinner inside a bordered box. No shimmer skeletons.
- **Empty States:** Stacked offset squares as a flat, gradient-free depth motif, plus descriptive text.

## Icons

Vector icons only — never emoji, anywhere in the UI.

Material's bundled icon set covers most needs. The five tarot suit marks are
drawn as vector paths instead, because Material has no sword, chalice or
pentacle, and substituting element icons (fire, water drop, wind, leaf) names
the correspondence rather than the suit.

## Do's and Don'ts

- No emojis in UI — vector icons only
- No gradients, anywhere
- No blurred shadows — offset hard shadows only
- No Material elevation or surface tint
- No thin borders on primary surfaces — 3px, dropping to 2px only on dense elements
- No low-contrast text on accent fills — accents always carry ink-coloured content

- Do Hard borders (2-4px)
- Do Hard offset shadows
- Do High saturation colors
- Do Bold typography
- Do Distinctive 'ugly-cute' look
