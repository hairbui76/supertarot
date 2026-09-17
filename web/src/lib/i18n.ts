import type { Lang } from './cards';

/**
 * UI copy. The card data itself already exists per language; this covers the
 * chrome only, and mirrors the wording the Android app uses.
 */
export interface Strings {
  siteTitle: string;
  tagline: string;
  metaDescription: string;
  browse: string;
  quiz: string;
  spread: string;
  chooseSuit: string;
  cardCount: string;
  search: string;
  searchHint: string;
  noResults: string;
  columns: string;
  fewerColumns: string;
  moreColumns: string;
  overview: string;
  upright: string;
  reversed: string;
  cardDescription: string;
  symbols: string;
  keywords: string;
  meaning: string;
  shortMeaning: string;
  love: string;
  career: string;
  finances: string;
  feelings: string;
  actions: string;
  type: string;
  element: string;
  astrology: string;
  yesNo: string;
  previous: string;
  next: string;
  backToSuits: string;
  quizTitle: string;
  quizIntro: string;
  quizButton: string;
  quizAgain: string;
  spreadTitle: string;
  spreadIntro: string;
  spreadButton: string;
  spreadAgain: string;
  spreadEmpty: string;
  spreadScroll: string;
  correspondences: string;
  question: string;
  hint: string;
  showAnswer: string;
  hideAnswer: string;
  answer: string;
  cycle: string;
  resetCycle: string;
  openCard: string;
  theme: string;
  getApp: string;
  appNote: string;
  author: string;
  installTitle: string;
  installIos: string;
  installButton: string;
  installDismiss: string;
}

