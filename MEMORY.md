# SuperTarot Memory

## Maintenance Rule

- Update this file after every repo change.
- If a change modifies structure, schemas, runtime behavior, or adds/removes logic, also update `CLAUDE.md` and `AGENTS.md`.
- Keep entries concise: date, intent, files touched, verification.

## 2026-09-16

- Thêm zoom lưới bài 1-5 cột và chuyển toàn bộ UI app sang neubrutalism theo `DESIGN.md`.
- Zoom: `SettingsStore.gridColumns` (clamp 1..5, lưu prefs), pinch trên lưới, kèm nút tăng/giảm trên app bar cho dễ thấy.
- Bug quan trọng: bản đầu dùng `GestureDetector(onScaleStart/onScaleUpdate)` bọc `GridView` — pinch không bao giờ chạy vì scale recognizer tranh chấp với drag recognizer của GridView trong gesture arena và thua. Widget test bắt được (nút thì chạy nên test tay không phát hiện). Đổi sang `Listener` thô theo dõi pointer, ngoài gesture arena; đóng băng scroll khi có 2 ngón để không trượt lưới giữa lúc đổi cột.
- Chiều cao ô tính từ chiều rộng thật qua `LayoutBuilder` thay vì `childAspectRatio` cố định, nên ảnh lá bài không bị cắt ở bất kỳ số cột nào.
- Design system: `lib/src/theme.dart` giữ `NeuTokens` (ThemeExtension) — viền 3px, bóng cứng lệch 4px không blur, radius 8px, palette vàng/đỏ/xanh dương + xanh lá và tím thêm vào cho đủ 5 bộ. `lib/src/widgets/neu.dart` có `NeuBox/NeuButton/NeuIconButton/NeuChip/NeuHeading/NeuSection/NeuField`; không màn hình nào hard-code viền hay bóng.
- Dark mode: `line` và `shadow` đổi sang gần trắng, vì viền đen trên nền tối là vô hình. Đã kiểm bằng `adb shell cmd uimode night yes`.
- Bỏ toàn bộ emoji trong UI theo yêu cầu của DESIGN.md, thay bằng icon vector. Năm biểu tượng bộ bài vẽ tay trong `lib/src/widgets/suit_glyph.dart` (gậy, chén, gươm, đồng xu có ngôi sao 5 cánh, sparkle cho Ẩn Chính) — Material Icons không có gươm/chén/đồng xu, và bản đầu tôi dùng nhầm icon nguyên tố (lửa/giọt nước/gió/cây) nên user phản hồi đúng là phải dùng biểu tượng của bộ.
- Màu bộ theo nguyên tố: lửa đỏ, nước xanh dương, khí vàng, đất xanh lá, tím cho Ẩn Chính.
- Tách `MarkupText` ra `lib/src/widgets/markup_text.dart`, xóa `section_block.dart`.
- Phần Execution Rules user gửi kèm viết cho landing page web (Navbar/Hero/Pricing/Testimonials/Footer, thẻ `<head>`, Tailwind CDN, Open Graph) nên không áp dụng cho app Flutter; chỉ áp dụng phần visual style. Cũng giữ nguyên song ngữ vi/en thay vì ép toàn bộ text sang tiếng Anh, vì app có toggle ngôn ngữ và dữ liệu tarot có bản tiếng Việt.
- DESIGN.md tự mâu thuẫn ở mục Do's/Don'ts ("No pure black", "saturation cap 80%") và Components ("1px border stroke", "subtle shadow 0 2px 12px rgba") so với chính spec neubrutalism trong cùng file; ưu tiên spec của style.
- Đã viết lại `DESIGN.md` theo yêu cầu bỏ phần landing page cho đỡ nhầm về sau:
  - Bỏ hết nội dung landing/web: "Ideal for landing pages, saas", hero split-screen, feature zig-zag, CSS Grid 1280px, z-index sticky-nav, mobile collapse 768px, và các Don't về `h-screen`, picsum.photos, lorem ipsum, AI copywriting clichés.
  - Sửa luôn các chỗ tự mâu thuẫn vì chúng cũng gây nhầm: bỏ "No pure black" và "saturation cap 80%", chốt radius 8px (Elevation cũ ghi "sharp corners 0px" trái với Shapes 8px), viết lại Components theo đúng cái đã implement (3px border, bóng cứng 4px) thay vì boilerplate 1px border + bóng mờ.
  - Thêm mục Scope nói rõ đây là style reference cho app Flutter trong `mobile/`, không phải blueprint trang web, và code (`theme.dart`) mới là source of truth nếu hai bên lệch nhau.
  - Thêm bảng surface light/dark, quy tắc dark mode đổi màu viền/bóng sang gần trắng, mục Icons, và block `tokens:` trong front matter khớp `NeuTokens`.
- Emulator: GlazeWM tile cửa sổ làm emulator chết liên tục. Cách chạy ổn định là `emulator.exe` qua background task của harness rồi `glazewm command set-floating` ngay sau đó. Launch bằng `(cmd &)` trong Bash thì process bị kill.
- Verification:
  - `flutter analyze` — no issues
  - `flutter test` — 22 test pass (thêm `test/grid_zoom_test.dart`: mặc định 2 cột, pinch ra còn 1, pinch vào tăng cột, stepper đi hết dải 1..5 và clamp hai đầu, giữ cột qua rebuild)
  - Chạy thật trên emulator: lưới 2/5/1 cột đều đúng và nút clamp đúng, style hiển thị chuẩn ở cả light lẫn dark, glyph bộ bài đúng biểu tượng
