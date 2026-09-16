# SuperTarot

*Đọc bản [English](README.md) — đây là bản chính.*

SuperTarot gồm một bộ CLI Python, một Telegram bot học bài, và một app Android
chạy offline, tất cả xoay quanh nghĩa của 78 lá tarot. Repo crawl và enrich dữ
liệu lá bài, build embedding index, rút câu hỏi học bài, và chấm câu trả lời
dựa trên chính tài liệu nguồn.

## Module chính

```text
supertarot/
├── crawler/       # Crawl, parse, ghi JSON gốc
├── enrichment/    # Dịch, enrich cheatsheet, tải ảnh tham chiếu
├── learning/      # Embedding index, study session, verification prompt
├── app/           # Runtime Telegram bot
├── mobile/        # App Android (Flutter), dùng chung dữ liệu, chạy offline
├── web/           # Site tĩnh Astro, deploy lên GitHub Pages
├── .github/       # CI và release tự động bằng release-please
├── data/          # Cache HTML, ảnh, JSON output, embeddings, state bot
└── tarot-meaning-links.json
```

`crawler` vẫn còn wrapper tương thích cho lệnh cũ như
`python -m crawler.embeddings`, nhưng code mới nên dùng `learning.*` và
`enrichment.*`.

## Cài đặt

Chạy từ thư mục gốc của repo:

```powershell
py -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

Khi cần gọi API thật:

```powershell
$env:OPENAI_API_KEY="..."
$env:ANTHROPIC_API_KEY="..."
```

`OPENAI_API_KEY` chỉ cần khi build embedding bằng OpenAI hoặc khi chọn provider
OpenAI cho Q&A/grading. `ANTHROPIC_API_KEY` cần cho các script dịch/enrich bằng
Claude, hoặc khi chọn provider Anthropic. `GOOGLE_API_KEY` hoặc `GEMINI_API_KEY`
cần khi chọn provider Google/Gemini.

## Sinh dữ liệu local

`data/embeddings/` là dữ liệu sinh ra, không commit. Build một lần trước khi
chạy bất cứ thứ gì cần search hay chấm bài — provider `hash` deterministic và
không cần API key:

```powershell
python -m learning.embeddings build --provider hash --lang all
```

## Chạy Telegram bot

Tạo bot bằng BotFather, rồi cấu hình biến môi trường:

```powershell
$env:TELEGRAM_BOT_TOKEN="123456:telegram_token"
$env:SUPERTAROT_LANGUAGE="vi"
$env:SUPERTAROT_TIMEZONE="Asia/Saigon"
$env:SUPERTAROT_GRADING_PROVIDER="auto"
$env:SUPERTAROT_QA_PROVIDER="auto"
$env:OPENAI_API_KEY="..."
```

Provider hợp lệ:

- `SUPERTAROT_QA_PROVIDER`: `auto`, `openai`, `anthropic`, `google`, `context`.
- `SUPERTAROT_GRADING_PROVIDER`: `auto`, `openai`, `anthropic`, `google`, `prompt`.
- `auto` chọn provider đầu tiên có key: OpenAI, rồi Anthropic, rồi Google.
- `context` chỉ dành cho Q&A: không gọi LLM, chỉ trả về dữ liệu liên quan.
- `prompt` chỉ dành cho grading: không gọi LLM, chỉ trả prompt và chunk để debug.

Biến model tương ứng:

```powershell
$env:OPENAI_CHAT_MODEL="gpt-4.1-mini"
$env:ANTHROPIC_CHAT_MODEL="claude-haiku-4-5-20251001"
$env:GOOGLE_CHAT_MODEL="gemini-2.5-flash"
```

Kiểm tra cấu hình local trước khi chạy bot:

```powershell
python -m app --check
```

Nếu đã chọn provider LLM mà bot vẫn trả về context fallback, đọc lại output đó:
khối `python_packages` và các API key đã redact phải khớp với provider đang
chọn. Thiếu package thì cài lại:

```powershell
python -m pip install -r requirements.txt
```

Chạy bot:

```powershell
python -m app
```

### Lệnh của bot

Bot dùng long polling, không cần webhook.

- `/start` hoặc `/help`: hướng dẫn.
- `/random`: rút một câu hỏi học bài ngẫu nhiên, kèm gợi ý ngắn.
- `/daily`: rút câu hỏi daily ngay.
- `/learn [tên lá bài]`: xem tóm tắt lá bài, rồi bấm `⬆️ Xuôi` hoặc `⬇️ Ngược`.
- `/ask <câu hỏi>`: hỏi đáp tarot tự do trên embedding index.
- `/menu`: mở menu nút Telegram.
- `/schedule HH:MM`: gửi daily tự động mỗi ngày, ví dụ `/schedule 08:30`.
- `/unschedule`: tắt daily tự động.
- `/answer <nội dung>`: trả lời câu hỏi đang mở để bot chấm.
- `/lang vi` hoặc `/lang en`: đổi ngôn ngữ dữ liệu.
- `/status`: xem trạng thái chat hiện tại.

Danh sách lá bài trong `/learn` theo đúng thứ tự bộ bài — Ẩn Chính 0–21, rồi
từng chất từ Ace tới King — chứ không theo alphabet.

State ứng dụng lưu ở `data/bot_state/telegram_bot_state.json`; vòng học 78 lá
của từng user lưu ở `data/bot_state/study_state.json`.

Chưa có API key thì bot vẫn rút bài và nhận câu trả lời: Q&A fallback về dữ liệu
liên quan, còn grading có thể dùng `SUPERTAROT_GRADING_PROVIDER=prompt` để xem
prompt.

Tin nhắn thường không kèm command được hiểu là Tarot Q&A. Muốn bot chấm câu trả
lời sau `/random` hoặc `/daily` thì dùng `/answer ...` để không bị nhầm thành
câu hỏi.

Các phản hồi thường gửi `remove_keyboard` để Telegram không tự xổ menu sau mỗi
tin nhắn. Menu nút chỉ mở khi dùng `/menu`, `/start`, `/help`, hoặc khi flow
`/learn` cần bạn chọn. Trong lúc Q&A hoặc grading đang chạy, bot giữ trạng thái
`typing...` cho tới khi có phản hồi.

### Chạy bằng Docker

```powershell
docker compose up --build -d
docker compose logs -f supertarot-bot
docker compose down
```

Compose đọc `.env`, mount `./data` vào `/app/data` để giữ state và output, rồi
chạy `python -m app`. Sau khi sửa `.env` hoặc dependency thì rebuild và
recreate:

```powershell
docker compose up -d --build --force-recreate
```

Chạy thẳng từ image đã push, không cần build local:

```powershell
docker pull hairbui76/supertarot
docker run -d \
	--name supertarot-bot \
	--restart unless-stopped \
	--env-file .env \
	-v ${PWD}/data:/app/data \
	hairbui76/supertarot
