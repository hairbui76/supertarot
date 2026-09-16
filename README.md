# SuperTarot

SuperTarot hiện là bộ CLI Python và Telegram bot runtime để tạo dữ liệu nghĩa 78 lá tarot, enrich dữ liệu, build embedding index, rút câu hỏi học bài và chấm câu trả lời.

## Module chính

```text
supertarot/
├── crawler/       # Chỉ chịu trách nhiệm crawl, parse, ghi JSON gốc
├── enrichment/    # Dịch, enrich cheatsheet, tải ảnh tham chiếu
├── learning/      # Embedding, study session, verification prompt
├── app/           # Runtime ứng dụng Telegram bot
├── mobile/        # Ứng dụng Android (Flutter), dùng chung dữ liệu, chạy offline
├── data/          # Cache HTML, ảnh, JSON output, embedding index, state học bài
└── tarot-meaning-links.json
```

`crawler` vẫn có một số wrapper tương thích cho lệnh cũ như `python -m crawler.embeddings`, nhưng cách chạy mới nên dùng `learning.*` và `enrichment.*`.

## Cài đặt

Chạy từ thư mục repo:

```powershell
cd D:\github\supertarot
py -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

Nếu dùng API thật:

```powershell
$env:OPENAI_API_KEY="..."
$env:ANTHROPIC_API_KEY="..."
```

`OPENAI_API_KEY` chỉ cần khi build embedding bằng OpenAI hoặc khi chọn provider OpenAI cho Q&A/grading. `ANTHROPIC_API_KEY` cần khi chạy các script dịch/enrich bằng Claude hoặc khi chọn provider Anthropic. `GOOGLE_API_KEY` hoặc `GEMINI_API_KEY` cần khi chọn provider Google/Gemini.

## Chạy như một ứng dụng Telegram bot

Tạo bot Telegram bằng BotFather, lấy token rồi cấu hình biến môi trường:

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
- `auto`: chọn theo key đang có, ưu tiên OpenAI, sau đó Anthropic, sau đó Google.
- `context` chỉ dành cho Q&A: không gọi LLM, chỉ trả các mảnh dữ liệu liên quan.
- `prompt` chỉ dành cho grading: không gọi LLM, chỉ tạo prompt/chunk để debug.

Model env tương ứng:

```powershell
$env:OPENAI_CHAT_MODEL="gpt-4.1-mini"
$env:ANTHROPIC_CHAT_MODEL="claude-haiku-4-5-20251001"
$env:GOOGLE_CHAT_MODEL="gemini-2.5-flash"
```

Kiểm tra dữ liệu local trước khi chạy bot:

```powershell
python -m app --check
```

Nếu chọn provider LLM nhưng bot vẫn trả về context fallback, kiểm tra `python -m app --check`. Các trường `python_packages` và API key redacted phải phù hợp với provider đang chọn; nếu thiếu package, chạy lại:

```powershell
python -m pip install -r requirements.txt
```

Nếu chạy bằng Docker, rebuild/recreate container sau khi sửa `.env` hoặc dependency:

```powershell
docker compose up -d --build --force-recreate
```

Chạy ứng dụng:

```powershell
python -m app
```

## Chạy bằng Docker

Repo đã có sẵn `Dockerfile` và `docker-compose.yml` cho runtime Telegram bot.

Build và chạy:

```powershell
docker compose up --build -d
```

Dừng container:

```powershell
docker compose down
```

Kiểm tra log:

```powershell
docker compose logs -f supertarot-bot
```

Compose sẽ:

- đọc biến môi trường từ `.env`
- mount `./data` vào `/app/data` để giữ state, output và embeddings
- chạy bot bằng lệnh `python -m app`

### Chạy trực tiếp từ Docker image

Nếu đã push image lên registry, có thể chạy trực tiếp mà không cần build local.

Pull image:

```powershell
docker pull hairbui76/supertarot
```

Chạy container từ image:

```powershell
docker run -d \
	--name supertarot-bot \
	--restart unless-stopped \
	--env-file .env \
	-v ${PWD}/data:/app/data \
	hairbui76/supertarot
```

Xem log:

```powershell
docker logs -f supertarot-bot
```

Dừng và xóa container:

```powershell
docker rm -f supertarot-bot
```

Nếu dùng PowerShell mà `${PWD}` không mount đúng, thay bằng đường dẫn tuyệt đối, ví dụ:

```powershell
docker run -d \
	--name supertarot-bot \
	--restart unless-stopped \
	--env-file .env \
	-v D:/github/supertarot/data:/app/data \
	hairbui76/supertarot
