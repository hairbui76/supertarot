# Agents Design — SuperTarot

## Tổng quan kiến trúc

Hệ thống crawl nằm trong package `crawler` và được chia thành 3 agent/module độc lập:

```text
[Fetcher Agent] → [Parser Agent] → [Writer Agent]
```

Các script enrich/dịch nằm trong package `enrichment`:

```text
[Meaning JSON] → [Cheatsheet/Image Enrichment] → [VI Translation/Enrichment]
```

Hệ thống học bài nằm trong package `learning`, dùng output JSON của crawler/enrichment và chạy theo pipeline riêng:

```text
[Meaning JSON] → [Embedding Agent] → [Study Agent] → [Verification Agent] → [Telegram Bot]
```

Runtime ứng dụng nằm trong package `app`:

```text
[Telegram Long Polling] → [Command/Menu Router] → [Study Draw | Tarot Q&A | Answer Verification] → [Telegram Reply]
```

Ứng dụng Android nằm trong `mobile/`, dùng chung dữ liệu nhưng chạy độc lập với bot:

```text
[Meaning JSON + Embedding Index] → [prepare_assets.py] → [Flutter assets] → [Browse | Study | Ask]
```

Các module cũ dưới `crawler` như `crawler.embeddings`, `crawler.study`, `crawler.verification`, `crawler.translate`, `crawler.enrich_*` hiện chỉ là compatibility wrappers để lệnh cũ không gãy. Code chính nằm trong `learning/` và `enrichment/`.
`learning/console.py` là helper chung để các CLI in tiếng Việt bằng UTF-8 ổn định trên Windows.

---

## Quy tắc cập nhật tài liệu

- Mỗi lần thay đổi repo phải cập nhật `MEMORY.md`.
- Nếu thay đổi cấu trúc hoặc thêm/bớt logic thì cập nhật cả `CLAUDE.md` và `AGENTS.md`.
- `AGENTS.md` phải mô tả module/agent đang tồn tại trong code, không chỉ ý tưởng tương lai.

---

## Agent 1: Fetcher (`crawler/fetch.py`)

**Nhiệm vụ:** Tải HTML từ URL, cache ra file, xử lý lỗi mạng.

**Input:** Danh sách URL từ `tarot-meaning-links.json`

**Output:** Raw HTML string cho mỗi lá bài

**Hành vi:**

- Đọc `tarot-meaning-links.json`
- Với mỗi entry, kiểm tra `data/raw/<slug>.html` đã có chưa (cache)
- Nếu chưa: fetch URL với header hợp lệ, delay 1–2s, lưu cache
- Nếu có rồi: đọc từ cache (skip network)
- Retry 3 lần nếu timeout hoặc 5xx
- Log tiến độ ra stdout

**Config:**

```python
DELAY = 1.5                    # seconds
MAX_RETRIES = 3
TIMEOUT = 15                   # seconds
CACHE_DIR = "data/raw"
HEADERS = {"User-Agent": "...Chrome/120..."}
```

**Interface:**

```python
def fetch_all(links: list[dict]) -> dict[str, Optional[str]]:
    """Returns {card_name: html_string_or_none}"""

def fetch_one(url: str) -> Optional[str]:
    """Fetch single URL with caching"""
```

---

## Agent 2: Parser (`crawler/parser.py`)

**Nhiệm vụ:** Parse HTML, extract tất cả các trường theo schema.

**Input:** HTML string của một lá bài

**Output:** `TarotCard` dataclass object

**Parsing logic theo từng trường:**

### Keywords

`<h2>X Keywords</h2>` → bảng đầu tiên, row[1]: col 0 = upright, col 1 = reversed.

```python
table = soup.find("h2", string=lambda s: s and "Keywords" in s).find_next("table")
rows = table.find_all("tr")
upright_kw = rows[1].find_all("td")[0].get_text().strip()
reversed_kw = rows[1].find_all("td")[1].get_text().strip()
```

### Description

