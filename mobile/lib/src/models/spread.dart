/// One slot in a spread: what the card laid there speaks to.
class SpreadPosition {
  const SpreadPosition(this.vi, this.en, {this.hintVi = '', this.hintEn = ''});

  final String vi;
  final String en;
  final String hintVi;
  final String hintEn;

  String label(String language) => language == 'vi' ? vi : en;

  String hint(String language) => language == 'vi' ? hintVi : hintEn;
}

/// A tarot layout. The free layout has no positions and reads the cards as
/// an ordered flow; every other layout gives each card a fixed meaning.
class SpreadDefinition {
  const SpreadDefinition({
    required this.id,
    required this.nameVi,
    required this.nameEn,
    required this.descriptionVi,
    required this.descriptionEn,
    this.positions = const <SpreadPosition>[],
  });

  /// Stored in reading history, so never rename an existing id.
  final String id;
  final String nameVi;
  final String nameEn;
  final String descriptionVi;
  final String descriptionEn;
  final List<SpreadPosition> positions;

  bool get isFree => positions.isEmpty;

  int get maxCards => isFree ? freeSpreadMaxCards : positions.length;

  String name(String language) => language == 'vi' ? nameVi : nameEn;

  String description(String language) =>
      language == 'vi' ? descriptionVi : descriptionEn;

  SpreadPosition? positionAt(int index) =>
      index >= 0 && index < positions.length ? positions[index] : null;
}

/// Upper bound for the free layout; a Celtic Cross plus a couple of
/// clarifiers.
const int freeSpreadMaxCards = 12;

SpreadDefinition spreadById(String? id) => tarotSpreads.firstWhere(
      (SpreadDefinition spread) => spread.id == id,
      orElse: () => tarotSpreads.first,
    );

