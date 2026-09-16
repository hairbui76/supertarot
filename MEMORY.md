# SuperTarot Memory

## Maintenance Rule

- Update this file after every repo change.
- If a change modifies structure, schemas, runtime behavior, or adds/removes logic, also update `CLAUDE.md` and `AGENTS.md`.
- Keep entries concise: date, intent, files touched, verification.

## 2026-09-16

- Sắp xếp lá bài trong `/learn` theo thứ tự bộ bài thay vì alphabet.
- Thêm `learning/deck_order.py` với `MAJOR_ARCANA_ORDER` (The Fool 0 → The World 21), `SUIT_ORDER` (Wands, Cups, Swords, Pentacles), `RANK_ORDER` (Ace → Ten → Page → Knight → Queen → King), `deck_position()` và `sort_cards()`. Tên lá bài trong cả JSON EN và VI đều tiếng Anh nên một bảng tra dùng chung. Tên lạ sort xuống cuối thay vì raise.
- `app/learn.py::cards_for_suit()` gọi `sort_cards()`; nút chọn bộ trong `app/telegram_bot.py::learn_suit_keyboard()` đổi sang Ẩn Chính → Gậy → Cốc → Kiếm → Tiền Vàng.
- Verification:
  - `python -m compileall app learning`
  - smoke test in ra 5 bộ: Major đúng 0-21, mỗi chất đúng Ace→King.

- Thêm ứng dụng Android `mobile/` (Flutter) dùng chung dữ liệu tarot của repo.
- `mobile/tools/prepare_assets.py` export `cards_{en,vi}.json` (đã sort deck order, VI backfill metadata), tách embedding index thành `index_*.json` (metadata) + `index_*.f32` (vector float32 little-endian phẳng), copy 78 ảnh lá bài. Bundle ~16 MB. Phải chạy lại sau mỗi lần đổi dữ liệu.
- Bốn tab: Tra cứu, Học bài, Hỏi đáp, Cài đặt. Tra cứu/rút bài/retrieval chạy offline hoàn toàn; API key OpenAI/Anthropic/Google người dùng nhập trong Cài đặt, lưu bằng `flutter_secure_storage`, app gọi thẳng nhà cung cấp.
- Port 1-1 sang Dart: `deck_order.py`, `HashEmbeddingProvider`, `search_index()`, `learning/study.py`, `learning/verification.py` + `app/grading.py`, `app/qa.py`, `app/llm.py`.
- Hai bẫy parity đã xử lý: `\w` của Dart chỉ ASCII nên phải dùng `[\p{L}\p{N}_]+` cho tiếng Việt; `int.from_bytes(digest, "big")` là 64-bit không dấu nên phải modulo theo từng byte thay vì ép `int` có dấu.
- Bug đã sửa trong lúc test trên emulator: lưu API key làm banner cảnh báo biến mất, list shift một vị trí, Flutter rebind state của `_ProviderCard` sang card kế bên (Anthropic hiện model `gpt-4.1-mini`). Fix bằng `ValueKey<LlmProvider>`.
- Bug đã sửa: trước lần rút đầu tiên hiển thị "còn 0 lá"; `progress()` giờ nhận `deckSize` và báo đủ bộ khi vòng chưa bắt đầu.
- Android config: applicationId `co.astravision.supertarot`, label SuperTarot, minSdk 23 (EncryptedSharedPreferences), thêm quyền INTERNET vào main manifest, ký release qua `android/key.properties` (gitignored, fallback debug key).
- Cập nhật `README.md`, `CLAUDE.md`, `AGENTS.md`, thêm `mobile/README.md`.
- Verification:
  - `flutter analyze` — no issues
  - `flutter test` — 17 test pass (parity hash embedder với vector tham chiếu Python, deck order, load assets EN/VI, cosine search)
  - `flutter build apk --release --split-per-abi` — arm64 25.6 MB, armeabi-v7a 23.2 MB, x86_64 27.0 MB
  - Cài lên emulator x86_64, chạy thật: duyệt bộ + chi tiết lá bài, rút bài học, lưu API key, Q&A retrieve + fallback khi key sai. Không crash.