`<h2>` chứa "Tarot Card Description" → `<p>` ngay sau.

```python
h2 = soup.find("h2", string=lambda s: s and "Tarot Card Description" in s)
description = h2.find_next_sibling("p").get_text(separator="\n").strip()
```

### Upright Description

`<p>` tags sau `<h2 id="up">` cho đến khi gặp `<table>`.

```python
h2_up = soup.find("h2", id="up")
paragraphs = []
for sibling in h2_up.next_siblings:
    if sibling.name == "table":
        break
    if sibling.name == "p":
        paragraphs.append(sibling.get_text().strip())
upright_desc = "\n\n".join(p for p in paragraphs if p)
```

### Upright Love / Career / Finances / Feelings / Actions

`<p>` ngay sau `<h3>` có keyword tương ứng.

```python
def extract_after_h3(soup, keyword):
    h3 = soup.find("h3", string=lambda s: s and keyword in s)
    if h3:
        return h3.find_next_sibling("p").get_text(separator="\n").strip()
    return None

upright_love     = extract_after_h3(soup, "Love Meaning - Upright")
upright_career   = extract_after_h3(soup, "Career Meaning - Upright")
upright_finances = extract_after_h3(soup, "Finances Meaning - Upright")
upright_feelings = extract_after_h3(soup, "Upright")  # h3 chứa "as Feelings"
upright_actions  = extract_after_h3(soup, "Upright")  # h3 chứa "as Actions"
```

> **Lưu ý:** h3 "Feelings" và "Actions" cần phân biệt upright vs reversed bằng text chứa "Upright"/"Reversed".

### Reversed Meaning

Tương tự Upright, dùng `<h2 id="rev">` và keyword "Reversed".

```python
reversed_love     = extract_after_h3(soup, "Love Meaning - Reversed")
reversed_career   = extract_after_h3(soup, "Career Meaning - Reversed")
reversed_finances = extract_after_h3(soup, "Finances Meaning - Reversed")
```

### Type & Element

Type suy luận từ URL. Element lấy theo từng lá Major Arcana nếu có trong `ELEMENT_BY_CARD`, còn Minor Arcana lấy theo suit.

```python
TYPE_FROM_URL = {
    "major-arcana": "Major Arcana",
    "cups":         "Cups",
    "wands":        "Wands",
    "swords":       "Swords",
    "pentacles":    "Pentacles",
}
ELEMENT_FROM_TYPE = {
    "Cups":         "Water",
    "Wands":        "Fire",
    "Swords":       "Air",
    "Pentacles":    "Earth",
    "Major Arcana": None,  # fallback nếu card không có trong ELEMENT_BY_CARD
}
```

### Astrology

Astrology lấy từ static lookup `ASTROLOGY` trong `crawler/reference.py`.

Coverage hiện tại:

- Aces: zodiac signs theo element.
- Pip cards 2-10: planet/sign correspondence.
- Court cards: zodiac degree ranges hoặc zodiac triplets từ cheatsheet.
- Major Arcana: planet hoặc zodiac correspondence.

**Yes or No:** lấy từ static lookup `YES_NO` trong `crawler/reference.py`.

**Interface:**

```python
def parse_card(html: str, name: str, url: str) -> TarotCard:
    """Parse HTML to structured TarotCard"""
```

---

## Agent 3: Writer (`crawler/main.py`)

**Nhiệm vụ:** Ghi output JSON từ list TarotCard.

**Input:** `list[TarotCard]`

**Output:** `data/output/tarot_meanings.json`

**Hành vi hiện tại:**

- Giữ thứ tự gốc từ `tarot-meaning-links.json`
- Ghi pretty-printed JSON với `ensure_ascii=False`
- Attach `card_image` từ `crawler/card_images.py`
- Download/cache cheatsheet images qua `crawler/cheatsheets.py`
- Log số lượng lá bài đã ghi thành công và danh sách lỗi parse/fetch

**Interface:**

