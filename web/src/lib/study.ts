import type { Lang, TarotCard } from './cards';

/**
 * Card rotation and question selection, ported from `learning/study.py` (and
 * matching `mobile/lib/src/services/study_service.dart`).
 *
 * The deck walks a 78-card cycle: no card repeats until the whole deck has
 * been drawn, then a new shuffled cycle starts. The facet cursor advances
 * independently so consecutive draws ask about different aspects.
 *
 * Grading is deliberately absent here - it needs an LLM, and the web build
 * ships without AI. The reference answer is shown instead.
 */

export const FACET_ORDER = [
  'overview',
  'upright.summary',
  'reversed.summary',
  'upright.love',
  'reversed.love',
  'upright.career',
  'reversed.career',
  'upright.finances',
  'reversed.finances',
  'upright.feelings',
  'reversed.feelings',
  'upright.actions',
  'reversed.actions',
  'symbols',
  'correspondences',
] as const;

export type Facet = (typeof FACET_ORDER)[number];

const FACET_LABELS: Record<string, Record<Lang, string>> = {
  overview: {
    en: 'overall card meaning',
    vi: 'ý nghĩa tổng quan của lá bài',
  },
  correspondences: {
    en: 'element, astrology, and yes/no correspondences',
    vi: 'nguyên tố, chiêm tinh và yes/no',
  },
  symbols: { en: 'main symbols', vi: 'các biểu tượng chính' },
  'upright.summary': { en: 'upright meaning', vi: 'ý nghĩa xuôi chiều' },
  'upright.love': {
    en: 'upright love meaning',
    vi: 'ý nghĩa tình yêu khi xuôi chiều',
  },
  'upright.career': {
    en: 'upright career meaning',
    vi: 'ý nghĩa sự nghiệp khi xuôi chiều',
  },
  'upright.finances': {
    en: 'upright finances meaning',
    vi: 'ý nghĩa tài chính khi xuôi chiều',
  },
  'upright.feelings': {
    en: 'upright feelings meaning',
    vi: 'ý nghĩa cảm xúc khi xuôi chiều',
  },
  'upright.actions': {
    en: 'upright actions meaning',
    vi: 'ý nghĩa hành động khi xuôi chiều',
  },
  'reversed.summary': { en: 'reversed meaning', vi: 'ý nghĩa ngược chiều' },
  'reversed.love': {
    en: 'reversed love meaning',
    vi: 'ý nghĩa tình yêu khi ngược chiều',
  },
  'reversed.career': {
    en: 'reversed career meaning',
    vi: 'ý nghĩa sự nghiệp khi ngược chiều',
  },
  'reversed.finances': {
    en: 'reversed finances meaning',
    vi: 'ý nghĩa tài chính khi ngược chiều',
  },
  'reversed.feelings': {
    en: 'reversed feelings meaning',
    vi: 'ý nghĩa cảm xúc khi ngược chiều',
  },
  'reversed.actions': {
    en: 'reversed actions meaning',
    vi: 'ý nghĩa hành động khi ngược chiều',
  },
};

export function facetLabel(facet: string, lang: Lang): string {
  const entry = FACET_LABELS[facet] ?? FACET_LABELS.overview;
  return entry[lang] ?? entry.en;
}

function sectionOf(card: TarotCard, orientation: string) {
  return orientation === 'upright' ? card.upright : card.reversed;
}

function hasValue(card: TarotCard, facet: string): boolean {
  if (facet === 'overview') {
    const keywords = card.upright_keywords;
    const hasKeywords = Array.isArray(keywords)
      ? keywords.length > 0
      : Boolean(keywords);
    return Boolean(card.description) || hasKeywords;
  }
  if (facet === 'correspondences') {
    return Boolean(card.type || card.element || card.astrology || card.yes_no);
  }
  if (facet === 'symbols') {
    return Boolean(card.symbols && card.symbols.length);
  }

  const [orientation, field] = facet.split('.');
  const section = sectionOf(card, orientation);
  if (!section) {
    return false;
  }
  if (field === 'summary') {
    return Boolean(section.description);
  }
  return Boolean((section as Record<string, string | undefined>)[field]);
}

export function availableFacets(card: TarotCard): string[] {
  return FACET_ORDER.filter((facet) => hasValue(card, facet));
}

export function buildQuestion(
  cardName: string,
  facet: string,
  lang: Lang,
): string {
  const label = facetLabel(facet, lang);
  if (lang === 'vi') {
    return (
      `Lá bài: ${cardName}. Hãy giải thích ${label}. ` +
      'Trả lời 3-5 ý chính, có ví dụ ngắn nếu nhớ được.'
    );
  }
  return (
    `Card: ${cardName}. Explain the ${label}. ` +
    'Answer with 3-5 key points and a short example if you can.'
  );
}