export const STRINGS: Record<Lang, Strings> = {
  vi: {
    siteTitle: 'SuperTarot',
    tagline: 'Tra cứu ý nghĩa 78 lá tarot',
    metaDescription:
      'Tra cứu ý nghĩa đầy đủ 78 lá bài tarot: nghĩa xuôi và ngược, tình yêu, ' +
      'sự nghiệp, tài chính, cảm xúc, hành động, biểu tượng và chiêm tinh.',
    browse: 'Tra cứu',
    quiz: 'Kiểm tra',
    spread: 'Bốc bài',
    chooseSuit: 'Chọn bộ bài',
    cardCount: 'lá',
    search: 'Tìm lá bài',
    searchHint: 'Gõ tên lá bài, ví dụ The Fool hoặc Ace of Cups',
    noResults: 'Không tìm thấy lá bài nào.',
    columns: 'Số cột',
    fewerColumns: 'Ít cột hơn',
    moreColumns: 'Nhiều cột hơn',
    overview: 'Tổng quan',
    upright: 'Xuôi',
    reversed: 'Ngược',
    cardDescription: 'Mô tả lá bài',
    symbols: 'Biểu tượng',
    keywords: 'Từ khóa',
    meaning: 'Ý nghĩa',
    shortMeaning: 'Nghĩa cô đọng',
    love: 'Tình yêu',
    career: 'Sự nghiệp',
    finances: 'Tài chính',
    feelings: 'Cảm xúc',
    actions: 'Hành động',
    type: 'Bộ',
    element: 'Nguyên tố',
    astrology: 'Chiêm tinh',
    yesNo: 'Yes/No',
    previous: 'Lá trước',
    next: 'Lá sau',
    backToSuits: 'Tất cả bộ bài',
    quizTitle: 'Kiểm tra',
    quizIntro:
      'Mỗi lần rút một lá và hỏi một khía cạnh cụ thể. Không lặp lá nào cho ' +
      'tới khi đi hết 78 lá.',
    quizButton: 'Rút một lá',
    quizAgain: 'Rút lá khác',
    spreadTitle: 'Bốc bài',
    spreadIntro:
      'Bốc ngẫu nhiên 3 lá cho quá khứ, hiện tại và tương lai. Mỗi lá có thể ' +
      'ra xuôi hoặc ngược, ý nghĩa đặt cạnh nhau để đối chiếu.',
    spreadButton: 'Bốc 3 lá',
    spreadAgain: 'Bốc lại',
    spreadEmpty: 'Bấm Bốc 3 lá để bắt đầu.',
    spreadScroll: 'Vuốt ngang để xem đủ 3 lá',
    correspondences: 'Tương ứng',
    question: 'Câu hỏi',
    hint: 'Gợi ý',
    showAnswer: 'Xem đáp án',
    hideAnswer: 'Ẩn đáp án',
    answer: 'Đáp án',
    cycle: 'Vòng {cycle} · còn {remaining} lá',
    resetCycle: 'Bắt đầu lại',
    openCard: 'Mở trang lá bài',
    theme: 'Đổi nền sáng/tối',
    getApp: 'Tải app Android',
    appNote:
      'Bản web tra cứu, bốc bài và kiểm tra. Muốn hỏi đáp và chấm bài bằng AI thì ' +
      'dùng app Android.',
    author: 'Tác giả: Bùi Hải',
    installTitle: 'Cài SuperTarot lên màn hình chính',
    installIos:
      'Bấm nút Chia sẻ ở thanh dưới, rồi chọn Thêm vào MH chính. Mở từ đó ' +
      'sẽ chạy toàn màn hình và xem được cả khi không có mạng.',
    installButton: 'Cài app',
    installDismiss: 'Để sau',
  },
  en: {
    siteTitle: 'SuperTarot',
    tagline: 'Meanings for all 78 tarot cards',
    metaDescription:
      'Full meanings for all 78 tarot cards: upright and reversed, love, ' +
      'career, finances, feelings, actions, symbols and astrology.',
    browse: 'Browse',
    quiz: 'Quiz',
    spread: 'Spread',
    chooseSuit: 'Choose a suit',
    cardCount: 'cards',
    search: 'Search cards',
    searchHint: 'Type a card name, such as The Fool or Ace of Cups',
    noResults: 'No cards matched.',
    columns: 'Columns',
    fewerColumns: 'Fewer columns',
    moreColumns: 'More columns',
    overview: 'Overview',
    upright: 'Upright',
    reversed: 'Reversed',
    cardDescription: 'Card description',
    symbols: 'Symbols',
    keywords: 'Keywords',
    meaning: 'Meaning',
    shortMeaning: 'Concise meaning',
    love: 'Love',
    career: 'Career',
    finances: 'Finances',
    feelings: 'Feelings',
    actions: 'Actions',
    type: 'Type',
    element: 'Element',
    astrology: 'Astrology',
    yesNo: 'Yes/No',
    previous: 'Previous',
    next: 'Next',
    backToSuits: 'All suits',
    quizTitle: 'Quiz',
    quizIntro:
      'Each draw asks about one card and one specific facet. No card repeats ' +
      'until all 78 have come up.',
    quizButton: 'Draw a card',
    quizAgain: 'Draw another',
    spreadTitle: 'Three-card spread',
    spreadIntro:
      'Draw three random cards for past, present and future. Each can land ' +
      'upright or reversed, with the meanings side by side to compare.',
    spreadButton: 'Draw 3 cards',
    spreadAgain: 'Draw again',
    spreadEmpty: 'Press Draw 3 cards to begin.',
    spreadScroll: 'Swipe sideways to see all 3 cards',
    correspondences: 'Correspondences',
    question: 'Question',
    hint: 'Hint',
    showAnswer: 'Show the answer',
    hideAnswer: 'Hide the answer',
    answer: 'Answer',
    cycle: 'Cycle {cycle} · {remaining} left',
    resetCycle: 'Start over',
    openCard: 'Open the card page',
    theme: 'Toggle light and dark',
    getApp: 'Get the Android app',
    appNote:
      'The web version browses, draws spreads and quizzes. For AI Q&A and answer grading, use ' +
      'the Android app.',
    author: 'By Bùi Hải',
    installTitle: 'Install SuperTarot on your home screen',
    installIos:
      'Tap the Share button in the toolbar, then Add to Home Screen. ' +
      'Launched from there it runs full screen and works offline.',
    installButton: 'Install',
    installDismiss: 'Not now',
  },
};

export function t(lang: Lang): Strings {
  return STRINGS[lang];
}

export function cycleLabel(lang: Lang, cycle: number, remaining: number) {
  return STRINGS[lang].cycle
    .replace('{cycle}', String(cycle))
    .replace('{remaining}', String(remaining));
}
