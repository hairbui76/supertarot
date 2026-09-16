# Quy ước commit và phát hành

Repo dùng [release-please](https://github.com/googleapis/release-please) để tự
động bump version, sinh `CHANGELOG.md`, tạo GitHub Release và đính kèm APK.
Toàn bộ cơ chế đó chạy dựa trên **message của commit**, nên phần này là bắt
buộc chứ không phải khuyến khích.

## Conventional Commits

```text
<type>(<scope>)!: <mô tả ngắn>

<thân bài tuỳ chọn>

<footer tuỳ chọn>
```

| `type` | Tác dụng lên version | Hiện trong CHANGELOG |
| ------ | -------------------- | -------------------- |
| `feat` | minor (1.2.0 → 1.3.0) | Features |
| `fix` | patch (1.2.0 → 1.2.1) | Bug Fixes |
| `perf` | patch | Performance |
| `data` | patch | Tarot Data |
| `refactor`, `docs`, `chore`, `test`, `ci` | không bump | ẩn |

Breaking change bump major: thêm `!` sau type/scope, hoặc footer
`BREAKING CHANGE: ...`.

```text
feat(mobile): thêm tab trải bài 3 lá
fix(telegram): sắp lá bài trong /learn theo thứ tự bộ bài
data: dịch lại trường astrology cho bộ Cốc
feat(app)!: bỏ SUPERTAROT_QA_PROVIDER=context
```

Scope hay dùng: `mobile`, `telegram`, `crawler`, `enrichment`, `learning`,
`data`, `ci`.

## Luồng phát hành

1. Merge commit vào `main`.
2. release-please mở/ cập nhật một PR tên `chore(main): release X.Y.Z`, trong
   đó đã bump `version.txt`, `mobile/pubspec.yaml` và viết `CHANGELOG.md`.
3. Merge PR đó → tạo tag `vX.Y.Z` và GitHub Release.
4. Job `apk` build và đính 3 file APK vào Release:
   `supertarot-X.Y.Z-arm64-v8a.apk`, `-armeabi-v7a`, `-x86_64`.

Không release nếu từ lần release trước chỉ có commit thuộc nhóm không bump.

Muốn ép một số version cụ thể, thêm footer vào commit:

```text
Release-As: 2.0.0
```

## versionCode của Android

`mobile/android/app/build.gradle.kts` suy ra `versionCode` từ semver:
`1.2.3` → `(1×10000 + 2×100 + 3) × 10000 = 102030000`.

Bốn chữ số cuối để trống có chủ đích: `--split-per-abi` khiến Flutter cộng
thêm `abiCode × 1000` (armeabi-v7a 1, arm64-v8a 2, x86_64 4). Nếu đánh số dày
hơn thì hai release khác nhau có thể trùng `versionCode`. Giới hạn: major ≤ 20,
minor và patch ≤ 99.

Không sửa `versionCode` bằng tay, và không sửa dòng version trong
`mobile/pubspec.yaml` — release-please ghi đè theo marker
`# x-release-please-version`.

## Secrets cần có trong repo

Job `apk` sẽ fail nếu thiếu `ANDROID_KEYSTORE_BASE64`, vì APK ký bằng debug key
tạm thời sẽ khiến người dùng không update chồng lên bản cũ được.

| Secret | Nội dung |
| ------ | -------- |
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 mobile/android/supertarot-release.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | mật khẩu store |
| `ANDROID_KEY_PASSWORD` | mật khẩu key |
| `ANDROID_KEY_ALIAS` | alias của key |

```bash
gh secret set ANDROID_KEYSTORE_BASE64 < <(base64 -w0 mobile/android/supertarot-release.jks)
gh secret set ANDROID_KEYSTORE_PASSWORD
gh secret set ANDROID_KEY_PASSWORD
gh secret set ANDROID_KEY_ALIAS
```

Keystore và `key.properties` nằm ngoài git. Mất keystore là mất khả năng update
app đã cài — hãy backup riêng.

## Dữ liệu sinh ra không nằm trong git

`data/embeddings/` và `mobile/assets/` được sinh lại trong CI từ `data/output/`
và `data/images/`:

```bash
python -m learning.embeddings build --provider hash --lang all
python mobile/tools/prepare_assets.py
```

Cả hai bước chỉ cần Python chuẩn, không cần dependency hay API key. Nhờ vậy
index không bao giờ lệch với JSON nguồn.

Nếu chuyển sang embedding OpenAI thì CI phải thêm `OPENAI_API_KEY` và app cần
gọi API embedding cho câu truy vấn thay vì hash — xem `mobile/README.md`.