- Ghi chú chất lượng: index đang bundle build bằng provider `hash` (bag-of-words), nên retrieval của cả app và bot chỉ ở mức từ khóa — truy vấn `Queen of Cups` trả `Knight of Cups` trước. Đã xác nhận Python cho kết quả y hệt. Muốn tốt hơn phải build index bằng OpenAI và cho app gọi API embedding cho query.

## 2026-05-24

- Refined `/random` and `/daily` study draw messages.
- Removed the duplicated top `Lá bài: ...` line from Telegram draw formatting because the generated question already includes the card name.
- Added facet-specific `hint` to `StudyDraw` and included it in the Telegram draw message.
- Updated `README.md`, `CLAUDE.md`, and `AGENTS.md`.
- Verification run:
  - `python -m compileall app learning`
  - smoke test confirmed draw formatting contains only one `Lá bài:` line and includes `Gợi ý:`.
  - `python -m app --check`

- Made Telegram `typing...` visible during slow Q&A/grading calls.
- Replaced one-shot `send_typing()` usage with `typing_indicator()` background loop that repeats `sendChatAction=typing` until the slow operation finishes.
- Applied the loop around freeform Q&A and study answer grading.
- Updated `README.md`, `CLAUDE.md`, and `AGENTS.md`.
- Verification run:
  - `python -m compileall app`
  - fake-client smoke test confirmed repeated typing actions while the indicator context is active.
  - `python -m app --check`

- Split `/learn` inline details into orientation-specific actions.
- Replaced the new `/learn` summary inline button `Xem đầy đủ` with two buttons: `⬆️ Xuôi` and `⬇️ Ngược` (`⬆️ Upright`/`⬇️ Reversed` for EN).
- Added `format_card_orientation_details()` so callbacks return only the selected orientation's keywords, meaning, love/career/finances/feelings/actions.
- Added `learn_orientation` callback handling and kept legacy `learn_full` callback support for old messages.
- Updated `README.md`, `CLAUDE.md`, and `AGENTS.md`.
- Verification run:
  - `python -m compileall app`
  - fake-client smoke test confirmed `/learn` sends two inline orientation buttons and callbacks return orientation-specific HTML without reply keyboard menu.

- Reset Telegram menu state when opening the main menu/help.
- `/help`, `/start`, and `/menu` now clear `learn_menu` before sending `show_menu=True`, so the reply keyboard returns to the main menu even if the user was midway through `/learn`.
- Updated `README.md`, `CLAUDE.md`, and `AGENTS.md`.
- Verification run:
  - fake-client smoke test confirmed `/help` clears `learn_menu` and sends the main menu keyboard.
  - `python -m compileall app`

- Improved Telegram waiting state and Q&A rendering.
- Added Telegram `sendChatAction=typing` before freeform Q&A and answer grading.
- Q&A replies now send `parse_mode=HTML`, sanitize Markdown bold/list markers into Telegram-safe `<b>` and `•`, and strip generated Lưu ý/Tham chiếu/Nguồn footers.
- Updated `README.md`, `CLAUDE.md`, and `AGENTS.md`.
- Verification run:
  - `python -m compileall app`
  - formatter smoke test confirmed raw `**`, `*`, Lưu ý, and Tham chiếu are removed from screenshot-like output.
  - fake-client smoke test confirmed non-command Q&A sends `typing`, `parse_mode=HTML`, and `remove_keyboard`.
  - `python -m app --check`

- Added optional Anthropic and Google/Gemini providers for Q&A and grading.
- Added `app/llm.py` shared provider adapter for OpenAI, Anthropic, and Google REST calls.
- Extended config with `ANTHROPIC_CHAT_MODEL`, `GOOGLE_CHAT_MODEL`, `ANTHROPIC_API_KEY`, and `GOOGLE_API_KEY`/`GEMINI_API_KEY` checks.
- `SUPERTAROT_QA_PROVIDER` now accepts `auto`, `openai`, `anthropic`, `google`, `context`; `SUPERTAROT_GRADING_PROVIDER` accepts `auto`, `openai`, `anthropic`, `google`, `prompt`.
- Updated `.env.example`, `README.md`, `CLAUDE.md`, and `AGENTS.md`.
- Verification run:
  - `python -m compileall app`
  - `python -m app --check`
  - Q&A smoke test with `qa_provider=google` and no Google key confirms context fallback reports missing `GOOGLE_API_KEY or GEMINI_API_KEY`.
  - Grading smoke test with `grading_provider=prompt` still returns prompt mode.

