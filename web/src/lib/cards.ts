import cardsEn from '../data/cards_en.json';
import cardsVi from '../data/cards_vi.json';

export type Lang = 'vi' | 'en';

export const LANGS: Lang[] = ['vi', 'en'];

export interface CardSection {
  description?: string;
  love?: string;
  career?: string;
  finances?: string;
  feelings?: string;
  actions?: string;
}

export interface CardSymbol {
  name?: string;
  meaning?: string;
}

export interface TarotCard {
  name: string;
  slug: string;
  order: number;
  type?: string;
  element?: string;
  astrology?: string;
  yes_no?: string;
  description?: string;
  card_image: string;
  upright_keywords?: string[] | string;
  reversed_keywords?: string[] | string;
  short_meaning?: string;
  short_rev_meaning?: string;
  upright?: CardSection;
  reversed?: CardSection;
  symbols?: CardSymbol[];
}

const BY_LANG: Record<Lang, TarotCard[]> = {
  en: cardsEn as TarotCard[],
  vi: cardsVi as TarotCard[],
};

export function cards(lang: Lang): TarotCard[] {
  return BY_LANG[lang];
}

export function cardBySlug(lang: Lang, slug: string): TarotCard | undefined {
  return BY_LANG[lang].find((card) => card.slug === slug);
}

/**
 * The five deck sections in traditional order. `typeEn`/`typeVi` are the
 * values the crawler writes into each card's `type` field.
 *
 * `symbol` is the suit's own object - staff, chalice, blade, coin - not its
 * element. The accent does follow the element: fire red, water blue, air
 * yellow, earth green, with violet reserved for the Major Arcana.
 */
export interface Suit {
  key: string;
  typeEn: string;
  typeVi: string;
  labelEn: string;
  labelVi: string;
  accent: string;
}

export const SUITS: Suit[] = [
  {
    key: 'major',
    typeEn: 'Major Arcana',
    typeVi: 'Bộ Ẩn Chính',
    labelEn: 'Major Arcana',
    labelVi: 'Ẩn Chính',
    accent: 'var(--violet)',
  },
  {
    key: 'wands',
    typeEn: 'Wands',
    typeVi: 'Gậy',
    labelEn: 'Wands',
    labelVi: 'Gậy',
    accent: 'var(--red)',
  },
  {
    key: 'cups',
    typeEn: 'Cups',
    typeVi: 'Cốc',
    labelEn: 'Cups',
    labelVi: 'Cốc',
    accent: 'var(--blue)',
  },
  {
    key: 'swords',
    typeEn: 'Swords',
    typeVi: 'Kiếm',
    labelEn: 'Swords',
    labelVi: 'Kiếm',
    accent: 'var(--yellow)',
  },
  {
    key: 'pentacles',
    typeEn: 'Pentacles',
    typeVi: 'Tiền Vàng',
    labelEn: 'Pentacles',
    labelVi: 'Tiền Vàng',
    accent: 'var(--green)',
  },
];

export function suitByKey(key: string): Suit | undefined {
  return SUITS.find((suit) => suit.key === key);
}

export function suitType(suit: Suit, lang: Lang): string {
  return lang === 'vi' ? suit.typeVi : suit.typeEn;
}

export function suitLabel(suit: Suit, lang: Lang): string {
  return lang === 'vi' ? suit.labelVi : suit.labelEn;
}

export function cardsForSuit(lang: Lang, suit: Suit): TarotCard[] {
  const expected = suitType(suit, lang);
  return cards(lang).filter((card) => card.type === expected);
}

/** Keywords come through as either an array or a comma-joined string. */
export function keywordList(value: string[] | string | undefined): string[] {
  if (Array.isArray(value)) {
    return value.filter(Boolean);
  }
  if (typeof value === 'string' && value.trim()) {
    return value.split(',').map((item) => item.trim()).filter(Boolean);
  }
  return [];
}

/** Every href has to carry Astro's base path when deployed under /supertarot. */
export function href(base: string, ...parts: string[]): string {
  const trimmed = base.replace(/\/+$/, '');
  const path = parts
    .map((part) => part.replace(/^\/+|\/+$/g, ''))
    .filter(Boolean)
    .join('/');
  return path ? `${trimmed}/${path}/` : `${trimmed}/`;
}

/** A file in public/. Unlike routes, these must not gain a trailing slash. */
export function asset(base: string, name: string): string {
  return `${base.replace(/\/+$/, '')}/${name.replace(/^\/+/, '')}`;
}
