import { describe, expect, it } from 'vitest';
import { cards, type Lang } from '../src/lib/cards';
import { fold, matchesQuery, searchKey } from '../src/lib/search';

/** Card names a query finds, against the real deck data. */
function find(lang: Lang, query: string): string[] {
  return cards(lang)
    .filter((card) => matchesQuery(searchKey(card, lang), query))
    .map((card) => card.name);
}

describe('search by number', () => {
  it('finds every Two for "2", plus Major Arcana II', () => {
    expect(find('en', '2')).toEqual([
      'The High Priestess',
      'Two of Wands',
      'Two of Cups',
      'Two of Swords',
      'Two of Pentacles',
    ]);
  });

  it('matches numbers exactly, not as a prefix', () => {
    // 12, 20 and 21 must not come back for "2".
    expect(find('en', '2')).not.toContain('The Hanged Man');
    expect(find('en', '2')).not.toContain('Judgement');
    expect(find('en', '2')).not.toContain('The World');
  });

  it('treats the Ace as 1 and the Fool as 0', () => {
    expect(find('en', '1')).toContain('Ace of Cups');
    expect(find('en', '1')).toContain('The Magician');
    expect(find('en', '0')).toEqual(['The Fool']);
  });

  it('narrows a number by suit, in either language', () => {
    expect(find('en', '2 cups')).toEqual(['Two of Cups']);
    expect(find('en', '2 of cups')).toEqual(['Two of Cups']);
    expect(find('vi', '2 cốc')).toEqual(['Two of Cups']);
    expect(find('vi', '10 kiếm')).toEqual(['Ten of Swords']);
  });

  it('gives court cards no number', () => {
    expect(find('en', '11')).toEqual(['Justice']);
    expect(find('en', '14')).toEqual(['Temperance']);
  });
});

describe('search by name', () => {
  it('still finds names as they are typed', () => {
    expect(find('en', 'prie')).toEqual(['The High Priestess']);
    expect(find('en', 'ace of c')).toEqual(['Ace of Cups']);
    expect(find('vi', 'Queen of Wands')).toEqual(['Queen of Wands']);
  });

  it('ignores case and Vietnamese diacritics', () => {
    expect(fold('Tiền Vàng')).toBe('tien vang');
    expect(find('vi', 'king tien vang')).toEqual(['King of Pentacles']);
    expect(find('vi', 'KING GẬY')).toEqual(['King of Wands']);
  });

  it('shows everything for an empty query and nothing for nonsense', () => {
    expect(find('en', '  ')).toHaveLength(78);
    expect(find('en', 'zzz')).toEqual([]);
  });
});