- Changed Telegram reply keyboard behavior so the menu no longer auto-opens after every user message.
- Added `/menu` command and made normal responses send `remove_keyboard`; menu keyboard now uses `one_time_keyboard`.
- Kept reply keyboard only for `/menu`, `/start`, `/help`, and `/learn` selection prompts.
- Verification run:
  - `python -m compileall app`
  - fake-client smoke test confirmed `/menu` and `/learn` attach keyboard, while Q&A and `/random` send `remove_keyboard`.

- Improved Tarot Q&A runtime diagnostics.
- Local config check confirmed `.env` is loaded with `SUPERTAROT_QA_PROVIDER=openai`.
- Added startup logging of redacted `AppConfig` and made OpenAI Q&A fallback messages include the actual OpenAI/config error instead of implying the provider was disabled.
- Added `openai` package availability to `python -m app --check` and document reinstall/rebuild steps for OpenAI Q&A fallback cases.
- Removed duplicate `openai` requirement line and installed current requirements in the local Python runtime.
- Verification run:
  - `python -m pip install -r requirements.txt`
  - `python -m app --check` now reports `python_packages.openai=true` and `ok=true`.
  - simulated invalid OpenAI model confirms Q&A fallback now reports OpenAI/config failure explicitly.

- Added freeform Tarot Q&A behavior for Telegram non-command messages.
- Added `app/qa.py` to retrieve embedding chunks and synthesize tarot answers with OpenAI when available, or return context chunks in fallback/context mode.
- Updated `app/telegram_bot.py` routing so plain text becomes Q&A; study grading now requires `/answer ...`.
- Added `SUPERTAROT_QA_PROVIDER` and `SUPERTAROT_QA_TOP_K` config/env support.
- Added root `CONTEXT.md` glossary for Freeform Tarot Question, Study Answer, Retrieved Reference Chunk, Tarot Q&A, and Study Draw.
- Updated `README.md`, `CLAUDE.md`, `AGENTS.md`, and `.env.example`.
- Verification run:
  - `python -m compileall app crawler learning enrichment`
  - `python -m app --check`
  - fake-client smoke test confirmed plain text goes to Tarot Q&A, plain text after `/random` still goes to Tarot Q&A, and `/answer ...` goes to grading.

- Fixed Telegram `Xem đầy đủ` inline callback so it sends the full card message without default reply keyboard markup.
- Cause: `app/telegram_bot.py::send_message` always attached the persistent reply keyboard when `reply_markup` was omitted, so Telegram reopened the menu after callback messages.
- Added `show_menu` to `send_message` and set `show_menu=False` for full-card callback details.
- Verification run:
  - `python -m compileall app`
  - fake callback smoke test confirmed `parse_mode=HTML`, `reply_markup=None`, and callback answered.

- Cleaned accidental CJK/Korean/Japanese fragments from `data/output/tarot_meanings_vi.json`.
- Rebuilt `data/embeddings/tarot_embeddings_vi.json` with the existing hash provider so the VI index no longer contains stale mixed-language text.
- Verification run:
  - `rg -n -P "\p{Han}|\p{Hiragana}|\p{Katakana}|\p{Hangul}" data\output data\embeddings`
  - `python -m learning.embeddings build --provider hash --lang vi`
  - JSON load check for both meaning files and both embedding indexes.

## 2026-05-23

- Added runnable Telegram bot application source under `app/`.
- Added `app/__main__.py` so the app runs with `python -m app`.
- Added runtime modules:
  - `app/config.py` for env config and redacted config checks;
  - `app/telegram_client.py` for direct Telegram Bot API long polling via `requests`;
  - `app/state.py` for `data/bot_state/telegram_bot_state.json`;
  - `app/telegram_bot.py` for commands `/random`, `/daily`, `/schedule`, `/unschedule`, `/answer`, `/lang`, `/status`, `/help`;
  - `app/grading.py` for reference retrieval plus optional OpenAI grading.
