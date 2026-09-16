# SuperTarot Mobile (Android)

Flutter app đóng gói toàn bộ dữ liệu tarot của repo vào APK. Tra cứu 78 lá,
rút bài học, và retrieval đều chạy offline; chỉ phần diễn giải/chấm bài bằng
AI mới cần mạng và API key do người dùng tự nhập.

## Tính năng

| Tab | Cần API key | Mô tả |
| --- | --- | --- |
| Tra cứu | Không | Duyệt theo bộ đúng thứ tự tarot, tìm theo tên, xem ảnh lá bài, correspondences, biểu tượng, nghĩa xuôi/ngược đầy đủ. |
| Học bài | Chỉ khi chấm | Rút một lá + một facet cụ thể, không lặp lá trong vòng 78 lá. Nhập câu trả lời rồi chấm theo rubric JSON. |
| Hỏi đáp | Có | Hỏi tự do; app retrieve chunk từ embedding index trong máy rồi nhờ LLM tổng hợp. |
| Cài đặt | — | Ngôn ngữ (vi/en), provider cho Q&A và chấm bài, API key + model từng provider, số chunk retrieve. |

API key lưu bằng `flutter_secure_storage` (Android EncryptedSharedPreferences),
chỉ nằm trên máy, và app gọi thẳng tới OpenAI / Anthropic / Google — không có
máy chủ trung gian.

## Yêu cầu

- Flutter stable (đã kiểm với 3.41.9)
- Android SDK + JDK 17
- Python 3.10+ ở repo gốc (để sinh assets)

## Sinh assets từ dữ liệu repo

Chạy từ thư mục gốc của repo, **bắt buộc** sau mỗi lần dữ liệu tarot hoặc
embedding index thay đổi:

```bash
python mobile/tools/prepare_assets.py
```

Script này ghi vào `mobile/assets/`:

- `data/cards_{en,vi}.json` — 78 lá đã sort theo thứ tự bộ bài, VI đã backfill
  metadata từ EN.
- `data/index_{en,vi}.json` — metadata chunk (id, card, orientation, facet,
  title, text), không kèm vector.
- `data/index_{en,vi}.f32` — vector float32 little-endian, phẳng, `n × dims`.
  Tách nhị phân để app không phải parse ~1.2 triệu số JSON lúc khởi động.
- `images/*.jpg` — 78 ảnh lá bài.

Tổng bundle ~16 MB.

## Chạy và build

```bash
cd mobile
flutter pub get
flutter test                       # 17 test: parity embedding, thứ tự bộ bài, assets
flutter run                        # chạy trên máy/emulator đang kết nối
flutter build apk --release --split-per-abi
```

APK nằm ở `mobile/build/app/outputs/flutter-apk/`:

- `app-arm64-v8a-release.apk` (~26 MB) — hầu hết điện thoại Android hiện nay
- `app-armeabi-v7a-release.apk` (~24 MB) — máy 32-bit cũ
- `app-x86_64-release.apk` (~27 MB) — emulator

`flutter build apk --release` (không `--split-per-abi`) tạo APK fat ~57 MB
chứa cả ba ABI.

## Ký release

Cấu hình ký đọc từ `android/key.properties`, file này cùng `*.jks` bị
`.gitignore` loại trừ. Nếu thiếu, build release tự quay về debug key — vẫn cài
sideload được nhưng không publish hay update in-place được.

```bash
keytool -genkeypair -v -keystore android/supertarot-release.jks \
  -storetype PKCS12 -keyalg RSA -keysize 2048 -validity 10000 -alias supertarot
```

```properties
# android/key.properties
storePassword=...
keyPassword=...
keyAlias=supertarot
storeFile=../supertarot-release.jks
```

Giữ keystore cẩn thận: mất nó thì không thể update app đã cài bằng key cũ.

## Kiến trúc

```text
lib/
├── main.dart                        # entry point, dựng AppServices rồi runApp
└── src/
    ├── app_scope.dart               # AppServices + InheritedNotifier cho SettingsStore
    ├── theme.dart                   # Material 3, seed tím + accent vàng, light/dark
    ├── l10n/strings.dart            # copy UI cho vi/en
    ├── models/
    │   ├── deck_order.dart          # port của learning/deck_order.py
    │   ├── tarot_card.dart          # schema lá bài
    │   ├── reference_chunk.dart     # chunk đã retrieve + score
    │   └── study_draw.dart          # StudyDraw và GradeResult
    ├── data/
    │   ├── hash_embedder.dart       # port của HashEmbeddingProvider
    │   ├── embedding_index.dart     # load .json + .f32, cosine search có filter
    │   ├── tarot_repository.dart    # cache card/index theo ngôn ngữ, định nghĩa bộ bài
    │   └── settings_store.dart      # prefs + secure storage cho API key
    ├── services/
    │   ├── llm_client.dart          # REST adapter OpenAI/Anthropic/Google
    │   ├── study_service.dart       # port của learning/study.py
    │   ├── grading_service.dart     # port của learning/verification.py + app/grading.py
    │   └── qa_service.dart          # port của app/qa.py
    ├── screens/                     # home (4 tab), browse, card detail, study, ask, settings
    └── widgets/section_block.dart   # SectionBlock, MarkupText, InfoChip
```

## Ràng buộc parity với Python

`HashEmbedder` phải sinh vector **giống hệt** `HashEmbeddingProvider` trong
`learning/embeddings.py`, nếu không vector truy vấn sẽ không cùng không gian
với index đã bundle. Hai điểm dễ sai:

- Python `re.findall(r"\w+", ...)` theo Unicode; `\w` của Dart chỉ ASCII nên
  phải viết rõ `[\p{L}\p{N}_]+` để tách tiếng Việt giống nhau.
- `int.from_bytes(digest, "big")` là số 64-bit không dấu, không vừa `int` có
  dấu của Dart; phải lấy modulo theo từng byte thay vì ép kiểu.

`test/hash_embedder_test.dart` chốt parity bằng vector tham chiếu sinh từ
Python. Nếu test đó đỏ, đừng sửa kỳ vọng — sửa code.

## Lưu ý về chất lượng retrieval

Index đang bundle được build bằng provider `hash` (`hash-word-v1`), tức là
bag-of-words chứ không phải semantic thật. Truy vấn một lá có thể trả về lá
anh em trước (`Queen of Cups` → `Knight of Cups`) — app và bot Telegram đều
như vậy vì dùng chung index. Muốn tốt hơn thì build lại index bằng OpenAI rồi
chạy lại `prepare_assets.py`:

```bash
python -m learning.embeddings build --provider openai --lang all
python mobile/tools/prepare_assets.py
```

Lưu ý khi đó vector query phải gọi API embedding thay vì hash — hiện app chưa
làm việc này, nên đổi provider index sẽ cần thêm bước ở `EmbeddingIndex`.