```python
python -m crawler.main
```

---

## Enrichment Utilities (`enrichment/`)

**Nhiệm vụ:** Bổ sung dữ liệu sau khi crawl: tải ảnh lá bài, extract symbols/facet keywords từ cheatsheet, dịch JSON tiếng Anh sang tiếng Việt, merge enrichment vào JSON tiếng Việt.

**Modules hiện có:**

- `enrichment/download_hoctarot_images.py`: crawl ảnh lá bài từ Hoctarot vào `data/images`.
- `enrichment/enrich_cheatsheets.py`: dùng Claude Vision extract `symbols` và các `*_keywords` từ cheatsheet vào `data/output/tarot_meanings.json`.
- `enrichment/translate.py`: dịch `data/output/tarot_meanings.json` sang `data/output/tarot_meanings_vi.json`.
- `enrichment/enrich_vi.py`: dịch/merge các trường enrichment mới sang `data/output/tarot_meanings_vi.json`.

**Interface/CLI:**

```bash
python -m enrichment.download_hoctarot_images
python -m enrichment.enrich_cheatsheets
python -m enrichment.translate
python -m enrichment.enrich_vi
```

Các lệnh dùng Anthropic cần `ANTHROPIC_API_KEY`.

---

## Agent 4: Embedding/Retrieval (`learning/embeddings.py`)

**Nhiệm vụ:** Chuyển dữ liệu `tarot_meanings.json` và `tarot_meanings_vi.json` thành embedding index có thể search để phục vụ bot học bài và verification.

**Input:**

- `data/output/tarot_meanings.json`
- `data/output/tarot_meanings_vi.json`

**Output:**

- `data/embeddings/tarot_embeddings_en.json`
- `data/embeddings/tarot_embeddings_vi.json`

**Chunking logic:**

- Mỗi lá tạo nhiều chunk nhỏ theo facet:
  - `overview`
  - `correspondences`
  - `symbols`
  - `upright.summary`
  - `upright.love`
  - `upright.career`
  - `upright.finances`
  - `upright.feelings`
  - `upright.actions`
  - `reversed.summary`
  - `reversed.love`
  - `reversed.career`
  - `reversed.finances`
  - `reversed.feelings`
  - `reversed.actions`
- Mỗi chunk giữ metadata: `card_name`, `language`, `orientation`, `facet`, `keywords`, `card_image`, `cheatsheet_image`, `text_hash`.
- Production provider: OpenAI `text-embedding-3-small`.
- Local smoke-test provider: `hash-word-v1`, deterministic, không cần API key.

**Interface/CLI:**

```bash
python -m learning.embeddings build --provider hash --lang all
python -m learning.embeddings build --provider openai --lang all
python -m learning.embeddings search --lang vi --query "tình yêu mới"
```

---

## Agent 5: Study Session (`learning/study.py`)

**Nhiệm vụ:** Quản lý vòng học 78 lá cho từng user và tạo câu hỏi học bài cho daily/random.

**Hành vi:**

- Mỗi user có state riêng trong `data/bot_state/study_state.json`.
- Draw không lặp lá trong cùng một cycle 78 lá.
- Khi hết cycle, shuffle lại toàn bộ 78 lá và tăng `cycle`.
- Mỗi draw chọn một facet cụ thể để người học trả lời ngắn, thay vì hỏi toàn bộ ý nghĩa một lần.
- Mỗi draw có `hint` ngắn theo facet để người học có điểm bám nhưng không lộ đáp án đầy đủ.
- Facet được rotate để dần cover: tổng quan, xuôi/ngược, love, career, finances, feelings, actions, symbols, correspondences.

**Interface/CLI:**

```bash
python -m learning.study draw --user-id local --lang vi --mode random
python -m learning.study draw --user-id local --lang vi --mode daily
```

---

## Agent 6: Verification Prompt (`learning/verification.py`)

**Nhiệm vụ:** Retrieve reference chunks từ embedding index và build prompt để GPT chấm câu trả lời của người học.