```

Nếu `${PWD}` không mount đúng trên PowerShell thì thay bằng đường dẫn tuyệt đối.

## Smoke test local

Sau khi đã build index, các lệnh dưới đây không cần API key:

```powershell
python -m learning.embeddings search --lang vi --query "tình yêu mới" --top-k 3
python -m learning.study draw --user-id local --lang vi --mode random
python -m learning.verification prompt --lang vi --card-name "Ace of Cups" --facet upright.love --answer "tình yêu mới mở lòng và nhiều cảm xúc"
```

## 1. Crawler

Đọc `tarot-meaning-links.json`, fetch và cache HTML, parse trang Labyrinthos,
rồi ghi JSON tiếng Anh.

```powershell
python -m crawler.main
```

Output:

```text
data/output/tarot_meanings.json
data/raw/*.html
data/cheatsheets/*.png
```

- `crawler/fetch.py`: tải HTML, retry, cache vào `data/raw`.
- `crawler/parser.py`: parse HTML thành `TarotCard`.
- `crawler/models.py`: dataclass schema.
- `crawler/reference.py`: lookup type, element, astrology, yes/no.
- `crawler/main.py`: orchestration và ghi JSON.

## 2. Enrichment

Xử lý bổ sung sau khi crawl xong.

```powershell
python -m enrichment.download_hoctarot_images
python -m enrichment.enrich_cheatsheets
python -m enrichment.translate
python -m enrichment.enrich_vi
```

- `download_hoctarot_images`: tải ảnh lá bài từ Hoctarot vào `data/images`.
- `enrich_cheatsheets`: đọc ảnh cheatsheet, thêm `symbols` và facet keywords vào
  JSON tiếng Anh. Cần `ANTHROPIC_API_KEY`.
- `translate`: dịch `tarot_meanings.json` sang `tarot_meanings_vi.json`.
  Cần `ANTHROPIC_API_KEY`.
- `enrich_vi`: dịch và merge các trường enrich mới vào JSON tiếng Việt.
  Cần `ANTHROPIC_API_KEY`.

Nếu chỉ muốn học bài với dữ liệu có sẵn thì bỏ qua module này.

## 3. Learning

### Build embedding index

Smoke test offline, không cần API key:

```powershell
python -m learning.embeddings build --provider hash --lang all
```

Embedding production bằng OpenAI:

```powershell
python -m learning.embeddings build --provider openai --lang all
```

Output:

```text
data/embeddings/tarot_embeddings_en.json
data/embeddings/tarot_embeddings_vi.json
```

### Search index

```powershell
python -m learning.embeddings search --lang vi --query "tình yêu mới và cảm xúc mở lòng" --top-k 5
```

### Rút câu hỏi học bài

```powershell
python -m learning.study draw --user-id local --lang vi --mode random
python -m learning.study draw --user-id local --lang vi --mode daily
```

State theo user lưu ở `data/bot_state/study_state.json`. Mỗi user có vòng 78 lá
riêng và không rút trùng lá trong cùng một vòng.

### Tạo prompt chấm bài

```powershell
python -m learning.verification prompt --lang vi --card-name "Ace of Cups" --facet upright.love --answer "tình yêu mới, mở lòng, cảm xúc tích cực"
```

CLI này chỉ tạo prompt chấm dạng JSON. Runtime Telegram trong `app/` sẽ gọi
provider đã cấu hình để chấm tự động.

## 4. App Android

App Flutter trong `mobile/` đóng gói nghĩa 78 lá, ảnh lá bài và embedding index
vào APK. Tra cứu, rút bài và retrieval chạy offline; chỉ phần diễn giải và chấm
bài bằng AI mới cần mạng và API key, do người dùng nhập trong tab Cài đặt.

Cần Flutter stable, Android SDK và JDK 17.

```powershell
python mobile/tools/prepare_assets.py
cd mobile
flutter pub get
flutter test
flutter build apk --release --split-per-abi
```

APK nằm ở `mobile/build/app/outputs/flutter-apk/`; dùng
`app-arm64-v8a-release.apk` cho điện thoại Android hiện nay.

Chạy lại `prepare_assets.py` mỗi khi dữ liệu tarot hoặc embedding index đổi,
nếu không APK sẽ ship dữ liệu cũ. Chi tiết trong
[mobile/README.vi.md](mobile/README.vi.md).

## Web

Ý nghĩa 78 lá cũng được công bố dưới dạng site tĩnh, ai cũng mở bằng trình
duyệt được, không cần cài gì và không cần API key:
[tarot.hairbui76.id.vn](https://tarot.hairbui76.id.vn/).

Web chỉ tra cứu, tìm kiếm và rút bài. Hỏi đáp và chấm bài vẫn nằm ở app Android
vì cần API key.

```powershell
python web/tools/prepare_web_assets.py
cd web
npm install
npm test
npm run build
```

Mỗi lần push vào `main` là `.github/workflows/pages.yml` build và deploy. Chi
tiết trong [web/README.vi.md](web/README.vi.md).

## Phát hành

Tải APK mới nhất ở
[Releases](https://github.com/hairbui76/supertarot/releases). Mỗi release đính
ba file; dùng `supertarot-<version>-arm64-v8a.apk` cho điện thoại Android hiện
nay.

Phát hành chạy tự động bằng release-please: commit vào `main` theo Conventional
Commits, release-please mở PR bump version, merge PR đó là có tag, GitHub
Release và APK đã ký. Quy ước commit và các secret cần thiết nằm trong
[CONTRIBUTING.md](CONTRIBUTING.md).

## Thứ tự chạy đề xuất

Rebuild toàn bộ từ đầu:

```powershell
python -m crawler.main
python -m enrichment.enrich_cheatsheets
python -m enrichment.translate
python -m enrichment.enrich_vi
python -m learning.embeddings build --provider openai --lang all
```

Phát triển local, không gọi API:

```powershell
python -m crawler.main
python -m learning.embeddings build --provider hash --lang all
python -m learning.study draw --user-id local --lang vi --mode random
```

Build lại app Android sau khi dữ liệu đổi:

```powershell
python -m learning.embeddings build --provider hash --lang all
python mobile/tools/prepare_assets.py
cd mobile
flutter test
flutter build apk --release --split-per-abi
```

## Kiểm tra output

```powershell
python -c "import json; data=json.load(open('data/output/tarot_meanings.json', encoding='utf-8')); print(len(data), data[0]['name'])"
python -c "import json; data=json.load(open('data/embeddings/tarot_embeddings_vi.json', encoding='utf-8')); print(data['chunk_count'])"
```

## Bố cục dữ liệu

Có commit trong repo:

- `data/output/`: JSON nghĩa bài tiếng Anh và tiếng Việt.
- `data/images/`: ảnh lá bài, bot dùng và app đóng gói vào APK.

Sinh ra ở local và trong CI, git bỏ qua:

- `data/embeddings/`: embedding index dùng để search và chấm bài.
- `mobile/assets/`: asset bundle của Flutter, dựng từ `data/output` và `data/images`.

File làm việc chỉ có ở local, cũng bị bỏ qua:

- `data/raw/`: cache HTML Labyrinthos.
- `data/cheatsheets/`: ảnh cheatsheet Labyrinthos.
- `data/bot_state/`: state học bài theo user.

Các CLI trong `learning` tự cấu hình stdout/stderr UTF-8 để in tiếng Việt ổn
định trên Windows PowerShell.

## Tham chiếu biến môi trường

`.env.example` liệt kê các biến môi trường chính. Ứng dụng không tự load `.env`,
nên trên PowerShell cần set biến bằng `$env:...` trước khi chạy. Docker Compose
thì có đọc `.env`.