```

Bot dùng long polling qua Telegram Bot API, không cần webhook. Các lệnh bot đang hỗ trợ:

- `/start` hoặc `/help`: xem hướng dẫn.
- `/random`: rút một câu hỏi học bài ngẫu nhiên, kèm gợi ý ngắn.
- `/daily`: rút một câu hỏi daily ngay, kèm gợi ý ngắn.
- `/learn [tên lá bài]`: xem tóm tắt lá bài, rồi bấm `⬆️ Xuôi` hoặc `⬇️ Ngược` để mở chi tiết theo chiều.
- `/ask câu hỏi`: hỏi đáp tarot bằng dữ liệu embedding.
- `/menu`: mở menu nút Telegram.
- `/schedule HH:MM`: gửi daily tự động mỗi ngày, ví dụ `/schedule 08:30`.
- `/unschedule`: tắt daily tự động.
- `/answer nội dung`: trả lời câu hỏi đang mở để bot chấm.
- `/lang vi` hoặc `/lang en`: đổi ngôn ngữ dữ liệu.
- `/status`: xem trạng thái chat hiện tại.

State ứng dụng lưu tại `data/bot_state/telegram_bot_state.json`; state vòng học 78 lá/user vẫn lưu tại `data/bot_state/study_state.json`.

Nếu chưa có API key cho provider đã chọn, bot vẫn rút bài và nhận câu trả lời; Q&A sẽ fallback về dữ liệu liên quan, còn grading có thể dùng `SUPERTAROT_GRADING_PROVIDER=prompt` để debug prompt. Muốn Q&A/grading tự động bằng LLM, cần cấu hình một trong các key OpenAI, Anthropic hoặc Google/Gemini và embedding index đã build bằng `learning.embeddings`.

Text thường không kèm command được hiểu là Tarot Q&A. Bot sẽ retrieve từ embedding index rồi xâu chuỗi các mảnh liên quan để giải nghĩa tarot, có thể liên hệ nghĩa xuôi/ngược, biểu tượng, nguyên tố, chiêm tinh và yes/no. Nếu muốn chấm câu trả lời học bài sau `/random` hoặc `/daily`, dùng `/answer ...` để bot không nhầm với Q&A.

Để tránh Telegram tự xổ menu sau mỗi tin nhắn, các phản hồi thường sẽ gửi `remove_keyboard`. Menu nút chỉ mở khi dùng `/menu`, `/start`, `/help`, hoặc khi bot cần bạn chọn trong flow `/learn`. Khi gọi `/help`, `/start`, hoặc `/menu`, bot xóa trạng thái chọn bài đang dở và quay về menu chính.

Trong lúc Q&A hoặc grading đang xử lý, bot giữ trạng thái `typing...` bằng cách gửi lại `sendChatAction` định kỳ cho tới khi có phản hồi. Câu trả lời Q&A dùng `parse_mode=HTML`; bot tự đổi Markdown như `**in đậm**` sang `<b>in đậm</b>`, đổi bullet `*`/`-` sang `•`, và không gắn thêm phần Lưu ý/Tham chiếu ở cuối.

Trong flow `/learn`, tin nhắn tóm tắt lá bài có hai nút inline `⬆️ Xuôi` và `⬇️ Ngược`; mỗi nút mở riêng phần keyword, ý nghĩa và các mục love/career/finances/feelings/actions của đúng chiều đó.

## Chạy nhanh local

Các file cache/output hiện đã có sẵn trong `data/`, nên có thể smoke test không cần API key:

```powershell
python -m learning.embeddings search --lang vi --query "tình yêu mới" --top-k 3
python -m learning.study draw --user-id local --lang vi --mode random
python -m learning.verification prompt --lang vi --card-name "Ace of Cups" --facet upright.love --answer "tình yêu mới mở lòng và nhiều cảm xúc"
```

## 1. Crawler module

Module này đọc `tarot-meaning-links.json`, fetch/cache HTML, parse dữ liệu Labyrinthos và ghi JSON tiếng Anh.

```powershell
python -m crawler.main
```

Output:

```text
data/output/tarot_meanings.json
data/raw/*.html
data/cheatsheets/*.png
```

Các file quan trọng:

- `crawler/fetch.py`: tải HTML, retry, cache vào `data/raw`.
- `crawler/parser.py`: parse HTML thành `TarotCard`.
- `crawler/models.py`: dataclass schema.
- `crawler/reference.py`: type, element, astrology, yes/no lookup.
- `crawler/main.py`: orchestration và ghi `data/output/tarot_meanings.json`.

## 2. Enrichment module

Module này xử lý dữ liệu bổ sung sau khi đã crawl xong.

```powershell
python -m enrichment.download_hoctarot_images
python -m enrichment.enrich_cheatsheets
python -m enrichment.translate
python -m enrichment.enrich_vi
```

Ý nghĩa từng lệnh:

- `download_hoctarot_images`: tải ảnh lá bài từ Hoctarot vào `data/images`.
- `enrich_cheatsheets`: đọc ảnh cheatsheet và thêm `symbols`, facet keywords vào JSON tiếng Anh. Cần `ANTHROPIC_API_KEY`.
- `translate`: dịch `tarot_meanings.json` sang `tarot_meanings_vi.json`. Cần `ANTHROPIC_API_KEY`.
- `enrich_vi`: dịch/merge các trường enrich mới vào JSON tiếng Việt. Cần `ANTHROPIC_API_KEY`.

Nếu chỉ muốn chạy học bài với dữ liệu hiện có, có thể bỏ qua module này.

## 3. Learning module

### Build embedding index

Local smoke test, không cần API key:

```powershell
python -m learning.embeddings build --provider hash --lang all
```

Production embedding bằng OpenAI:

```powershell
python -m learning.embeddings build --provider openai --lang all
```

Output:

```text
data/embeddings/tarot_embeddings_en.json
data/embeddings/tarot_embeddings_vi.json
```

### Search embedding index

```powershell
python -m learning.embeddings search --lang vi --query "tình yêu mới và cảm xúc mở lòng" --top-k 5
```

### Rút câu hỏi học bài

```powershell
python -m learning.study draw --user-id local --lang vi --mode random
python -m learning.study draw --user-id local --lang vi --mode daily
```

State theo user được lưu ở:

```text
data/bot_state/study_state.json
```

Mỗi user có cycle 78 lá riêng; trong một cycle không rút trùng lá.

### Tạo prompt chấm câu trả lời

```powershell
python -m learning.verification prompt --lang vi --card-name "Ace of Cups" --facet upright.love --answer "tình yêu mới, mở lòng, cảm xúc tích cực"
```

Lệnh CLI này chỉ tạo prompt JSON-grading cho GPT. Runtime Telegram trong `app/` có thể gọi OpenAI để chấm tự động khi cấu hình `OPENAI_API_KEY`.

## 4. Ứng dụng Android

App Flutter trong `mobile/` đóng gói 78 lá bài, ảnh và embedding index vào APK. Tra cứu, rút bài học và retrieval chạy offline; chỉ phần diễn giải/chấm bài bằng AI mới cần mạng và API key người dùng tự nhập trong tab Cài đặt.

Cần Flutter stable, Android SDK và JDK 17.

```powershell
python mobile/tools/prepare_assets.py
cd mobile
flutter pub get
flutter test
flutter build apk --release --split-per-abi
```

APK nằm ở `mobile/build/app/outputs/flutter-apk/`; dùng `app-arm64-v8a-release.apk` cho điện thoại Android hiện nay.

Chạy lại `prepare_assets.py` sau mỗi lần dữ liệu tarot hoặc embedding index đổi, nếu không APK sẽ ship dữ liệu cũ. Chi tiết trong `mobile/README.md`.

## Thứ tự chạy đề xuất

Khi cần rebuild toàn bộ dữ liệu từ đầu:

```powershell
python -m crawler.main
python -m enrichment.enrich_cheatsheets
python -m enrichment.translate
python -m enrichment.enrich_vi
python -m learning.embeddings build --provider openai --lang all
```

Khi chỉ phát triển local, không muốn gọi API:

```powershell
python -m crawler.main
python -m learning.embeddings build --provider hash --lang all
python -m learning.study draw --user-id local --lang vi --mode random
```

Khi build lại app Android sau khi dữ liệu đổi:

```powershell
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

## Ghi chú dữ liệu

- `data/raw/`: HTML cache từ Labyrinthos.
- `data/output/`: JSON nghĩa bài tiếng Anh/Việt.
- `data/images/`: ảnh lá bài.
- `data/cheatsheets/`: ảnh cheatsheet Labyrinthos.
- `data/embeddings/`: embedding index để search/verify.
- `data/bot_state/`: state học bài theo user.

CLI trong `learning` tự cấu hình stdout/stderr UTF-8 để in tiếng Việt ổn định trên Windows PowerShell.

## Cấu hình môi trường mẫu

Repo có file `.env.example` để xem các biến môi trường chính. Ứng dụng hiện không tự load `.env`, nên trên PowerShell cần set biến bằng `$env:...` trước khi chạy.