**Input:**

- `card_name`
- `facet`
- `user_answer`
- embedding index tương ứng language

**Output:** Prompt yêu cầu GPT trả về JSON:

```json
{
  "score": 0,
  "passed": false,
  "correct_points": [],
  "missing_points": [],
  "incorrect_points": [],
  "feedback": "",
  "next_hint": ""
}
```

**Interface/CLI:**

```bash
python -m learning.verification prompt --lang vi --card-name "Ace of Cups" --facet upright.love --answer "..."
```

---

## Agent 7: Telegram App Runtime (`app/`)

**Nhiệm vụ:** Chạy SuperTarot như một ứng dụng Telegram bot bằng long polling, nối transport Telegram với các module `learning`.

**Modules hiện có:**

- `app/__main__.py`: entry point `python -m app`.
- `app/config.py`: đọc env config như `TELEGRAM_BOT_TOKEN`, `SUPERTAROT_LANGUAGE`, `SUPERTAROT_TIMEZONE`, `SUPERTAROT_GRADING_PROVIDER`, `SUPERTAROT_QA_PROVIDER`.
- `app/telegram_client.py`: client mỏng gọi Telegram Bot API bằng `requests`, gồm `sendChatAction` cho trạng thái `typing`.
- `app/state.py`: lưu app state vào `data/bot_state/telegram_bot_state.json`.
- `app/telegram_bot.py`: xử lý command, long polling, daily schedule.
- `app/llm.py`: adapter LLM cho OpenAI, Anthropic và Google Gemini.
- `app/grading.py`: retrieve reference chunks và gọi provider LLM đã chọn để chấm.
- `app/qa.py`: xử lý freeform Tarot Q&A bằng embedding retrieval và optional LLM synthesis.

**UI behavior:**

- Message thường không dùng reply keyboard menu mặc định.
- Menu nút chỉ mở khi dùng `/menu`, `/start`, `/help`, hoặc khi flow `/learn` cần người dùng chọn bộ/lá bài.
- `/menu`, `/start`, và `/help` phải clear `learn_menu` trước khi gửi reply keyboard để luôn quay về menu chính.
- Message thường, Q&A, random/daily, grading gửi `remove_keyboard` để Telegram không tự xổ reply keyboard sau mỗi phản hồi.
- `/learn` gửi summary lá bài với hai inline button `⬆️ Xuôi`/`⬇️ Ngược` (`⬆️ Upright`/`⬇️ Reversed` cho EN).
- Danh sách lá bài trong `/learn` sắp theo thứ tự bộ bài chuẩn qua `learning/deck_order.py`, không theo alphabet; nút chọn bộ xếp Ẩn Chính → Gậy → Cốc → Kiếm → Tiền Vàng.
- Callback `learn_orientation` gửi chi tiết đúng chiều lá bài với `show_menu=False` để không làm Telegram tự xổ reply keyboard/menu.
- Callback `learn_full` cũ vẫn được nhận để các tin nhắn cũ không lỗi, nhưng UI mới không còn gửi nút `Xem đầy đủ`.
- Q&A và grading giữ trạng thái `typing` bằng background loop, gửi lại `sendChatAction` định kỳ trong suốt bước xử lý có thể chậm.
- Q&A gửi `parse_mode=HTML`, chuẩn hóa Markdown `**`/`*` thành `<b>`/`•`, và không gắn footer Lưu ý/Tham chiếu/Nguồn.

**Bot commands:**

- `/random`: rút câu hỏi học bài ngẫu nhiên.
- `/daily`: rút daily ngay.
- `/learn [card]`: xem summary lá bài và chọn chiều Xuôi/Ngược.
- `/ask ...`: hỏi đáp tarot bằng dữ liệu embedding.
- `/menu`: mở menu nút Telegram.
- `/schedule HH:MM`: bật daily tự động theo `SUPERTAROT_TIMEZONE`.
- `/unschedule`: tắt daily.
- `/answer ...`: chấm câu trả lời cho câu hỏi đang mở.
- `/lang vi|en`: đổi language cho chat.
- `/status`: xem trạng thái chat.
- `/help`: hướng dẫn.

