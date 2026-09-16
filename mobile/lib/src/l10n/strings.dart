/// UI copy for the two supported languages.
///
/// The bundled tarot data already exists per language; this only covers chrome
/// such as tab names, field labels and buttons.
class Strings {
  const Strings({
    required this.languageCode,
    required this.appTitle,
    required this.tabBrowse,
    required this.tabStudy,
    required this.tabAsk,
    required this.tabSettings,
    required this.chooseSuit,
    required this.cardCount,
    required this.searchCards,
    required this.noCardsFound,
    required this.overview,
    required this.upright,
    required this.reversed,
    required this.cardDescription,
    required this.symbols,
    required this.keywords,
    required this.meaning,
    required this.shortMeaning,
    required this.love,
    required this.career,
    required this.finances,
    required this.feelings,
    required this.actions,
    required this.type,
    required this.element,
    required this.astrology,
    required this.yesNo,
    required this.drawNew,
    required this.drawAnother,
    required this.studyIntro,
    required this.question,
    required this.hint,
    required this.yourAnswer,
    required this.answerPlaceholder,
    required this.gradeAnswer,
    required this.grading,
    required this.cycleProgress,
    required this.score,
    required this.passed,
    required this.notPassed,
    required this.correctPoints,
    required this.missingPoints,
    required this.incorrectPoints,
    required this.feedback,
    required this.nextHint,
    required this.referenceChunks,
    required this.emptyAnswerWarning,
    required this.askPlaceholder,
    required this.askIntro,
    required this.send,
    required this.thinking,
    required this.sources,
    required this.language,
    required this.qaProvider,
    required this.gradingProvider,
    required this.apiKeys,
    required this.apiKeyHint,
    required this.model,
    required this.apiKeyLabel,
    required this.save,
    required this.keySaved,
    required this.keyCleared,
    required this.retrievalDepth,
    required this.qaTopK,
    required this.answerTopK,
    required this.noProviderWarning,
    required this.about,
    required this.aboutBody,
    required this.offlineBadge,
    required this.updates,
    required this.currentVersion,
    required this.checkForUpdates,
    required this.checking,
    required this.upToDate,
    required this.updateAvailable,
    required this.downloadAndInstall,
    required this.downloading,
    required this.releaseNotes,
    required this.updateNoAsset,
    required this.installHint,
  });

  final String languageCode;
  final String appTitle;
  final String tabBrowse;
  final String tabStudy;
  final String tabAsk;
  final String tabSettings;
  final String chooseSuit;
  final String cardCount;
  final String searchCards;
  final String noCardsFound;
  final String overview;
  final String upright;
  final String reversed;
  final String cardDescription;
  final String symbols;
  final String keywords;
  final String meaning;
  final String shortMeaning;
  final String love;
  final String career;
  final String finances;
  final String feelings;
  final String actions;
  final String type;
  final String element;
  final String astrology;
  final String yesNo;
  final String drawNew;
  final String drawAnother;
  final String studyIntro;
  final String question;
  final String hint;
  final String yourAnswer;
  final String answerPlaceholder;
  final String gradeAnswer;
  final String grading;
  final String cycleProgress;
  final String score;
  final String passed;
  final String notPassed;
  final String correctPoints;
  final String missingPoints;
  final String incorrectPoints;
  final String feedback;
  final String nextHint;
  final String referenceChunks;
  final String emptyAnswerWarning;
  final String askPlaceholder;
  final String askIntro;
  final String send;
  final String thinking;
  final String sources;
  final String language;
  final String qaProvider;
  final String gradingProvider;
  final String apiKeys;
  final String apiKeyHint;
  final String model;
  final String apiKeyLabel;
  final String save;
  final String keySaved;
  final String keyCleared;
  final String retrievalDepth;
  final String qaTopK;
  final String answerTopK;
  final String noProviderWarning;
  final String about;
  final String aboutBody;
  final String offlineBadge;
  final String updates;
  final String currentVersion;
  final String checkForUpdates;
  final String checking;
  final String upToDate;
  final String updateAvailable;
  final String downloadAndInstall;
  final String downloading;
  final String releaseNotes;
  final String updateNoAsset;
  final String installHint;