- Cập nhật `mobile/README.md`, `mobile/README.vi.md`, `CLAUDE.md`, `AGENTS.md`.

## 2026-09-16

- Thêm phát hành tự động bằng release-please, khởi tạo git và push lên `hairbui76/supertarot`.
- `release-please-config.json`: một package ở path `.`, `release-type: simple`, `include-component-in-tag: false` (tag `vX.Y.Z`), `extra-files` kiểu `generic` bump `mobile/pubspec.yaml` qua marker `# x-release-please-version`. Kèm `version.txt` và `.release-please-manifest.json` khởi tạo 1.0.0.
- `.github/workflows/release.yml`: release-please job + job `apk` (khôi phục keystore từ secret, sinh index + assets, analyze/test, build `--split-per-abi`, đổi tên `supertarot-<version>-<abi>.apk`, upload vào Release, xoá keystore ở `if: always()`).
- `.github/workflows/ci.yml`: chạy trên PR và push main. Có vì `release.yml` build APK sau khi Release đã tạo, nên main hỏng sẽ đẻ Release rỗng.
- Bốn chi tiết release-please đã tra tài liệu để tránh sai: không đặt `release-type` trong workflow (sẽ bỏ qua config file); `version.txt` phải tồn tại sẵn vì updater dùng `createIfMissing: false`; output cho path `.` là `release_created` không tiền tố và rỗng khi không release nên phải kiểm tra truthiness; cần `contents/issues/pull-requests: write` cộng setting cho phép Actions tạo PR.
- Bug đã sửa trong lúc verify: `versionCode` suy ra theo `major*1e6 + minor*1e3 + patch` bị đụng với offset ABI mà `--split-per-abi` cộng vào (`abiCode * 1000`). Đo bằng `aapt2 dump badging`: 1.0.0/arm64 ra 1002000 thay vì 1000000. Đổi sang `(major*10000 + minor*100 + patch) * 10000` để chừa 4 chữ số cuối cho offset. Kết quả: 100001000 / 100002000 / 100004000.
- Phát hiện `minSdk = 23` đặt trước đó đã quay về `flutter.minSdkVersion`; đổi thành `maxOf(flutter.minSdkVersion, 23)` để giữ yêu cầu mà vẫn theo sàn của Flutter.
- Phát hiện `data/embeddings/` bị stale: build 2026-05-24, sau đó `tarot_meanings_vi.json` sửa "Sao Thổ in Song Ngư" → "trong", làm 73/1170 chunk còn text cũ. Đã build lại index và mobile assets.
- Quyết định: `data/embeddings/` và `mobile/assets/` không commit, CI sinh lại từ `data/output/` + `data/images/` bằng provider `hash`. Đã kiểm bằng venv trống rằng cả hai bước chỉ cần Python chuẩn, không cần dependency hay API key. Repo ~10MB thay vì ~37MB và index không thể lệch với JSON nguồn nữa.
- `.gitignore` gốc: loại `.env` (chứa Telegram token và API key thật), `*.jks`, `key.properties`, `.venv`, `data/raw|cache|cheatsheets|embeddings|bot_state`, `mobile/build`, `mobile/assets`. Giữ `data/*.html` vì tài liệu tham chiếu parser.
- Đã set 4 secret ký APK trên repo và bật `can_approve_pull_request_reviews` để release-please mở được PR.
- Thêm `CONTRIBUTING.md` (Conventional Commits, luồng phát hành, versionCode, secrets, dữ liệu sinh ra).
- Verification:
  - `flutter analyze` / `flutter test` (17 test) pass sau khi đổi pubspec và gradle
  - `aapt2 dump badging` xác nhận versionCode 100001000 / 100002000 / 100004000 cho 1.0.0
  - Quét toàn bộ staged diff không thấy pattern `sk-`, `ghp_`, `sk-ant-`, `AIza`, hay Telegram token
  - Push `main` thành công; workflow `Release` xanh và release-please đã mở PR `chore(main): release 1.0.0`
  - Workflow `CI` trên `main` xanh sau 1m52s: compile Python, build index, sinh assets, analyze, test đều pass trên Linux
- README chuyển sang song ngữ, bản chính tiếng Anh: `README.md` (EN) + `README.vi.md` (VI), `mobile/README.md` (EN) + `mobile/README.vi.md` (VI), có dòng chuyển ngữ ở đầu mỗi file. `CONTRIBUTING.md` vẫn tiếng Việt.
- Nhân dịp viết lại: sửa chỗ README nói "cache/output đã có sẵn trong data/" vì `data/embeddings/` giờ không commit — thêm bước build index trước khi smoke test, và mô tả rõ thư mục nào commit, thư mục nào sinh ra.
- Workflow release: rút gọn message lỗi khi thiếu `ANDROID_KEYSTORE_BASE64` và thêm `keytool -list` ngay sau khi giải mã keystore để fail sớm thay vì lỗi Gradle khó đọc.
- Đã verify base64 round-trip của keystore khớp bit-perfect và alias/password mở được, vì job `apk` chưa chạy thật lần nào.
- Còn lại: PR release 1.0.0 chưa merge nên job `apk` chưa chạy lần nào. CI trên PR do release-please tạo ở trạng thái `action_required` vì PR được tạo bằng GITHUB_TOKEN.

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