**Freeform message behavior:**

- Text không bắt đầu bằng `/`, không phải menu button, và không nằm trong learn menu sẽ được hiểu là `Freeform Tarot Question`.
- Bot dùng `app/qa.py` để retrieve từ `data/embeddings/tarot_embeddings_<lang>.json`, rồi tổng hợp câu trả lời bằng provider trong `SUPERTAROT_QA_PROVIDER`.
- `SUPERTAROT_QA_PROVIDER`: `auto`, `openai`, `anthropic`, `google`, `context`.
- `SUPERTAROT_GRADING_PROVIDER`: `auto`, `openai`, `anthropic`, `google`, `prompt`.
- `auto` chọn provider theo key có sẵn: OpenAI → Anthropic → Google.
- Nếu thiếu key/provider lỗi, Q&A fallback về các mảnh dữ liệu liên quan và không gắn footer tham chiếu ở cuối.
- Chấm câu trả lời học bài phải dùng `/answer ...`; text thường không còn tự động đi vào verification.

**Interface/CLI:**

```bash
python -m app --check
python -m app
```

`--check` không gọi Telegram, chỉ kiểm tra config redacted và file dữ liệu local. Chạy thật cần `TELEGRAM_BOT_TOKEN`. Chấm tự động cần `OPENAI_API_KEY`; nếu thiếu key, bot vẫn rút bài nhưng chỉ báo GPT grading chưa bật.

---

## Deck Order (`learning/deck_order.py`)

**Nhiệm vụ:** Cung cấp thứ tự bộ bài chuẩn cho mọi chỗ con người duyệt bài.

Dữ liệu crawl lưu theo alphabet vì trang nguồn liệt kê như vậy. Module này định nghĩa `MAJOR_ARCANA_ORDER` (The Fool 0 → The World 21), `SUIT_ORDER` (Wands, Cups, Swords, Pentacles) và `RANK_ORDER` (Ace → Ten → Page → Knight → Queen → King).

**Interface:**

- `deck_position(name) -> (group, position, name)`: sort key; tên lạ rơi vào nhóm cuối thay vì raise, để lỗi dữ liệu chỉ làm lệch đuôi danh sách chứ không vỡ menu.
- `sort_cards(cards) -> list[dict]`: sắp danh sách card dict theo `deck_position`.

Tên lá bài trong cả JSON EN và VI đều là tiếng Anh, nên một bảng tra dùng chung cho hai ngôn ngữ. `app/learn.py::cards_for_suit()` gọi `sort_cards()`, và `mobile/lib/src/models/deck_order.dart` là bản port Dart của cùng logic.

---

## Agent 8: Android App (`mobile/`)

**Nhiệm vụ:** Chạy SuperTarot như một app Android độc lập, đóng gói toàn bộ dữ liệu tarot vào APK. Không có máy chủ trung gian: API key do người dùng nhập trong app và app gọi thẳng nhà cung cấp.

**Asset pipeline (`mobile/tools/prepare_assets.py`):**

- Đọc `data/output/tarot_meanings*.json` qua `app.learn.load_cards_for_language()` (đã backfill metadata VI) rồi `sort_cards()`.
- Ghi `mobile/assets/data/cards_{en,vi}.json`, bỏ các field app không đọc.
- Tách embedding index thành `index_{en,vi}.json` (metadata chunk) và `index_{en,vi}.f32` (vector float32 little-endian phẳng) để app không phải parse ~1.2 triệu số JSON lúc khởi động.
- Copy 78 ảnh lá bài. Tổng bundle ~16 MB.
- **Phải chạy lại sau mỗi lần dữ liệu tarot hoặc embedding index thay đổi.**

**Port 1-1 từ Python:**