- Added `.env.example` documenting `TELEGRAM_BOT_TOKEN`, app language/timezone, image sending, and grading env vars.
- Updated `README.md`, `CLAUDE.md`, and `AGENTS.md` with app runtime architecture and run commands.
- Verification run:
  - `python -m compileall app crawler learning enrichment`
  - `python -m app --check`
  - `python -m app.telegram_bot --check`
  - fake-client smoke test for `/lang`, `/random`, and `/answer` in prompt mode.

- Separated non-crawler responsibilities into dedicated packages and added run documentation.
- Added `README.md` with setup, module boundaries, run order, local smoke-test commands, API-key notes, and data directory map.
- Moved learning code from `crawler/` to `learning/`:
  - `learning/embeddings.py`
  - `learning/study.py`
  - `learning/verification.py`
  - `learning/console.py` for Windows-safe UTF-8 CLI output.
- Moved enrichment scripts from `crawler/` to `enrichment/`:
  - `enrichment/download_hoctarot_images.py`
  - `enrichment/enrich_cheatsheets.py`
  - `enrichment/translate.py`
  - `enrichment/enrich_vi.py`
- Added compatibility wrappers in `crawler/` for the old module commands.
- Updated `CLAUDE.md` and `AGENTS.md` to describe the split between `crawler`, `enrichment`, and `learning`.
- Verification run:
  - `python -m compileall crawler learning enrichment`
  - `python -m learning.embeddings build --provider hash --lang vi --dry-run`
  - `python -m learning.study draw --user-id readme-test --lang vi --mode random --seed 7 --state data/bot_state/readme_test_state.json`
  - `python -m learning.verification prompt --lang vi --card-name "Ace of Cups" --facet upright.love --answer "tình yêu mới mở lòng" --top-k 2`
  - compatibility wrapper checks for `crawler.embeddings`, `crawler.study`, and `crawler.verification`.

- Added embedding/retrieval foundation for `data/output/tarot_meanings.json` and `data/output/tarot_meanings_vi.json`.
- Added `crawler/embeddings.py`:
  - chunks each card by overview, correspondences, symbols, upright/reversed summary, love, career, finances, feelings, actions;
  - supports OpenAI production embeddings with `text-embedding-3-small`;
  - supports deterministic `hash` provider for offline smoke tests;
  - writes/searches `data/embeddings/tarot_embeddings_en.json` and `data/embeddings/tarot_embeddings_vi.json`.
- Added `crawler/study.py` for future Telegram bot study flow:
  - per-user deck state in `data/bot_state/study_state.json`;
  - no repeated cards within a 78-card cycle;
  - resets/shuffles when the cycle is exhausted;
  - rotates question facets so daily/random sessions cover all meaning areas over time.
- Added `crawler/verification.py` to retrieve reference chunks and build a GPT grading prompt that returns JSON feedback.
- Updated `requirements.txt` with `openai` for embeddings and `anthropic` because existing translation/enrichment scripts import it.
- Updated `CLAUDE.md` and `AGENTS.md` with the documentation maintenance rule and the new embedding/study/verification pipeline.
- Reconciled `CLAUDE.md` and `AGENTS.md` with current code fields: `yes_no`, card/cheatsheet images, symbols, enriched facet keywords, current metadata lookups, and `crawler/main.py` writer behavior.
- Generated local smoke-test embedding indexes:
  - `data/embeddings/tarot_embeddings_en.json`
  - `data/embeddings/tarot_embeddings_vi.json`
- Verification run:
  - `python -m crawler.embeddings build --provider hash --lang all`
  - `python -m crawler.embeddings search --lang vi --query "tình yêu mới và cảm xúc mở lòng" --top-k 3`
  - `python -m crawler.study draw --user-id local-test --lang vi --mode random --seed 1 --state data/bot_state/test_study_state.json`
  - `python -m crawler.verification prompt --lang vi --card-name "Ace of Cups" --facet upright.love --answer "..."`
  - no-repeat invariant: 78 first-cycle draws are unique; draw 79 starts cycle 2.