  static const Strings vi = Strings(
    languageCode: 'vi',
    appTitle: 'SuperTarot',
    tabBrowse: 'Tra cứu',
    tabStudy: 'Học bài',
    tabAsk: 'Hỏi đáp',
    tabSettings: 'Cài đặt',
    chooseSuit: 'Chọn bộ bài',
    cardCount: 'lá',
    searchCards: 'Tìm lá bài',
    noCardsFound: 'Không tìm thấy lá bài nào.',
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
    drawNew: 'Rút lá học bài',
    drawAnother: 'Rút lá khác',
    studyIntro: 'Mỗi lần rút một lá và một khía cạnh cụ thể. Không lặp lá nào '
        'cho tới khi đi hết 78 lá.',
    question: 'Câu hỏi',
    hint: 'Gợi ý',
    yourAnswer: 'Câu trả lời của bạn',
    answerPlaceholder: 'Viết những gì bạn nhớ về lá bài này…',
    gradeAnswer: 'Chấm bài',
    grading: 'Đang chấm…',
    cycleProgress: 'Vòng {cycle} · còn {remaining} lá',
    score: 'Điểm',
    passed: 'Đạt',
    notPassed: 'Chưa đạt',
    correctPoints: 'Ý đúng',
    missingPoints: 'Ý còn thiếu',
    incorrectPoints: 'Ý sai hoặc lệch',
    feedback: 'Nhận xét',
    nextHint: 'Gợi ý tiếp',
    referenceChunks: 'Tài liệu tham chiếu',
    emptyAnswerWarning: 'Bạn chưa viết câu trả lời nào.',
    askPlaceholder: 'Hỏi về tarot…',
    askIntro: 'Hỏi bất cứ điều gì về 78 lá bài. App tìm dữ liệu ngay trên máy '
        'rồi nhờ AI diễn giải.',
    send: 'Gửi',
    thinking: 'Đang xử lý…',
    sources: 'Dữ liệu đã dùng',
    language: 'Ngôn ngữ',
    qaProvider: 'AI cho hỏi đáp',
    gradingProvider: 'AI cho chấm bài',
    apiKeys: 'API key',
    apiKeyHint: 'Key được mã hóa và chỉ lưu trên máy bạn. App gửi thẳng tới '
        'nhà cung cấp bạn chọn, không qua máy chủ trung gian.',
    model: 'Model',
    apiKeyLabel: 'API key',
    save: 'Lưu',
    keySaved: 'Đã lưu key',
    keyCleared: 'Đã xóa key',
    retrievalDepth: 'Số đoạn tham chiếu',
    qaTopK: 'Hỏi đáp',
    answerTopK: 'Chấm bài',
    noProviderWarning: 'Chưa có API key nào. Tra cứu và rút bài vẫn chạy '
        'offline, nhưng hỏi đáp và chấm bài cần key.',
    about: 'Giới thiệu',
    aboutBody: 'Dữ liệu 78 lá bài, ảnh và embedding index đều nằm trong app. '
        'Chỉ phần diễn giải bằng AI mới cần mạng.',
    offlineBadge: 'Offline',
    updates: 'Cập nhật',
    currentVersion: 'Phiên bản hiện tại',
    checkForUpdates: 'Kiểm tra cập nhật',
    checking: 'Đang kiểm tra…',
    upToDate: 'Bạn đang dùng bản mới nhất.',
    updateAvailable: 'Có bản mới {version}',
    downloadAndInstall: 'Tải và cài',
    downloading: 'Đang tải…',
    releaseNotes: 'Có gì mới',
    updateNoAsset: 'Bản mới chưa có APK phù hợp với máy này. Mở trang Releases để tải thủ công.',
    installHint: 'Android sẽ hỏi quyền cài app từ nguồn này trước khi cài.',
  );

  static const Strings en = Strings(
    languageCode: 'en',
    appTitle: 'SuperTarot',
    tabBrowse: 'Browse',
    tabStudy: 'Study',
    tabAsk: 'Ask',
    tabSettings: 'Settings',
    chooseSuit: 'Choose a suit',
    cardCount: 'cards',
    searchCards: 'Search cards',
    noCardsFound: 'No cards matched.',
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
    drawNew: 'Draw a study card',
    drawAnother: 'Draw another',
    studyIntro: 'Each draw asks about one card and one specific facet. No card '
        'repeats until all 78 have come up.',
    question: 'Question',
    hint: 'Hint',
    yourAnswer: 'Your answer',
    answerPlaceholder: 'Write what you remember about this card…',
    gradeAnswer: 'Grade my answer',
    grading: 'Grading…',
    cycleProgress: 'Cycle {cycle} · {remaining} left',
    score: 'Score',
    passed: 'Passed',
    notPassed: 'Not passed',
    correctPoints: 'Correct points',
    missingPoints: 'Missing points',
    incorrectPoints: 'Incorrect points',
    feedback: 'Feedback',
    nextHint: 'Next hint',
    referenceChunks: 'Reference material',
    emptyAnswerWarning: 'Write an answer first.',
    askPlaceholder: 'Ask about tarot…',
    askIntro: 'Ask anything about the 78 cards. The app searches its bundled '
        'data on device, then asks AI to explain.',
    send: 'Send',
    thinking: 'Working…',
    sources: 'Data used',
    language: 'Language',
    qaProvider: 'AI for Q&A',
    gradingProvider: 'AI for grading',
    apiKeys: 'API keys',
    apiKeyHint: 'Keys are encrypted and stay on this device. The app calls the '
        'provider you pick directly, with no server in between.',
    model: 'Model',
    apiKeyLabel: 'API key',
    save: 'Save',
    keySaved: 'Key saved',
    keyCleared: 'Key cleared',
    retrievalDepth: 'Reference chunks',
    qaTopK: 'Q&A',
    answerTopK: 'Grading',
    noProviderWarning: 'No API key yet. Browsing and drawing work offline, but '
        'Q&A and grading need a key.',
    about: 'About',
    aboutBody: 'All 78 card meanings, art and the embedding index ship inside '
        'the app. Only AI synthesis needs the network.',
    offlineBadge: 'Offline',
    updates: 'Updates',
    currentVersion: 'Installed version',
    checkForUpdates: 'Check for updates',
    checking: 'Checking…',
    upToDate: 'You are on the latest version.',
    updateAvailable: 'Version {version} is available',
    downloadAndInstall: 'Download and install',
    downloading: 'Downloading…',
    releaseNotes: "What's new",
    updateNoAsset: 'This release has no APK for your device. Open the Releases page to download manually.',
    installHint: 'Android will ask you to allow installs from this app first.',
  );

  static Strings of(String languageCode) =>
      languageCode == 'en' ? Strings.en : Strings.vi;

  String versionAvailable(String version) =>
      updateAvailable.replaceAll('{version}', version);

  String cycle(int cycleNumber, int remaining) => cycleProgress
      .replaceAll('{cycle}', '$cycleNumber')
      .replaceAll('{remaining}', '$remaining');
}
