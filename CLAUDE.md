# SuperTarot

## Mục tiêu

Tạo dữ liệu nghĩa 78 lá tarot từ [labyrinthos.co](https://labyrinthos.co/blogs/tarot-card-meanings-list), enrich dữ liệu, build embedding index và chạy Telegram bot học bài/verification.

## Tech Stack

- **Python 3.10+**
- `requests` + `beautifulsoup4` — HTTP fetch & HTML parse
- `lxml` — parser backend nhanh cho BS4
- `openai` — production embeddings
- `anthropic` — translation/cheatsheet enrichment scripts hiện có
- Output: JSON (UTF-8), có thể thêm CSV

## Cấu trúc dự án

```text
supertarot/
├── tarot-meaning-links.json       # Danh sách 78 lá bài với URL
├── README.md                      # Hướng dẫn chạy theo từng module
├── CLAUDE.md
├── AGENTS.md
├── crawler/
│   ├── __init__.py
│   ├── fetch.py                   # HTTP fetcher với rate limiting
│   ├── parser.py                  # BS4 HTML parser
│   ├── models.py                  # Dataclass schema
│   ├── reference.py               # Type/element/astrology/yes-no lookup
│   ├── card_images.py             # Attach local card image refs
│   ├── cheatsheets.py             # Download/cache cheatsheet images
│   └── main.py                    # Entry point
├── enrichment/
│   ├── translate.py               # Dịch EN JSON sang VI JSON bằng Anthropic
│   ├── enrich_cheatsheets.py      # Extract symbols/facet keywords từ cheatsheet
│   ├── enrich_vi.py               # Merge/dịch enrichment sang VI JSON
│   └── download_hoctarot_images.py # Tải ảnh lá bài từ Hoctarot
├── learning/
│   ├── console.py                 # UTF-8 stdout/stderr helper cho Windows CLI
│   ├── deck_order.py              # Thứ tự bộ bài chuẩn (Major 0-21, Ace→King)
│   ├── embeddings.py              # Build/search embedding index
│   ├── study.py                   # Draw không lặp và tạo câu hỏi học bài
│   └── verification.py            # Build GPT grading prompt từ retrieved chunks
├── app/
│   ├── __main__.py                # `python -m app`
│   ├── config.py                  # Env config cho runtime
│   ├── state.py                   # Telegram bot app state
│   ├── telegram_client.py         # Minimal Telegram Bot API client
│   ├── llm.py                     # OpenAI/Anthropic/Google provider adapters
│   ├── grading.py                 # Retrieve + selected-provider grading
│   ├── qa.py                      # Freeform tarot Q&A over embeddings
│   └── telegram_bot.py            # Long-polling bot runtime
├── .github/workflows/             # ci.yml (kiểm tra) và release.yml (release-please + APK)
├── release-please-config.json     # Cấu hình release, extra-files bump mobile/pubspec.yaml
├── .release-please-manifest.json  # Version hiện tại release-please đang giữ
├── version.txt                    # File version của release-type `simple`
├── CONTRIBUTING.md                # Quy ước Conventional Commits và luồng phát hành
├── mobile/                        # Flutter Android app (xem mobile/README.md)
│   ├── tools/prepare_assets.py    # Export data repo sang mobile/assets
│   ├── assets/                    # cards_*.json, index_*.json/.f32, 78 ảnh lá bài
│   ├── lib/src/                   # models, data, services, screens, widgets
│   └── test/                      # parity embedding, deck order, offline assets
├── web/                           # Site tĩnh Astro (xem web/README.md)
│   ├── tools/prepare_web_assets.py # Export data repo sang web/src/data + public
│   ├── src/lib/                   # cards, i18n, icons, study (port của study.py)
│   ├── src/pages/[lang]/          # home, suit, card, draw — prerender toàn bộ
│   └── test/                      # test logic rút bài
├── data/
│   ├── raw/                       # HTML cache (tùy chọn)
│   ├── embeddings/                # Local/prod embedding indexes
│   ├── images/                    # Card images
│   ├── cheatsheets/               # Cheatsheet images
│   └── output/
│       ├── tarot_meanings.json    # Output EN
│       └── tarot_meanings_vi.json # Output VI
└── requirements.txt
```

`crawler/embeddings.py`, `crawler/study.py`, `crawler/verification.py` và các script enrich cũ trong `crawler/` hiện chỉ là compatibility wrappers. Cách chạy mới dùng `learning.*` và `enrichment.*`.

## Schema dữ liệu

```json
{
  "name": "Ace of Swords",
  "url": "https://...",
  "type": "Swords",
  "astrology": "Libra, Gemini, Aquarius",
  "element": "Air",
  "yes_no": "Yes",
  "cheatsheet_image": "data/cheatsheets/ace-of-swords.png",
  "cheatsheet_image_url": "https://...",
  "card_image": "data/images/ace-of-swords.jpg",
  "upright_keywords": ["clarity", "breakthrough", "..."],
  "reversed_keywords": ["confusion", "miscommunication", "..."],
  "description": "The Ace of Swords shows...",
  "upright": {
    "description": "As with all the aces...",
    "love": "You'll find intellectual discussion...",
    "love_keywords": ["clear communication", "..."],
    "career": "Since the aces always...",
    "finances": "You'll need to think very rationally...",
    "feelings": "The Ace of Swords reveals...",
    "actions": "When you draw the upright Ace..."
  },
  "reversed": {
    "description": "Getting a reversed Ace of Swords...",
    "love": "Confusion and clarity...",
    "career": "At work, the reversed Ace...",
    "finances": "Handle your finances with care...",
    "feelings": "The arrival of the reversed Ace...",
    "actions": "When you draw the reversed Ace..."
  },
  "symbols": [
    {"name": "CROWN", "meaning": "..."}
  ]
}
```

## HTML Parsing Strategy

Dựa trên phân tích file `Ace of Swords Meaning - Tarot Card Meanings – Labyrinthos.html`:

| Trường                        | HTML Selector                                      |
| ----------------------------- | -------------------------------------------------- |
| Upright Keywords              | `<table>` đầu tiên trong `.content` → row 2, col 1 |
| Reversed Keywords             | `<table>` đầu tiên → row 2, col 2                  |
| Description                   | `<p>` sau `<h2>` chứa "Tarot Card Description"     |
| Upright description           | `<p>` sau `<h2 id="up">` đến `<table>` tiếp theo   |
| Upright Love                  | `<p>` sau `<h3>` chứa "Love Meaning - Upright"     |
| Upright Career                | `<p>` sau `<h3>` chứa "Career Meaning - Upright"   |
| Upright Finances              | `<p>` sau `<h3>` chứa "Finances Meaning - Upright" |
| Upright Feelings              | `<p>` sau `<h3>` chứa "Upright ... as Feelings"    |
| Upright Actions               | `<p>` sau `<h3>` chứa "Upright ... as Actions"     |
| Reversed description          | `<p>` sau `<h2 id="rev">` đến `<table>` tiếp theo  |
| Reversed Love/Career/Finances | Tương tự upright, thay "Reversed"                  |
| Reversed Feelings             | `<p>` sau `<h3>` chứa "Reversed ... as Feelings"   |
| Reversed Actions              | `<p>` sau `<h3>` chứa "Reversed ... as Actions"    |

## Nguồn dữ liệu metadata

Các trường `Type`, `Element`, `Astrology`, `Yes/No` được lookup trong `crawler/reference.py`.

### File 1: List page

`Tarot Card Meanings List - 78 Cards By Suit, Element, and Zodiac – Labyrinthos.html`

Nhóm cards theo section: `<div id="majorarcana">`, `<div id="wands">`, `<div id="cups">`, `<div id="swords">`, `<div id="pentacles">`.

Type derive trực tiếp từ URL:

```python
def infer_type(url: str) -> str:
    if "major-arcana" in url: return "Major Arcana"
    if "cups" in url:          return "Cups"
    if "wands" in url:         return "Wands"
    if "swords" in url:        return "Swords"
    if "pentacles" in url:     return "Pentacles"
```

### Element lookup

Minor Arcana lấy theo suit. Major Arcana lấy theo `ELEMENT_BY_CARD`; fallback là `None` nếu không có mapping.

```python
ELEMENT_MAP = {
    "Cups": "Water", "Wands": "Fire",
    "Swords": "Air",  "Pentacles": "Earth",
    "Major Arcana": None,  # varies per card, not in file
}
```

### Astrology lookup

**Coverage:**

| Cards | Source |
| ----- | ------ |
| Aces | Zodiac signs theo element |
| Pip cards 2-10 | Planet/sign correspondence |
| Court cards | Zodiac degree ranges hoặc zodiac triplets từ cheatsheet |
| Major Arcana | Planet hoặc zodiac correspondence |

**Yes or No:** lấy từ `YES_NO` trong `crawler/reference.py`.

## Cách chạy

```bash
pip install -r requirements.txt
python -m crawler.main
# Output: data/output/tarot_meanings.json
```

## Chạy ứng dụng Telegram bot

Runtime bot nằm trong `app/` và chạy long polling qua Telegram Bot API.

```bash
export TELEGRAM_BOT_TOKEN="..."
export SUPERTAROT_LANGUAGE=vi
export SUPERTAROT_TIMEZONE=Asia/Saigon
export SUPERTAROT_GRADING_PROVIDER=auto
export SUPERTAROT_QA_PROVIDER=auto
export OPENAI_API_KEY="..."

python -m app --check
python -m app
```

Trên PowerShell dùng `$env:TELEGRAM_BOT_TOKEN="..."` thay cho `export`.

Các lệnh bot hiện có: `/random`, `/daily`, `/learn`, `/ask`, `/menu`, `/schedule HH:MM`, `/unschedule`, `/answer`, `/lang`, `/status`, `/help`.

Thứ tự lá bài: menu `/learn` liệt kê theo thứ tự bộ bài chuẩn (`learning/deck_order.py`), không theo alphabet — Major Arcana 0-21 rồi từng chất Ace→Ten→Page→Knight→Queen→King. `cards_for_suit()` trong `app/learn.py` sort bằng `sort_cards()`; nút chọn bộ xếp Ẩn Chính → Gậy → Cốc → Kiếm → Tiền Vàng.

Telegram UI note: reply keyboard chỉ mở khi `/menu`, `/start`, `/help`, hoặc flow `/learn` cần chọn; `/menu`, `/start`, và `/help` clear `learn_menu` để luôn quay về menu chính. Message thường gửi `remove_keyboard` để không tự xổ menu. `/learn` gửi summary với hai inline button `⬆️ Xuôi`/`⬇️ Ngược`; callback `learn_orientation` gửi chi tiết đúng chiều với `show_menu=False`. Callback `learn_full` cũ vẫn được nhận để tin nhắn cũ không lỗi. Q&A/grading giữ trạng thái `typing` bằng background loop cho tới khi xử lý xong.

Freeform Q&A note: text thường không kèm command là `Freeform Tarot Question` và đi qua `app/qa.py`; `/answer ...` mới là `Study Answer` để chấm bài. Q&A gửi HTML Telegram-safe, đổi Markdown `**`/`*` sang `<b>`/`•`, và không gắn footer Lưu ý/Tham chiếu.

Provider note: `SUPERTAROT_QA_PROVIDER` hỗ trợ `auto`, `openai`, `anthropic`, `google`, `context`; `SUPERTAROT_GRADING_PROVIDER` hỗ trợ `auto`, `openai`, `anthropic`, `google`, `prompt`. `auto` ưu tiên OpenAI, rồi Anthropic, rồi Google theo API key có sẵn.

## Ứng dụng Android (`mobile/`)

App Flutter đóng gói toàn bộ dữ liệu tarot vào APK. Tra cứu, rút bài học và retrieval chạy offline; chỉ diễn giải/chấm bài bằng AI mới cần mạng và API key người dùng tự nhập trong tab Cài đặt.

- API key lưu bằng `flutter_secure_storage` (Android EncryptedSharedPreferences), gọi thẳng OpenAI/Anthropic/Google, không qua máy chủ trung gian.
- Bốn tab: Tra cứu (78 lá theo thứ tự bộ bài, pinch để đổi 1-5 cột), Học bài (rút không lặp + chấm rubric), Hỏi đáp (Q&A trên embedding index), Cài đặt.
- Tab Cài đặt có nút kiểm tra cập nhật: đọc GitHub Releases, so version, tải APK đúng ABI rồi giao cho package installer. Cần `REQUEST_INSTALL_PACKAGES` và APK phải cùng chữ ký với bản đang cài.
- Icon app sinh từ `mobile/icon/app_icon.png` bằng `dart run flutter_launcher_icons`; file sinh ra được commit nên CI không chạy generator.
- UI theo hệ neubrutalism trong `DESIGN.md`: token ở `lib/src/theme.dart` (`NeuTokens`), primitive ở `lib/src/widgets/neu.dart`. Chỉ dùng icon vector, không emoji; 5 biểu tượng bộ bài vẽ tay trong `lib/src/widgets/suit_glyph.dart`.
- Logic port 1-1 từ Python: `deck_order.dart` ← `learning/deck_order.py`, `hash_embedder.dart` ← `HashEmbeddingProvider`, `study_service.dart` ← `learning/study.py`, `grading_service.dart` ← `learning/verification.py` + `app/grading.py`, `qa_service.dart` ← `app/qa.py`.
- `HashEmbedder` phải sinh vector giống hệt Python, nếu không query không cùng không gian với index đã bundle. `test/hash_embedder_test.dart` chốt parity bằng vector tham chiếu.

```bash
python mobile/tools/prepare_assets.py   # sinh lại assets sau mỗi lần đổi dữ liệu
cd mobile && flutter pub get && flutter test
flutter build apk --release --split-per-abi
```

Ký release đọc từ `mobile/android/key.properties` (gitignored); thiếu file thì tự quay về debug key. Chi tiết trong `mobile/README.md` (bản tiếng Việt: `mobile/README.vi.md`).

## Web tĩnh (`web/`)

Site Astro công bố ý nghĩa 78 lá cho trình duyệt, deploy lên GitHub Pages qua `.github/workflows/pages.yml` mỗi lần push `main`.

- **Không có AI.** Hỏi đáp và chấm bài chỉ có ở app Android vì cần API key. Web chỉ tra cứu, tìm kiếm, rút bài.
- Route: `/vi/` và `/en/`, mỗi ngôn ngữ có home, `suit/<key>`, `card/<slug>`, `draw`. Gốc `/` redirect về `/vi/`. Tổng 171 trang prerender.
- `web/tools/prepare_web_assets.py` sinh `web/src/data/cards_*.json`, `web/public/cards/*.jpg` và logo/favicon/og từ `mobile/icon/app_icon.png`. Tất cả gitignore, CI dựng lại. Không cần embedding index vì không có AI.
- `web/src/lib/study.ts` là port của `learning/study.py`, khớp với `study_service.dart`. `web/test/study.test.ts` chốt vòng 78 lá không lặp.
- `site` và `base` lấy từ `actions/configure-pages` lúc build, không hard-code, vì Pages đang chạy qua custom domain.
- PWA: cài được lên màn hình chính (banner `InstallHint.astro`, iOS hướng dẫn Chia sẻ → Thêm vào MH chính). `@vite-pwa/astro` precache toàn bộ trang để offline; ảnh lá bài chỉ cache khi xem, lá chưa xem hiện `card-offline.svg`. Icon PWA nền be đặc sinh bởi `prepare_web_assets.py`.
- UI theo cùng hệ neubrutalism trong `DESIGN.md`, token ở `web/src/styles/global.css`, icon SVG inline ở `web/src/lib/icons.ts`.

```bash
python web/tools/prepare_web_assets.py
cd web && npm install && npm test && npm run build
```

## Phát hành tự động (release-please)

Repo phát hành bằng [release-please](https://github.com/googleapis/release-please); chi tiết quy ước nằm trong `CONTRIBUTING.md`.

- Một version duy nhất cho cả repo, tag `vX.Y.Z`, `CHANGELOG.md` ở root.
- Commit phải theo Conventional Commits. `feat` bump minor, `fix`/`perf`/`data` bump patch, `!` hoặc `BREAKING CHANGE` bump major. `chore`/`docs`/`refactor`/`test`/`ci` không bump.
- Merge vào `main` → release-please mở PR `chore(main): release X.Y.Z` đã bump `version.txt` và `mobile/pubspec.yaml`. Merge PR đó → tạo tag, GitHub Release, rồi job `apk` build và đính 3 file `supertarot-X.Y.Z-<abi>.apk`.
- `mobile/pubspec.yaml` giữ dòng `version: X.Y.Z # x-release-please-version`; không sửa tay.
- `versionCode` suy ra từ semver trong `mobile/android/app/build.gradle.kts`: `(major×10000 + minor×100 + patch) × 10000`. Bốn chữ số cuối để trống vì `--split-per-abi` khiến Flutter cộng `abiCode × 1000`.
- CI sinh lại `data/embeddings/` và `mobile/assets/` từ `data/output/` + `data/images/` bằng provider `hash` — không cần dependency Python hay API key, và index không bao giờ lệch với JSON nguồn.
- Ký APK cần 4 secret: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`. Thiếu `ANDROID_KEYSTORE_BASE64` thì job fail có chủ đích.

## Rate Limiting

- Delay 1–2s giữa mỗi request để tránh bị block
- User-Agent hợp lệ
- Tổng: 78 lá × ~1.5s ≈ ~2 phút

## Kiểm tra kết quả

```bash
python -c "import json; data=json.load(open('data/output/tarot_meanings.json')); print(len(data), 'cards')"
```

## Documentation Maintenance Rules

- Mỗi lần thay đổi repo phải cập nhật `MEMORY.md` với ngày, phạm vi thay đổi và lệnh kiểm tra đã chạy.
- Nếu thay đổi cấu trúc module, pipeline, schema, hoặc thêm/bớt logic runtime thì phải cập nhật cả `CLAUDE.md` và `AGENTS.md`.
- `MEMORY.md` là nhật ký ngắn hạn để biết lần gần nhất đã làm gì; `CLAUDE.md` và `AGENTS.md` là tài liệu định hướng kiến trúc phải luôn khớp với code.

## Embedding & Tarot Learning Bot

Repo dùng dữ liệu tarot để hỗ trợ bot học bài qua Telegram:

- `/random`: rút một lá thủ công.
- `/daily`: rút một câu hỏi daily ngay.
- `/schedule HH:MM`: gửi một lá mỗi ngày vào giờ người dùng chọn.
- `/answer ...`: chấm câu trả lời cho câu hỏi đang mở.
- Mỗi user có vòng 78 lá riêng; không lặp lá trong cùng một vòng. Khi hết 78 lá, bắt đầu vòng mới.
- Mỗi lần hỏi chỉ nên hỏi một facet cụ thể để dễ chấm: tổng quan, xuôi/ngược, tình yêu, sự nghiệp, tài chính, cảm xúc, hành động, biểu tượng, hoặc correspondence.
- Mỗi draw kèm một hint ngắn theo facet; Telegram format không lặp dòng `Lá bài` ở đầu vì câu hỏi đã chứa tên lá bài.
- Khi verify câu trả lời, bot retrieve reference chunks từ embedding index rồi đưa cùng câu trả lời vào GPT để chấm theo rubric JSON.

Các module nền tảng:

```text
learning/embeddings.py    # build/search embedding index cho EN và VI JSON
learning/study.py         # draw card không lặp, chọn facet, tạo câu hỏi
learning/verification.py  # retrieve chunks và build prompt chấm điểm cho GPT
```

Production embedding dùng OpenAI `text-embedding-3-small`. Offline smoke test dùng provider `hash` deterministic, không thay thế semantic embedding thật.

```bash
# Smoke test local, không cần API key
python -m learning.embeddings build --provider hash --lang all
python -m learning.embeddings search --lang vi --query "tình yêu mới và cảm xúc mở lòng"

# Production index
python -m learning.embeddings build --provider openai --lang all

# Draw một câu hỏi học bài, không lặp trong vòng 78 lá/user
python -m learning.study draw --user-id local --lang vi --mode random
```
