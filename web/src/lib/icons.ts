/**
 * Inline SVG icons, Lucide-style stroke geometry on a 24x24 grid.
 *
 * DESIGN.md forbids emoji in the UI, and inlining keeps them gradient-free and
 * recolourable with `currentColor` without a webfont request.
 */

const stroke =
  'fill="none" stroke="currentColor" stroke-width="2.2" ' +
  'stroke-linecap="round" stroke-linejoin="round"';

function svg(body: string): string {
  return `<svg viewBox="0 0 24 24" aria-hidden="true" ${stroke}>${body}</svg>`;
}

export const icons: Record<string, string> = {
  search: svg('<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>'),
  close: svg('<path d="M18 6 6 18M6 6l12 12"/>'),
  arrowRight: svg('<path d="M5 12h14M13 6l6 6-6 6"/>'),
  arrowLeft: svg('<path d="M19 12H5M11 18l-6-6 6-6"/>'),
  // Three cards fanned side by side, for the spread.
  cards: svg(
    '<rect x="2" y="6" width="6" height="12" rx="1"/>' +
      '<rect x="9" y="4" width="6" height="16" rx="1"/>' +
      '<rect x="16" y="6" width="6" height="12" rx="1"/>',
  ),
  arrowUp: svg('<path d="M12 19V5M6 11l6-6 6 6"/>'),
  arrowDown: svg('<path d="M12 5v14M18 13l-6 6-6-6"/>'),
  sparkle: svg(
    '<path d="M12 3c.9 4.6 2.5 6.2 7 7-4.5.8-6.1 2.4-7 7-.9-4.6-2.5-6.2-7-7 4.5-.8 6.1-2.4 7-7Z"/>',
  ),
  book: svg(
    '<path d="M4 5a2 2 0 0 1 2-2h5v18H6a2 2 0 0 1-2-2Z"/>' +
      '<path d="M20 5a2 2 0 0 0-2-2h-5v18h5a2 2 0 0 0 2-2Z"/>',
  ),
  shuffle: svg(
    '<path d="M16 4h4v4"/><path d="M4 20 20 4"/><path d="M16 20h4v-4"/>' +
      '<path d="m4 4 5 5"/><path d="m15 15 5 5"/>',
  ),
  image: svg(
    '<rect x="3" y="4" width="18" height="16" rx="2"/>' +
      '<circle cx="8.5" cy="9.5" r="1.5"/><path d="m4 18 5-5 4 4 3-3 4 4"/>',
  ),
  heart: svg(
    '<path d="M12 20s-7-4.4-7-9.2A4 4 0 0 1 12 8a4 4 0 0 1 7 2.8C19 15.6 12 20 12 20Z"/>',
  ),
  briefcase: svg(
    '<rect x="3" y="7" width="18" height="13" rx="2"/>' +
      '<path d="M9 7V5a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v2"/><path d="M3 12h18"/>',
  ),
  coins: svg(
    '<ellipse cx="9" cy="7" rx="6" ry="3"/><path d="M3 7v5c0 1.7 2.7 3 6 3"/>' +
      '<path d="M3 12v5c0 1.7 2.7 3 6 3"/><ellipse cx="15" cy="15" rx="6" ry="3"/>' +
      '<path d="M21 15v4c0 1.7-2.7 3-6 3s-6-1.3-6-3"/>',
  ),
  brain: svg(
    '<path d="M12 5a3 3 0 0 0-6 .5A3 3 0 0 0 4 8a3 3 0 0 0 1 2.2A3 3 0 0 0 6 16a3 3 0 0 0 6 .5Z"/>' +
      '<path d="M12 5a3 3 0 0 1 6 .5A3 3 0 0 1 20 8a3 3 0 0 1-1 2.2A3 3 0 0 1 18 16a3 3 0 0 1-6 .5Z"/>',
  ),
  target: svg(
    '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="4"/>' +
      '<circle cx="12" cy="12" r="1"/>',
  ),
  tag: svg(
    '<path d="M3 11V5a2 2 0 0 1 2-2h6l9 9-8 8-9-9Z"/><circle cx="8" cy="8" r="1.4"/>',
  ),
  moon: svg('<path d="M20 14.5A8.5 8.5 0 1 1 9.5 4a6.6 6.6 0 0 0 10.5 10.5Z"/>'),
  leaf: svg(
    '<path d="M5 19c0-8 5-13 14-13 0 9-5 14-13 14"/><path d="M5 19c3-3 6-5 10-6"/>',
  ),
  help: svg(
    '<circle cx="12" cy="12" r="9"/>' +
      '<path d="M9.5 9.5a2.6 2.6 0 0 1 5 .8c0 1.8-2.5 2-2.5 3.7"/>' +
      '<path d="M12 17.2h.01"/>',
  ),
  bulb: svg(
    '<path d="M9 18h6"/><path d="M10 21h4"/>' +
      '<path d="M12 3a6 6 0 0 0-3.5 10.9c.4.3.5.8.5 1.1h6c0-.3.1-.8.5-1.1A6 6 0 0 0 12 3Z"/>',
  ),
  eye: svg(
    '<path d="M2 12s3.6-6 10-6 10 6 10 6-3.6 6-10 6S2 12 2 12Z"/>' +
      '<circle cx="12" cy="12" r="2.6"/>',
  ),
  eyeOff: svg(
    '<path d="M4 4 20 20"/>' +
      '<path d="M9.9 5.2A9.6 9.6 0 0 1 12 5c6.4 0 10 6 10 6a17 17 0 0 1-3.2 3.7"/>' +
      '<path d="M6.3 7.8A16.8 16.8 0 0 0 2 11s3.6 6 10 6a9.7 9.7 0 0 0 3.6-.7"/>',
  ),
  rotate: svg(
    '<path d="M3 12a9 9 0 0 1 15.3-6.4L21 8"/><path d="M21 3v5h-5"/>' +
      '<path d="M21 12a9 9 0 0 1-15.3 6.4L3 16"/><path d="M3 21v-5h5"/>',
  ),
  contrast: svg('<circle cx="12" cy="12" r="9"/><path d="M12 3v18a9 9 0 0 0 0-18Z" fill="currentColor"/>'),
  download: svg('<path d="M12 3v12"/><path d="m7 11 5 5 5-5"/><path d="M4 20h16"/>'),
  grid: svg(
    '<rect x="3" y="3" width="7" height="7" rx="1"/>' +
      '<rect x="14" y="3" width="7" height="7" rx="1"/>' +
      '<rect x="3" y="14" width="7" height="7" rx="1"/>' +
      '<rect x="14" y="14" width="7" height="7" rx="1"/>',
  ),
  minus: svg('<path d="M5 12h14"/>'),
  share: svg(
    '<path d="M12 3v12"/><path d="m8 7 4-4 4 4"/>' +
      '<path d="M6 11H5a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-6a2 2 0 0 0-2-2h-1"/>',
  ),
  homeAdd: svg(
    '<rect x="3" y="3" width="18" height="18" rx="3"/><path d="M12 8v8M8 12h8"/>',
  ),

  plus: svg('<path d="M12 5v14M5 12h14"/>'),
};

