import { describe, expect, it } from 'vitest';
import type { TarotCard } from '../src/lib/cards';
import {
  drawSpread,
  restoreSpread,
  saveSpread,
  SPREAD_POSITIONS,
  SPREAD_SIZE,
} from '../src/lib/spread';

const deck: TarotCard[] = Array.from({ length: 78 }, (_, order) => ({
  name: `Card ${order}`,
  slug: `card-${order}`,
  order,
  card_image: `card-${order}.jpg`,
}));

/** A seeded generator, so a failure reproduces. */
function seeded(seed: number): () => number {
  let value = seed;
  return () => {
    value = (value * 1664525 + 1013904223) % 4294967296;
    return value / 4294967296;
  };
}

describe('drawSpread', () => {
  it('draws three different cards', () => {
    for (let seed = 1; seed <= 500; seed++) {
      const spread = drawSpread(deck, seeded(seed));
      expect(spread).toHaveLength(SPREAD_SIZE);
      expect(new Set(spread.map((item) => item.card.slug)).size).toBe(SPREAD_SIZE);
    }
  });

  it('can reach every card and both orientations', () => {
    const slugs = new Set<string>();
    const orientations = new Set<boolean>();
    for (let seed = 1; seed <= 500; seed++) {
      for (const item of drawSpread(deck, seeded(seed))) {
        slugs.add(item.card.slug);
        orientations.add(item.reversed);
      }
    }
    expect(slugs.size).toBe(deck.length);
    expect(orientations).toEqual(new Set([true, false]));
  });

  it('does not reorder the deck it was given', () => {
    const before = deck.map((card) => card.slug);
    drawSpread(deck, seeded(7));
    expect(deck.map((card) => card.slug)).toEqual(before);
  });

  it('handles the edges of the random range', () => {
    expect(drawSpread(deck, () => 0).map((item) => item.card.slug)).toEqual([
      'card-0',
      'card-1',
      'card-2',
    ]);
    const high = drawSpread(deck, () => 0.999999);
    expect(new Set(high.map((item) => item.card.slug)).size).toBe(SPREAD_SIZE);
  });

  it('has a position label for every card, in both languages', () => {
    expect(SPREAD_POSITIONS.vi).toHaveLength(SPREAD_SIZE);
    expect(SPREAD_POSITIONS.en).toHaveLength(SPREAD_SIZE);
  });
});

describe('restoreSpread', () => {
  it('round-trips a saved spread', () => {
    const spread = drawSpread(deck, seeded(3));
    const saved = JSON.parse(JSON.stringify(saveSpread(spread)));
    expect(restoreSpread(deck, saved)).toEqual(spread);
  });

  it('rejects anything that no longer matches the deck', () => {
    expect(restoreSpread(deck, null)).toBeNull();
    expect(restoreSpread(deck, 'nonsense')).toBeNull();
    expect(restoreSpread(deck, [{ slug: 'card-1', reversed: false }])).toBeNull();
    expect(
      restoreSpread(deck, [
        { slug: 'card-1', reversed: false },
        { slug: 'renamed', reversed: false },
        { slug: 'card-3', reversed: true },
      ]),
    ).toBeNull();
    expect(
      restoreSpread(deck, [
        { slug: 'card-1', reversed: false },
        { slug: 'card-1', reversed: true },
        { slug: 'card-3', reversed: true },
      ]),
    ).toBeNull();
  });
});