| Dart | Python |
| ---- | ------ |
| `models/deck_order.dart` | `learning/deck_order.py` |
| `data/hash_embedder.dart` | `HashEmbeddingProvider` trong `learning/embeddings.py` |
| `data/embedding_index.dart` | `search_index()` trong `learning/embeddings.py` |
| `services/study_service.dart` | `learning/study.py` |
| `services/grading_service.dart` | `learning/verification.py` + `app/grading.py` |
| `services/qa_service.dart` | `app/qa.py` |
| `services/llm_client.dart` | `app/llm.py` |

**Ràng buộc parity:** `HashEmbedder` phải sinh vector giống hệt provider Python, nếu không vector query không cùng không gian với index đã bundle. Hai chỗ dễ sai: `\w` của Dart chỉ ASCII (phải dùng `[\p{L}\p{N}_]+` cho tiếng Việt), và `int.from_bytes(digest, "big")` là số 64-bit không dấu không vừa `int` có dấu của Dart (phải modulo theo từng byte). `test/hash_embedder_test.dart` chốt parity bằng vector tham chiếu sinh từ Python — test đỏ nghĩa là code sai, không phải kỳ vọng sai.

**UI:** bốn tab — Tra cứu (duyệt theo bộ, tìm theo tên, chi tiết lá bài 3 tab Tổng quan/Xuôi/Ngược), Học bài (rút không lặp trong vòng 78 lá + chấm rubric), Hỏi đáp (Q&A trên index), Cài đặt (ngôn ngữ, provider, API key + model, số chunk retrieve).

**Design system:** neubrutalism theo `DESIGN.md` — viền 3px, bóng cứng lệch 4px không blur, màu phẳng bão hòa cao, không gradient, chữ đậm viết hoa, full light/dark. Token nằm ở `lib/src/theme.dart` dưới dạng ThemeExtension `NeuTokens`; mọi màn hình dựng từ primitive trong `lib/src/widgets/neu.dart` và không hard-code viền/bóng. Ở dark, `line` và `shadow` đổi sang gần trắng vì viền đen trên nền tối vô hình. Chỉ dùng icon vector, không emoji; năm biểu tượng bộ bài vẽ bằng path trong `lib/src/widgets/suit_glyph.dart` vì Material không có gươm/chén/đồng xu.

**Cập nhật trong app (`services/update_service.dart`, `widgets/update_section.dart`):** app cài sideload nên tự lo đường cập nhật. Đọc `releases/latest` của GitHub, so tag với version đang cài (so theo số, không theo chuỗi, để 1.10.0 đứng trên 1.9.0), chọn asset khớp ABI của máy, tải có progress rồi giao cho package installer. Cần `REQUEST_INSTALL_PACKAGES` trong manifest; Android vẫn hỏi quyền lần đầu và luôn hiện màn xác nhận. APK tải về phải cùng chữ ký với bản đang cài, nên chỉ đúng khi release ra từ CI. API GitHub không xác thực giới hạn 60 lần/giờ nên đây là nút bấm chứ không chạy lúc mở app.

**Icon app:** sinh từ `mobile/icon/app_icon.png` bằng `dart run flutter_launcher_icons`, cấu hình trong `pubspec.yaml`. `adaptive_icon_foreground_inset: 12` vì adaptive icon chỉ đảm bảo 66% ở giữa hiển thị còn art chiếm 84% canvas. File sinh ra được commit; CI không chạy generator.

**Zoom lưới bài:** 1-5 cột, pinch hoặc nút trên app bar, lưu trong prefs. Pinch phải đi qua `Listener` thô: `GestureDetector` scale tranh chấp với drag recognizer của GridView trong gesture arena và thua, nên pinch không bao giờ chạy. Chiều cao ô tính từ chiều rộng thật qua `LayoutBuilder` để ảnh không bị cắt ở mọi số cột.