export function buildHint(facet: string, lang: Lang): string {
  const parts = facet.split('.');
  if (parts.length === 2) {
    const reversed = parts[0] === 'reversed';
    if (lang === 'vi') {
      const field =
        ({
          love: 'tình yêu',
          career: 'sự nghiệp',
          finances: 'tài chính',
          feelings: 'cảm xúc',
          actions: 'hành động',
        } as Record<string, string>)[parts[1]] ?? 'ý nghĩa';
      return reversed
        ? `Với ${field}, nhìn mặt ngược: điều gì đang bị kẹt, lệch nhịp hoặc cần điều chỉnh?`
        : `Với ${field}, nhìn mặt xuôi: năng lượng này hỗ trợ điều gì và nên ứng xử ra sao?`;
    }
    const field =
      ({
        love: 'love',
        career: 'career',
        finances: 'finances',
        feelings: 'feelings',
        actions: 'actions',
      } as Record<string, string>)[parts[1]] ?? 'meaning';
    return reversed
      ? `For ${field}, read the reversed side: what is blocked, distorted, or asking for adjustment?`
      : `For ${field}, read the upright side: what does this energy support, and what response fits?`;
  }

  const hints: Record<string, Record<Lang, string>> = {
    overview: {
      vi: 'Nêu năng lượng cốt lõi, tình huống thường gặp và một lời khuyên.',
      en: 'Name the core energy, a common situation, and one practical advice.',
    },
    correspondences: {
      vi: 'Liên hệ bộ bài, nguyên tố, chiêm tinh hoặc yes/no với cách lá vận hành.',
      en: 'Connect suit, element, astrology, or yes/no to how the card behaves.',
    },
    symbols: {
      vi: 'Chọn 1-2 biểu tượng nổi bật và giải thích chúng gợi điều gì.',
      en: 'Pick 1-2 strong symbols and explain what they suggest.',
    },
  };
  const entry = hints[facet] ?? hints.overview;
  return entry[lang] ?? entry.en;
}

/** The reference text the question is asking about, shown instead of grading. */
export function referenceAnswer(card: TarotCard, facet: string): string {
  if (facet === 'overview') {
    return card.description ?? '';
  }
  if (facet === 'correspondences') {
    return [
      card.type && `Type: ${card.type}`,
      card.element && `Element: ${card.element}`,
      card.astrology && `Astrology: ${card.astrology}`,
      card.yes_no && `Yes/No: ${card.yes_no}`,
    ]
      .filter(Boolean)
      .join('\n');
  }
  if (facet === 'symbols') {
    return (card.symbols ?? [])
      .map((symbol) =>
        [symbol.name, symbol.meaning].filter(Boolean).join(': '),
      )
      .filter(Boolean)
      .join('\n');
  }

  const [orientation, field] = facet.split('.');
  const section = sectionOf(card, orientation);
  if (!section) {
    return '';
  }
  if (field === 'summary') {
    return section.description ?? '';
  }
  return (section as Record<string, string | undefined>)[field] ?? '';
}

export interface DrawState {
  cycle: number;
  remaining: string[];
  seen: string[];
  cursor: number;
}

export function emptyState(): DrawState {
  return { cycle: 1, remaining: [], seen: [], cursor: 0 };
}

export interface Draw {
  card: TarotCard;
  facet: string;
  facetLabel: string;
  question: string;
  hint: string;
  answer: string;
  cycle: number;
  remaining: number;
}

function shuffle<T>(items: T[]): T[] {
  const copy = items.slice();
  for (let i = copy.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

/** Advances [state] in place and returns the draw it produced. */
export function drawCard(
  state: DrawState,
  deck: TarotCard[],
  lang: Lang,
): Draw {
  const byName = new Map(deck.map((card) => [card.name, card]));

  // Drop names that no longer exist in the data before deciding whether the
  // cycle is exhausted.
  let remaining = state.remaining.filter((name) => byName.has(name));
  if (remaining.length === 0) {
    if (state.seen.length > 0) {
      state.cycle += 1;
    }
    remaining = shuffle([...byName.keys()]);
    state.seen = [];
  }

  const name = remaining.shift()!;
  const card = byName.get(name)!;
  state.seen.push(name);
  state.remaining = remaining;

  const available = availableFacets(card);
  let facet: string = available[0] ?? 'overview';
  for (let offset = 0; offset < FACET_ORDER.length; offset++) {
    const candidate = FACET_ORDER[(state.cursor + offset) % FACET_ORDER.length];
    if (available.includes(candidate)) {
      facet = candidate;
      state.cursor = state.cursor + offset + 1;
      break;
    }
  }

  return {
    card,
    facet,
    facetLabel: facetLabel(facet, lang),
    question: buildQuestion(card.name, facet, lang),
    hint: buildHint(facet, lang),
    answer: referenceAnswer(card, facet),
    cycle: state.cycle,
    remaining: remaining.length,
  };
}
