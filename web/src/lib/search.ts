import { SUITS, type Lang, type TarotCard } from './cards';

/**
 * Card search. Names are the English "Two of Cups", so a plain substring match
 * misses the way people actually look a card up: by number ("2", "2 cups"), or
 * by the Vietnamese suit ("2 cốc", "2 coc" without diacritics).
 *
 * Each card gets a search key - its name, its number, and both languages'
 * names for its suit - and a query matches when every word in it matches a
 * word of the key.
 */

const RANKS: Record<string, number> = {
  ace: 1,
  two: 2,
  three: 3,
  four: 4,
  five: 5,
  six: 6,
  seven: 7,
  eight: 8,
  nine: 9,
  ten: 10,
};

/** Lowercase, without Vietnamese diacritics, so "coc" finds "cốc". */
export function fold(text: string): string {
  return text
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/đ/g, 'd');
}

function words(text: string): string[] {
  return fold(text).split(/[^\p{L}\p{N}]+/u).filter(Boolean);
}

/**
 * The card's number: 0-21 for the Major Arcana, Ace (1) to Ten for the pips.
 * Court cards have none.
 */
export function cardNumber(card: TarotCard, lang: Lang): number | null {
  const suit = SUITS.find(
    (item) => (lang === 'vi' ? item.typeVi : item.typeEn) === card.type,
  );
  if (suit?.key === 'major') {
    return card.order;
  }
  return RANKS[fold(card.name).split(' ')[0]] ?? null;
}

export function searchKey(card: TarotCard, lang: Lang): string {
  const suit = SUITS.find(
    (item) => (lang === 'vi' ? item.typeVi : item.typeEn) === card.type,
  );
  const parts = [card.name];
  const number = cardNumber(card, lang);
  if (number !== null) {
    parts.push(String(number));
  }
  if (suit) {
    parts.push(suit.labelEn, suit.labelVi, suit.typeEn, suit.typeVi);
  }
  // Deduplicated so the attribute stays short.
  return [...new Set(words(parts.join(' ')))].join(' ');
}

/**
 * Every query word has to match a key word. A number must match exactly, so
 * "2" finds the Twos but not XII or XX; a word only has to start one, so
 * typing is incremental ("prie" finds The High Priestess).
 */
export function matchesQuery(key: string, query: string): boolean {
  const wanted = words(query);
  if (wanted.length === 0) {
    return true;
  }
  const have = key.split(' ');
  return wanted.every((word) =>
    /^\d+$/.test(word)
      ? have.includes(word)
      : have.some((candidate) => candidate.startsWith(word)),
  );
}