**State:** `SettingsStore` giữ prefs + API key (`flutter_secure_storage`, Android EncryptedSharedPreferences) và là `ChangeNotifier` cho `AppScope`. `StudyService` lưu vòng 78 lá và câu hỏi đang mở vào `SharedPreferences`, nên đóng app giữa chừng không mất lá đang hỏi.

**Interface/CLI:**

```bash
python mobile/tools/prepare_assets.py
cd mobile && flutter pub get && flutter test
flutter build apk --release --split-per-abi
```

Ký release đọc `mobile/android/key.properties` (gitignored); thiếu file thì fallback debug key. Chi tiết trong `mobile/README.md` (bản tiếng Việt: `mobile/README.vi.md`).

---

## Agent 9: Static Web (`web/`)

**Nhiệm vụ:** Công bố ý nghĩa 78 lá cho trình duyệt, không cần cài gì và không cần API key.

**Ranh giới rõ ràng:** web **không có AI**. Hỏi đáp và chấm bài cần API key nên chỉ tồn tại ở app Android. Web chỉ giữ những phần chạy được offline và miễn phí: tra cứu, tìm theo tên, rút bài. Trang rút bài hiện đáp án tham chiếu thay vì chấm.

**Pipeline:** `web/tools/prepare_web_assets.py` đọc `data/output` + `data/images` qua `app.learn.load_cards_for_language()` và `sort_cards()`, ghi `web/src/data/cards_*.json` (kèm slug và chỉ số vị trí) và `web/public/cards/`. Nó cũng sinh logo/favicon/og từ `mobile/icon/app_icon.png` bằng decoder/encoder PNG tự viết trên thư viện chuẩn, để không kéo dependency ảnh chỉ vì ba file. Không sinh embedding index.

**Route:** `/vi/` và `/en/` với home, `suit/<key>`, `card/<slug>`, `draw`; gốc `/` redirect về `/vi/`. 171 trang prerender, mỗi trang có canonical, `hreflang` chéo hai ngôn ngữ, Open Graph, và JSON-LD cho trang lá bài.

**Logic dùng chung:** `web/src/lib/study.ts` là port thứ ba của `learning/study.py` (sau Dart). Cùng thứ tự facet, cùng câu chữ, cùng vòng 78 lá không lặp. `web/test/study.test.ts` chốt tính chất không lặp — thứ mà ảnh chụp màn hình không thể chứng minh.

**Deploy:** `.github/workflows/pages.yml` build và đẩy lên GitHub Pages. `site` và `base` lấy từ `actions/configure-pages` lúc build chứ không hard-code, vì tài khoản phục vụ Pages qua custom domain; `robots.txt` sinh từ `Astro.site` cùng lý do.

---

## Release Pipeline (`.github/workflows/`, `release-please-config.json`)

**Nhiệm vụ:** Bump version, sinh changelog, tạo GitHub Release và đính APK, tất cả từ message của commit.

**Cấu hình:** một package ở path `.`, `release-type: simple` (bump `version.txt`), `include-component-in-tag: false` (tag `vX.Y.Z`), và `extra-files` kiểu `generic` trỏ vào `mobile/pubspec.yaml` để bump dòng có marker `# x-release-please-version`.

**Chi tiết dễ sai đã xác minh với tài liệu release-please:**

- Không đặt `release-type` trong workflow: nếu có, action bỏ qua hoàn toàn `release-please-config.json`.
- `version.txt` phải tồn tại sẵn; updater dùng `createIfMissing: false` nên file thiếu chỉ bị warn và bỏ qua. `CHANGELOG.md` thì tự tạo được.
- Với package ở path `.`, output là `release_created` không có tiền tố; khi không release thì nó rỗng chứ không phải `"false"`, nên phải kiểm tra truthiness thay vì so sánh chuỗi.
- Job cần `contents: write`, `issues: write`, `pull-requests: write`, và repo phải bật "Allow GitHub Actions to create and approve pull requests".