const List<SpreadDefinition> tarotSpreads = <SpreadDefinition>[
  SpreadDefinition(
    id: 'free',
    nameVi: 'Tự do',
    nameEn: 'Free',
    descriptionVi: 'Không cố định vị trí. Rút bao nhiêu lá tùy bạn (tối đa '
        '12), AI đọc theo thứ tự như một dòng chảy và gắn với câu hỏi.',
    descriptionEn: 'No fixed positions. Draw as many cards as you like (up to '
        '12) and the AI reads them in order as one flow.',
  ),
  SpreadDefinition(
    id: 'one_card',
    nameVi: 'Thông điệp',
    nameEn: 'Message',
    descriptionVi: 'Một lá cho chủ đề trong ngày hoặc câu trả lời nhanh cho '
        'một câu hỏi rõ ràng.',
    descriptionEn: 'One card for the theme of the day or a quick answer to a '
        'clear question.',
    positions: <SpreadPosition>[SpreadPosition('Thông điệp', 'Message')],
  ),
  SpreadDefinition(
    id: 'two_choices',
    nameVi: 'Hai lựa chọn',
    nameEn: 'Two choices',
    descriptionVi: 'Đặt hai hướng đi cạnh nhau: mỗi lá cho thấy năng lượng '
        'và hệ quả của một lựa chọn.',
    descriptionEn: 'Two paths side by side: each card shows the energy and '
        'consequence of one option.',
    positions: <SpreadPosition>[
      SpreadPosition('Lựa chọn A', 'Option A'),
      SpreadPosition('Lựa chọn B', 'Option B'),
    ],
  ),
  SpreadDefinition(
    id: 'situation_advice',
    nameVi: 'Tình huống - Lời khuyên',
    nameEn: 'Situation - Advice',
    descriptionVi: 'Lá đầu nói chuyện gì đang diễn ra, lá sau nói bạn nên '
        'làm gì với nó.',
    descriptionEn: 'The first card shows what is going on, the second what to '
        'do about it.',
    positions: <SpreadPosition>[
      SpreadPosition('Tình huống', 'Situation'),
      SpreadPosition('Lời khuyên', 'Advice'),
    ],
  ),
  SpreadDefinition(
    id: 'past_present_future',
    nameVi: 'Quá khứ - Hiện tại - Tương lai',
    nameEn: 'Past - Present - Future',
    descriptionVi: 'Kiểu ba lá kinh điển: điều đã dẫn tới đây, tình hình lúc '
        'này và hướng sự việc đang đi nếu giữ nguyên.',
    descriptionEn: 'The classic three-card read: what led here, where things '
        'stand, and where they are heading if nothing changes.',
    positions: <SpreadPosition>[
      SpreadPosition('Quá khứ', 'Past'),
      SpreadPosition('Hiện tại', 'Present'),
      SpreadPosition('Tương lai', 'Future'),
    ],
  ),
  SpreadDefinition(
    id: 'situation_obstacle_advice',
    nameVi: 'Tình huống - Trở ngại - Lời khuyên',
    nameEn: 'Situation - Obstacle - Advice',
    descriptionVi: 'Ba lá để gỡ một vấn đề: bối cảnh, điều đang cản bạn và '
        'cách vượt qua.',
    descriptionEn: 'Three cards to untangle a problem: the context, what is in '
        'the way, and how to get past it.',
    positions: <SpreadPosition>[
      SpreadPosition('Tình huống', 'Situation'),
      SpreadPosition('Trở ngại', 'Obstacle'),
      SpreadPosition('Lời khuyên', 'Advice'),
    ],
  ),
  SpreadDefinition(
    id: 'you_them_relationship',
    nameVi: 'Bạn - Người kia - Mối quan hệ',
    nameEn: 'You - Them - Relationship',
    descriptionVi: 'Nhìn một mối quan hệ từ hai phía và phần kết nối giữa '
        'hai người.',
    descriptionEn: 'A relationship seen from both sides plus the bond between '
        'you.',
    positions: <SpreadPosition>[
      SpreadPosition('Bạn', 'You'),
      SpreadPosition('Người kia', 'Them'),
      SpreadPosition('Mối quan hệ', 'Relationship'),
    ],
  ),
  SpreadDefinition(
    id: 'mind_body_spirit',
    nameVi: 'Tâm trí - Cơ thể - Tinh thần',
    nameEn: 'Mind - Body - Spirit',
    descriptionVi: 'Kiểm tra trạng thái của bạn trên ba tầng: suy nghĩ, thể '
        'chất và đời sống tinh thần.',
    descriptionEn: 'A check-in on three levels: thoughts, physical state and '
        'inner life.',
    positions: <SpreadPosition>[
      SpreadPosition('Tâm trí', 'Mind'),
      SpreadPosition('Cơ thể', 'Body'),
      SpreadPosition('Tinh thần', 'Spirit'),
    ],
  ),
  SpreadDefinition(
    id: 'strength_weakness_advice',
    nameVi: 'Điểm mạnh - Điểm yếu - Lời khuyên',
    nameEn: 'Strength - Weakness - Advice',
    descriptionVi: 'Điều bạn có thể dựa vào, điều đang kéo bạn lại và cách '
        'cân bằng hai bên.',
    descriptionEn: 'What you can lean on, what holds you back, and how to '
        'balance the two.',
    positions: <SpreadPosition>[
      SpreadPosition('Điểm mạnh', 'Strength'),
      SpreadPosition('Điểm yếu', 'Weakness'),
      SpreadPosition('Lời khuyên', 'Advice'),
    ],
  ),
  SpreadDefinition(
    id: 'do_dont_outcome',
    nameVi: 'Nên làm - Không nên làm - Kết quả',
    nameEn: 'Do - Avoid - Outcome',
    descriptionVi: 'Hướng dẫn hành động cụ thể: việc nên làm, việc cần tránh '
        'và kết quả nếu làm theo.',
    descriptionEn: 'Practical guidance: what to do, what to avoid, and the '
        'likely result if you follow it.',
    positions: <SpreadPosition>[
      SpreadPosition('Nên làm', 'Do'),
      SpreadPosition('Không nên làm', 'Avoid'),
      SpreadPosition('Kết quả', 'Outcome'),
    ],
  ),
  SpreadDefinition(
    id: 'shadow_work',
    nameVi: 'Shadow work',
    nameEn: 'Shadow work',
    descriptionVi: 'Ba lá để nhìn vào phần bạn hay né: nó là gì, đến từ đâu '
        'và làm sao đối diện.',
    descriptionEn: 'Three cards for the part of you that you avoid: what it '
        'is, where it comes from, and how to face it.',
    positions: <SpreadPosition>[
      SpreadPosition('Điều bạn né tránh', 'What you avoid'),
      SpreadPosition('Nguồn gốc', 'Its root'),
      SpreadPosition('Cách đối diện', 'How to face it'),
    ],
  ),
  SpreadDefinition(
    id: 'new_moon',
    nameVi: 'Trăng non - Đặt ý định',
    nameEn: 'New moon - Intentions',
    descriptionVi: 'Dùng đầu chu kỳ trăng để gieo ý định mới cho tháng tới.',
    descriptionEn: 'For the start of the lunar cycle: set intentions for the '
        'month ahead.',
    positions: <SpreadPosition>[
      SpreadPosition('Năng lượng hiện tại', 'Current energy'),
      SpreadPosition('Ý định nên gieo', 'Intention to set'),
      SpreadPosition('Hành động cần làm', 'Action to take'),
      SpreadPosition('Điều cần lưu ý', 'What to watch'),
    ],
  ),
  SpreadDefinition(
    id: 'full_moon',
    nameVi: 'Trăng tròn - Buông bỏ',
    nameEn: 'Full moon - Release',
    descriptionVi: 'Dùng lúc trăng tròn để nhìn lại thành quả và buông điều '
        'không còn phục vụ bạn.',
    descriptionEn: 'For the full moon: review what has come to fruition and '
        'let go of what no longer serves you.',
    positions: <SpreadPosition>[
      SpreadPosition('Điều đã thành hình', 'What has manifested'),
      SpreadPosition('Điều cần buông bỏ', 'What to release'),
      SpreadPosition('Bài học', 'The lesson'),
      SpreadPosition('Hướng đi tiếp', 'Next step'),
    ],
  ),
  SpreadDefinition(
    id: 'cross_5',
    nameVi: 'Chữ thập',
    nameEn: 'Cross',
    descriptionVi: 'Hiện tại ở giữa, quá khứ bên trái, tương lai bên phải, '
        'nguyên nhân bên dưới, tiềm năng bên trên.',
    descriptionEn: 'Present in the middle, past to the left, future to the '
        'right, root below, potential above.',
    positions: <SpreadPosition>[
      SpreadPosition('Hiện tại', 'Present'),
      SpreadPosition('Quá khứ', 'Past'),
      SpreadPosition('Tương lai', 'Future'),
      SpreadPosition('Nguyên nhân', 'Root cause'),
      SpreadPosition('Tiềm năng', 'Potential'),
    ],
  ),
  SpreadDefinition(
    id: 'decision_5',
    nameVi: 'Ra quyết định',
    nameEn: 'Decision',
    descriptionVi: 'So sánh hai lựa chọn kỹ hơn: mỗi hướng có một lá cho bản '
        'chất và một lá cho kết quả.',
    descriptionEn: 'A closer look at two options: each has one card for what '
        'it is and one for where it leads.',
    positions: <SpreadPosition>[
      SpreadPosition('Tình huống', 'Situation'),
      SpreadPosition('Lựa chọn A', 'Option A'),
      SpreadPosition('Kết quả A', 'Outcome A'),
      SpreadPosition('Lựa chọn B', 'Option B'),
      SpreadPosition('Kết quả B', 'Outcome B'),
    ],
  ),
  SpreadDefinition(
    id: 'career_6',
    nameVi: 'Sự nghiệp',
    nameEn: 'Career',
    descriptionVi: 'Nhìn tổng thể công việc: bạn đang ở đâu, có gì trong tay, '
        'vướng gì, cơ hội nào và nên đi tiếp ra sao.',
    descriptionEn: 'A full look at your work: where you stand, what you bring, '
        'what blocks you, the opening, and the way forward.',
    positions: <SpreadPosition>[
      SpreadPosition('Vị trí hiện tại', 'Where you stand'),
      SpreadPosition('Điểm mạnh', 'Strengths'),
      SpreadPosition('Trở ngại', 'Obstacle'),
      SpreadPosition('Cơ hội', 'Opportunity'),
      SpreadPosition('Lời khuyên', 'Advice'),
      SpreadPosition('Kết quả', 'Outcome'),
    ],
  ),
  SpreadDefinition(
    id: 'relationship_7',
    nameVi: 'Mối quan hệ chi tiết',
    nameEn: 'Relationship in depth',
    descriptionVi: 'Đào sâu một mối quan hệ: mỗi người muốn gì, điều gắn kết, '
        'điều thử thách và hướng đi chung.',
    descriptionEn: 'A deeper relationship read: what each person wants, what '
        'binds you, what tests you, and where it is going.',
    positions: <SpreadPosition>[
      SpreadPosition('Bạn', 'You'),
      SpreadPosition('Người kia', 'Them'),
      SpreadPosition('Điều bạn muốn', 'What you want'),
      SpreadPosition('Điều họ muốn', 'What they want'),
      SpreadPosition('Điểm mạnh', 'Strength'),
      SpreadPosition('Thử thách', 'Challenge'),
      SpreadPosition('Hướng đi', 'Direction'),
    ],
  ),
  SpreadDefinition(
    id: 'horseshoe',
    nameVi: 'Móng ngựa',
    nameEn: 'Horseshoe',
    descriptionVi: 'Bảy lá xếp hình chữ U, đi từ quá khứ qua các ảnh hưởng '
        'tới kết quả. Hợp với câu hỏi có nhiều yếu tố.',
    descriptionEn: 'Seven cards in a U shape, from the past through the '
        'influences to the outcome. Good for many-sided questions.',
    positions: <SpreadPosition>[
      SpreadPosition('Quá khứ', 'Past'),
      SpreadPosition('Hiện tại', 'Present'),
      SpreadPosition(
        'Ảnh hưởng ẩn',
        'Hidden influences',
        hintVi: 'điều bạn chưa thấy rõ',
        hintEn: 'what you are not seeing',
      ),
      SpreadPosition('Trở ngại', 'Obstacle'),
      SpreadPosition(
        'Người xung quanh',
        'Others',
        hintVi: 'thái độ và tác động từ người khác',
        hintEn: 'how people around you act on this',
      ),
      SpreadPosition('Lời khuyên', 'Advice'),
      SpreadPosition('Kết quả', 'Outcome'),
    ],
  ),
  SpreadDefinition(
    id: 'celtic_cross',
    nameVi: 'Celtic Cross',
    nameEn: 'Celtic Cross',
    descriptionVi: 'Kiểu trải kinh điển nhất. Sáu lá đầu tạo hình chữ thập '
        '(lá 2 đặt ngang đè lên lá 1), bốn lá sau xếp thành cột bên phải.',
    descriptionEn: 'The best-known spread. The first six cards form a cross '
        '(card 2 lies across card 1), the last four stand in a column on the '
        'right.',
    positions: <SpreadPosition>[
      SpreadPosition(
        'Hiện tại',
        'Present',
        hintVi: 'trọng tâm của vấn đề',
        hintEn: 'the heart of the matter',
      ),
      SpreadPosition(
        'Thử thách',
        'Challenge',
        hintVi: 'điều cắt ngang hoặc cản trở',
        hintEn: 'what crosses or blocks it',
      ),
      SpreadPosition(
        'Gốc rễ',
        'Foundation',
        hintVi: 'nguyên nhân sâu, tiềm thức',
        hintEn: 'the deep cause, the subconscious',
      ),
      SpreadPosition(
        'Quá khứ gần',
        'Recent past',
        hintVi: 'điều vừa đi qua',
        hintEn: 'what is just behind you',
      ),
      SpreadPosition(
        'Mục tiêu',
        'Goal',
        hintVi: 'điều bạn ý thức hướng tới',
        hintEn: 'what you consciously aim for',
      ),
      SpreadPosition(
        'Tương lai gần',
        'Near future',
        hintVi: 'điều sắp tới',
        hintEn: 'what is coming next',
      ),
      SpreadPosition(
        'Bản thân',
        'Self',
        hintVi: 'thái độ của bạn',
        hintEn: 'your own stance',
      ),
      SpreadPosition(
        'Môi trường',
        'Environment',
        hintVi: 'người và hoàn cảnh xung quanh',
        hintEn: 'people and circumstances around you',
      ),
      SpreadPosition(
        'Hy vọng và nỗi sợ',
        'Hopes and fears',
        hintVi: 'điều bạn mong và điều bạn lo',
        hintEn: 'what you hope for and dread',
      ),
      SpreadPosition(
        'Kết quả',
        'Outcome',
        hintVi: 'hướng kết thúc nếu giữ nguyên',
        hintEn: 'where it ends if nothing changes',
      ),
    ],
  ),
  SpreadDefinition(
    id: 'astrology_12',
    nameVi: 'Chiêm tinh 12 nhà',
    nameEn: 'Astrological 12 houses',
    descriptionVi: 'Mỗi lá rơi vào một nhà trong lá số, cho cái nhìn toàn '
        'cảnh mọi mặt đời sống.',
    descriptionEn: 'Each card falls in one house of the chart, for a full view '
        'across every area of life.',
    positions: <SpreadPosition>[
      SpreadPosition('Nhà 1 - Bản thân', 'House 1 - Self'),
      SpreadPosition('Nhà 2 - Tiền bạc, giá trị', 'House 2 - Money, values'),
      SpreadPosition(
        'Nhà 3 - Giao tiếp, học tập',
        'House 3 - Communication, learning',
      ),
      SpreadPosition('Nhà 4 - Gia đình, gốc rễ', 'House 4 - Home, roots'),
      SpreadPosition(
        'Nhà 5 - Tình yêu, sáng tạo',
        'House 5 - Romance, creativity',
      ),
      SpreadPosition(
        'Nhà 6 - Công việc hằng ngày, sức khỏe',
        'House 6 - Daily work, health',
      ),
      SpreadPosition('Nhà 7 - Quan hệ đối tác', 'House 7 - Partnerships'),
      SpreadPosition(
        'Nhà 8 - Chuyển hóa, tài sản chung',
        'House 8 - Transformation, shared resources',
      ),
      SpreadPosition(
        'Nhà 9 - Niềm tin, đi xa',
        'House 9 - Beliefs, travel',
      ),
      SpreadPosition(
        'Nhà 10 - Sự nghiệp, danh tiếng',
        'House 10 - Career, reputation',
      ),
      SpreadPosition(
        'Nhà 11 - Bạn bè, cộng đồng',
        'House 11 - Friends, community',
      ),
      SpreadPosition('Nhà 12 - Tiềm thức', 'House 12 - The subconscious'),
    ],
  ),
  SpreadDefinition(
    id: 'year_ahead',
    nameVi: 'Vòng năm',
    nameEn: 'Year ahead',
    descriptionVi: 'Mười hai lá cho mười hai tháng tới, tính từ tháng này, '
        'và lá thứ 13 là chủ đề chung của cả năm.',
    descriptionEn: 'Twelve cards for the next twelve months starting with this '
        'one, and a thirteenth for the theme of the whole year.',
    positions: <SpreadPosition>[
      SpreadPosition('Tháng thứ 1', 'Month 1'),
      SpreadPosition('Tháng thứ 2', 'Month 2'),
      SpreadPosition('Tháng thứ 3', 'Month 3'),
      SpreadPosition('Tháng thứ 4', 'Month 4'),
      SpreadPosition('Tháng thứ 5', 'Month 5'),
      SpreadPosition('Tháng thứ 6', 'Month 6'),
      SpreadPosition('Tháng thứ 7', 'Month 7'),
      SpreadPosition('Tháng thứ 8', 'Month 8'),
      SpreadPosition('Tháng thứ 9', 'Month 9'),
      SpreadPosition('Tháng thứ 10', 'Month 10'),
      SpreadPosition('Tháng thứ 11', 'Month 11'),
      SpreadPosition('Tháng thứ 12', 'Month 12'),
      SpreadPosition('Chủ đề cả năm', 'Theme of the year'),
    ],
  ),
];
