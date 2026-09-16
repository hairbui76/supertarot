# SuperTarot Mobile (Android)

*Read this in [Tiếng Việt](README.vi.md).*

A Flutter app that bundles the repository's entire tarot dataset into the APK.
Browsing all 78 cards, drawing study questions, and retrieval all run offline;
only AI explanation and grading need the network and an API key the user enters
themselves.

## Features

| Tab | Needs an API key | What it does |
| --- | --- | --- |
| Browse | No | Walk each suit in traditional deck order, search by name, view card art, correspondences, symbols, and the full upright/reversed meanings. |
| Study | Only to grade | Draw one card and one specific facet, never repeating a card within a cycle of 78. Write an answer and have it graded against a JSON rubric. |
| Ask | Yes | Freeform questions; the app retrieves chunks from the on-device embedding index, then asks an LLM to synthesize. |
| Settings | — | Language (vi/en), providers for Q&A and grading, API key and model per provider, retrieval depth. |

API keys are stored with `flutter_secure_storage` (Android
EncryptedSharedPreferences), never leave the device, and the app calls OpenAI,
Anthropic, or Google directly — there is no server in between.

## Requirements

- Flutter stable (verified with 3.41.9)
- Android SDK and JDK 17
- Python 3.10+ at the repository root, to generate the assets

## Generate the assets

Run from the repository root. This is **required** after any change to the tarot
data or the embedding index:

```bash
python -m learning.embeddings build --provider hash --lang all
python mobile/tools/prepare_assets.py
```

Neither step needs third-party packages or an API key.

`prepare_assets.py` writes into `mobile/assets/`:

- `data/cards_{en,vi}.json` — all 78 cards in deck order, with the Vietnamese
  set backfilled with metadata from the English one.
- `data/index_{en,vi}.json` — chunk metadata (id, card, orientation, facet,
  title, text), without vectors.
- `data/index_{en,vi}.f32` — a flat little-endian float32 blob, `n × dims`.
  Keeping the vectors binary means startup does not parse ~1.2 million JSON
  numbers.
- `images/*.jpg` — the 78 card images.

The bundle is roughly 16 MB. It is generated, so it is not committed.

## Run and build

```bash
cd mobile
flutter pub get
flutter test                       # 17 tests: embedding parity, deck order, assets
flutter run                        # on a connected device or emulator
flutter build apk --release --split-per-abi
```

APKs land in `mobile/build/app/outputs/flutter-apk/`:

- `app-arm64-v8a-release.apk` (~26 MB) — current Android phones
- `app-armeabi-v7a-release.apk` (~24 MB) — older 32-bit devices
- `app-x86_64-release.apk` (~27 MB) — emulators

`flutter build apk --release` without `--split-per-abi` produces a single fat
APK of about 57 MB containing all three ABIs.

## Release signing

Signing is read from `android/key.properties`, which along with `*.jks` is
excluded by `.gitignore`. Without it a release build falls back to the debug
key — still sideloadable, but not publishable and not upgradable in place.

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

Keep the keystore safe: losing it means you can no longer update an app that
was installed with it.

CI signs releases from repository secrets — see
[CONTRIBUTING.md](../CONTRIBUTING.md).

## Versioning

`pubspec.yaml` carries `version: X.Y.Z # x-release-please-version` and is
rewritten by release-please. Do not edit that line by hand.

`android/app/build.gradle.kts` derives `versionCode` from the semver:
`1.2.3` → `(1×10000 + 2×100 + 3) × 10000 = 102030000`.

The bottom four digits are deliberately left at zero: `--split-per-abi` makes
Flutter add `abiCode × 1000` (armeabi-v7a 1, arm64-v8a 2, x86_64 4) so each ABI
gets a distinct code. Numbering any finer would let two different releases share
a `versionCode`. Limits: major ≤ 20, minor and patch ≤ 99.

## Architecture

```text
lib/
├── main.dart                        # entry point: build AppServices, then runApp
└── src/
    ├── app_scope.dart               # AppServices + InheritedNotifier for SettingsStore
    ├── theme.dart                   # Material 3, violet seed with gold accent, light/dark
    ├── l10n/strings.dart            # UI copy for vi/en
    ├── models/
    │   ├── deck_order.dart          # port of learning/deck_order.py
    │   ├── tarot_card.dart          # card schema
    │   ├── reference_chunk.dart     # a retrieved chunk plus its score
    │   └── study_draw.dart          # StudyDraw and GradeResult
    ├── data/
    │   ├── hash_embedder.dart       # port of HashEmbeddingProvider
    │   ├── embedding_index.dart     # loads .json + .f32, filtered cosine search
    │   ├── tarot_repository.dart    # per-language cache, suit definitions
    │   └── settings_store.dart      # prefs plus secure storage for API keys
    ├── services/
    │   ├── llm_client.dart          # REST adapters for OpenAI/Anthropic/Google
    │   ├── study_service.dart       # port of learning/study.py
    │   ├── grading_service.dart     # port of learning/verification.py + app/grading.py
    │   └── qa_service.dart          # port of app/qa.py
    ├── screens/                     # home (4 tabs), browse, card detail, study, ask, settings
    └── widgets/section_block.dart   # SectionBlock, MarkupText, InfoChip
```

## Parity with the Python side

`HashEmbedder` must produce **exactly** the same vectors as
`HashEmbeddingProvider` in `learning/embeddings.py`, or query vectors will not
share a space with the bundled index. Two things are easy to get wrong:

- Python's `re.findall(r"\w+", ...)` is Unicode-aware; Dart's `\w` is ASCII
  only, so the classes are spelled out as `[\p{L}\p{N}_]+` to tokenize
  Vietnamese identically.
- `int.from_bytes(digest, "big")` is an unsigned 64-bit value that does not fit
  a signed Dart `int`, so the modulo is taken byte by byte instead of casting.

`test/hash_embedder_test.dart` pins this with reference vectors generated from
Python. If that test goes red, fix the code, not the expectation.

## A note on retrieval quality

The bundled index is built with the `hash` provider (`hash-word-v1`), which is
bag-of-words rather than genuinely semantic. Querying one card can surface a
sibling first (`Queen of Cups` → `Knight of Cups`); the Telegram bot behaves the
same way because it uses the same index. For better results, rebuild with
OpenAI and regenerate the assets:

```bash
python -m learning.embeddings build --provider openai --lang all
python mobile/tools/prepare_assets.py
```

Note that query vectors would then have to come from the embedding API rather
than the hash function. The app does not do that yet, so switching the index
provider needs an additional step in `EmbeddingIndex`.