**`ci.yml`:** chạy trên pull_request và push main — compile Python, build index, sinh assets, `flutter analyze`, `flutter test`. Có mặt vì `release.yml` build APK *sau* khi Release đã được tạo, nên main hỏng sẽ đẻ ra Release không có APK.

**`release.yml` job `apk`:** khôi phục keystore từ secret, sinh lại index + assets, analyze/test, `flutter build apk --release --split-per-abi`, đổi tên thành `supertarot-<version>-<abi>.apk`, `gh release upload`, rồi xoá keystore ở bước `if: always()`.

**versionCode:** `mobile/android/app/build.gradle.kts` suy ra từ `flutter.versionName` theo `(major×10000 + minor×100 + patch) × 10000`. Bốn chữ số cuối bắt buộc để trống vì `--split-per-abi` khiến Flutter cộng thêm `abiCode × 1000` (armeabi-v7a 1, arm64-v8a 2, x86_64 4); đánh số dày hơn sẽ làm hai release khác nhau trùng `versionCode`.

**Dữ liệu sinh ra không commit:** `data/embeddings/` và `mobile/assets/` nằm trong `.gitignore` và được dựng lại trong CI từ `data/output/` + `data/images/`. Provider `hash` deterministic và chỉ cần Python chuẩn (đã kiểm bằng venv trống), nên không có secret nào trong đường build dữ liệu.

---

## Models (`crawler/models.py`)

```python
from dataclasses import dataclass, field
from typing import Optional

@dataclass
class Meaning:
    description: Optional[str] = None
    love: Optional[str] = None
    career: Optional[str] = None
    finances: Optional[str] = None
    feelings: Optional[str] = None
    actions: Optional[str] = None

@dataclass
class TarotCard:
    name: str
    url: str
    type: Optional[str] = None
    element: Optional[str] = None
    astrology: Optional[str] = None
    yes_no: Optional[str] = None
    cheatsheet_image: Optional[str] = None
    cheatsheet_image_url: Optional[str] = None
    upright_keywords: list[str] = field(default_factory=list)
    reversed_keywords: list[str] = field(default_factory=list)
    description: Optional[str] = None
    upright: Meaning = field(default_factory=Meaning)
    reversed: Meaning = field(default_factory=Meaning)
```

Sau các bước enrich, output JSON có thể có thêm `symbols`, `card_image` và các trường `*_keywords` theo từng facet trong `upright`/`reversed`.

---

## Main Entry Point (`crawler/main.py`)

```python
links = json.load(open("tarot-meaning-links.json"))
html_map = fetch_all(links)
cards = []
for entry in links:
    html = html_map.get(entry["name"])
    if html:
        cards.append(parse_card(html, entry["name"], entry["url"]).to_dict())

attach_card_image_refs(cards)
download_cheatsheet_images(cards)
Path("data/output/tarot_meanings.json").write_text(...)
```

---

## Edge Cases cần xử lý

| Vấn đề                                      | Xử lý                                       |
| ------------------------------------------- | ------------------------------------------- |
| Trang không có section "Feelings"/"Actions" | `try/except`, trả về `None`                 |
| Major Arcana có cấu trúc h3 khác            | Match bằng keyword lỏng hơn                 |
| HTML có `<br>` giữa đoạn văn                | `get_text(separator=" ")`                   |
| Text có whitespace thừa                     | `.strip()` + `re.sub(r'\s+', ' ', ...)`     |
| Lá bài bị block (403/429)                   | Log warning, tiếp tục với lá khác           |
| h3 title khác nhau giữa các card            | Match substring thay vì exact string        |

---

## Thứ tự chạy & kiểm tra

```bash
pip install requests beautifulsoup4 lxml
python -m crawler.main
```

```python
import json
data = json.load(open("data/output/tarot_meanings.json"))
print(f"Total cards: {len(data)}")
card = data[0]
print(f"Name: {card['name']}")
print(f"Upright keywords: {card['upright_keywords']}")
print(f"Description length: {len(card['description'] or '')}")
```
