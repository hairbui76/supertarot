import type { Lang, TarotCard } from './cards';

/**
 * The three-card spread: past, present, future.
 *
 * Unlike the quiz, which walks a no-repeat 78-card cycle across sessions, a
 * spread is a fresh reading every time. The only rule is the one a physical
 * deck enforces - three different cards - and each card lands upright or
 * reversed with equal odds.
 */

export const SPREAD_SIZE = 3;

export const SPREAD_POSITIONS: Record<Lang, string[]> = {
  vi: ['Quá khứ', 'Hiện tại', 'Tương lai'],
  en: ['Past', 'Present', 'Future'],
};

export interface SpreadCard {
  card: TarotCard;
  reversed: boolean;
}

/** What gets persisted: enough to rebuild the spread, not the card data. */
export interface SavedSpread {
  slug: string;
  reversed: boolean;
}

/**
 * Draws [size] distinct cards. [random] returns a float in [0, 1), and is only
 * a parameter so tests can make the draw deterministic.
 */
export function drawSpread(
  deck: TarotCard[],
  random: () => number = Math.random,
  size: number = SPREAD_SIZE,
): SpreadCard[] {
  const pool = deck.slice();
  const count = Math.min(size, pool.length);
  const drawn: SpreadCard[] = [];
  // A partial Fisher-Yates: only the first [count] slots need shuffling.
  for (let i = 0; i < count; i++) {
    const j = i + Math.floor(random() * (pool.length - i));
    [pool[i], pool[j]] = [pool[j], pool[i]];
    drawn.push({ card: pool[i], reversed: random() < 0.5 });
  }
  return drawn;
}

export function saveSpread(spread: SpreadCard[]): SavedSpread[] {
  return spread.map(({ card, reversed }) => ({ slug: card.slug, reversed }));
}

/**
 * Rebuilds a saved spread against the current deck. Anything that no longer
 * matches - a renamed card, a wrong length, a corrupt value - yields null so
 * the page simply starts empty.
 */
export function restoreSpread(
  deck: TarotCard[],
  saved: unknown,
): SpreadCard[] | null {
  if (!Array.isArray(saved) || saved.length !== SPREAD_SIZE) {
    return null;
  }
  const bySlug = new Map(deck.map((card) => [card.slug, card]));
  const spread: SpreadCard[] = [];
  for (const entry of saved) {
    const card = bySlug.get((entry as SavedSpread)?.slug);
    if (!card) {
      return null;
    }
    spread.push({ card, reversed: (entry as SavedSpread).reversed === true });
  }
  return new Set(spread.map((item) => item.card.slug)).size === spread.length
    ? spread
    : null;
}