/**
 * The five deck symbols. Generic icon sets have no sword, chalice or
 * pentacle, and element icons (fire, water drop, wind, leaf) would name the
 * correspondence rather than the suit. These mirror the Flutter app's
 * `suit_glyph.dart` paths.
 */
export const suitGlyphs: Record<string, string> = {
  major: `<svg viewBox="0 0 24 24" aria-hidden="true">
    <path fill="currentColor" d="M12 1.5c1.2 6.9 3.6 9.3 10.5 10.5C15.6 13.2 13.2 15.6 12 22.5 10.8 15.6 8.4 13.2 1.5 12 8.4 10.8 10.8 8.4 12 1.5Z"/>
  </svg>`,
  wand: `<svg viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round">
    <path d="M4.5 19.5 16 8"/>
    <circle cx="18.2" cy="5.8" r="2.6" fill="currentColor" stroke="none"/>
    <path fill="currentColor" stroke="none" d="M10.5 13.5c-3-2-6-.2-4 2.3 2.3 1.4 4-.6 4-2.3Z"/>
  </svg>`,
  cup: `<svg viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round">
    <path d="M5 5.5h14c0 6-3 9.5-7 9.5S5 11.5 5 5.5Z"/>
    <path d="M12 15v4"/><path d="M8 19.5h8"/>
  </svg>`,
  sword: `<svg viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round">
    <path d="M12 1.6 14.6 6.5V14H9.4V6.5Z"/>
    <path d="M6.5 14.8h11"/><path d="M12 15.6v4"/>
    <circle cx="12" cy="20.8" r="1.5" fill="currentColor" stroke="none"/>
  </svg>`,
  pentacle: `<svg viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linejoin="round">
    <circle cx="12" cy="12" r="9.2"/>
    <path stroke-width="1.7" d="M12 6.4 16.3 15.5 8.6 9.9h6.8L7.7 15.5Z"/>
  </svg>`,
};

export function icon(name: string): string {
  return icons[name] ?? '';
}
