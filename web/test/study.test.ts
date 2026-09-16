import { describe, expect, it } from 'vitest';
import { cards } from '../src/lib/cards';
import {
  availableFacets,
  buildHint,
  buildQuestion,
  drawCard,
  emptyState,
  facetLabel,
  referenceAnswer,
} from '../src/lib/study';

/**
 * The draw is a port of `learning/study.py`. The property that matters is the
 * no-repeat cycle: a broken shuffle would silently show the same card twice
 * and nobody would notice from a screenshot.
 */
describe('drawCard', () => {
  const deck = cards('vi');

  it('walks all 78 cards before repeating any', () => {
    const state = emptyState();
    const seen = new Set<string>();

    for (let i = 0; i < deck.length; i++) {
      const draw = drawCard(state, deck, 'vi');
      expect(seen.has(draw.card.name)).toBe(false);
      seen.add(draw.card.name);
    }

    expect(seen.size).toBe(deck.length);
    expect(state.cycle).toBe(1);
    expect(state.remaining).toHaveLength(0);
  });

  it('starts a new cycle once the deck runs out', () => {
    const state = emptyState();
    for (let i = 0; i < deck.length; i++) {
      drawCard(state, deck, 'vi');
    }

    const first = drawCard(state, deck, 'vi');
    expect(state.cycle).toBe(2);
    expect(first.remaining).toBe(deck.length - 1);
  });

  it('reports the remaining count it leaves behind', () => {
    const state = emptyState();
    const draw = drawCard(state, deck, 'vi');
    expect(draw.remaining).toBe(deck.length - 1);
    expect(draw.cycle).toBe(1);
  });

  it('varies the facet across consecutive draws', () => {
    const state = emptyState();
    const facets = new Set<string>();
    for (let i = 0; i < 6; i++) {
      facets.add(drawCard(state, deck, 'vi').facet);
    }
    expect(facets.size).toBeGreaterThan(1);
  });

  it('only ever asks about a facet the card actually has', () => {
    const state = emptyState();
    for (let i = 0; i < deck.length; i++) {
      const draw = drawCard(state, deck, 'vi');
      expect(availableFacets(draw.card)).toContain(draw.facet);
      expect(draw.answer.length).toBeGreaterThan(0);
    }
  });

  it('survives stored state that names cards no longer in the deck', () => {
    const state = emptyState();
    state.remaining = ['Card That Was Removed'];
    state.seen = ['Card That Was Removed'];

    const draw = drawCard(state, deck, 'vi');
    expect(deck.some((card) => card.name === draw.card.name)).toBe(true);
  });
});

describe('question text', () => {
  it('names the card and the facet in both languages', () => {
    expect(buildQuestion('The Fool', 'upright.love', 'vi')).toContain(
      'Lá bài: The Fool',
    );
    expect(buildQuestion('The Fool', 'upright.love', 'vi')).toContain(
      facetLabel('upright.love', 'vi'),
    );
    expect(buildQuestion('The Fool', 'upright.love', 'en')).toContain(
      'Card: The Fool',
    );
  });

  it('gives an orientation-aware hint', () => {
    expect(buildHint('reversed.love', 'vi')).toContain('ngược');
    expect(buildHint('upright.love', 'vi')).toContain('xuôi');
    expect(buildHint('reversed.career', 'en')).toContain('reversed');
    expect(buildHint('symbols', 'en')).toContain('symbols');
  });
});

describe('referenceAnswer', () => {
  const deck = cards('en');
  const fool = deck.find((card) => card.slug === 'the-fool')!;

  it('returns the card description for the overview facet', () => {
    expect(referenceAnswer(fool, 'overview')).toBe(fool.description);
  });

  it('joins the correspondences into readable lines', () => {
    const answer = referenceAnswer(fool, 'correspondences');
    expect(answer).toContain('Type:');
    expect(answer).toContain('Element:');
  });

  it('returns the matching orientation field', () => {
    expect(referenceAnswer(fool, 'upright.love')).toBe(fool.upright?.love);
    expect(referenceAnswer(fool, 'reversed.career')).toBe(fool.reversed?.career);
  });
});
