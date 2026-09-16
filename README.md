# SuperTarot

*Read this in [Tiếng Việt](README.vi.md).*

SuperTarot is a Python toolchain, a Telegram study bot, and an offline Android
app built around the meanings of all 78 tarot cards. It crawls and enriches the
card data, builds an embedding index, draws study questions, and grades your
answers against the source material.

## Modules

```text
supertarot/
├── crawler/       # Crawl, parse, and write the source JSON
├── enrichment/    # Translation, cheatsheet enrichment, reference images
├── learning/      # Embedding index, study sessions, verification prompts
├── app/           # Telegram bot runtime
├── mobile/        # Android app (Flutter), same data, runs offline
├── web/          # Static Astro site, deployed to GitHub Pages
├── .github/       # CI and automated releases via release-please
├── data/          # HTML cache, images, JSON output, embeddings, bot state
└── tarot-meaning-links.json
```

`crawler` still ships compatibility wrappers for old entry points such as
`python -m crawler.embeddings`, but new work should use `learning.*` and
`enrichment.*`.

## Install

From the repository root:

```powershell
py -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

When calling real APIs:

```powershell
$env:OPENAI_API_KEY="..."
$env:ANTHROPIC_API_KEY="..."
```

`OPENAI_API_KEY` is only needed to build embeddings with OpenAI or to pick the
OpenAI provider for Q&A and grading. `ANTHROPIC_API_KEY` is needed for the
Claude-based translation and enrichment scripts, or for the Anthropic provider.
`GOOGLE_API_KEY` or `GEMINI_API_KEY` is needed for the Google/Gemini provider.

## Generate the local data

`data/embeddings/` is generated, not committed. Build it once before running
anything that searches or grades — the `hash` provider is deterministic and
needs no API key:

```powershell
python -m learning.embeddings build --provider hash --lang all
```

## Run the Telegram bot

Create a bot with BotFather, then configure the environment:

```powershell
$env:TELEGRAM_BOT_TOKEN="123456:telegram_token"
$env:SUPERTAROT_LANGUAGE="vi"
$env:SUPERTAROT_TIMEZONE="Asia/Saigon"
$env:SUPERTAROT_GRADING_PROVIDER="auto"
$env:SUPERTAROT_QA_PROVIDER="auto"
$env:OPENAI_API_KEY="..."
```

Valid providers:

- `SUPERTAROT_QA_PROVIDER`: `auto`, `openai`, `anthropic`, `google`, `context`.
- `SUPERTAROT_GRADING_PROVIDER`: `auto`, `openai`, `anthropic`, `google`, `prompt`.
- `auto` picks the first provider that has a key: OpenAI, then Anthropic, then Google.
- `context` is Q&A only: no LLM call, just the matching reference material.
- `prompt` is grading only: no LLM call, just the prompt and chunks, for debugging.

Matching model variables:

```powershell
$env:OPENAI_CHAT_MODEL="gpt-4.1-mini"
$env:ANTHROPIC_CHAT_MODEL="claude-haiku-4-5-20251001"
$env:GOOGLE_CHAT_MODEL="gemini-2.5-flash"
```

Check the local setup before starting the bot:

```powershell
python -m app --check
```

If you selected an LLM provider but the bot still falls back to context, re-read
that output: the `python_packages` block and the redacted API keys must match
the provider you chose. Reinstall if a package is missing:

```powershell
python -m pip install -r requirements.txt
```

Start the bot:

```powershell
python -m app
```

### Bot commands

The bot uses long polling, so no webhook is required.

- `/start` or `/help`: usage.
- `/random`: draw a random study question with a short hint.
- `/daily`: draw today's question immediately.
- `/learn [card name]`: card summary, then `⬆️ Upright` or `⬇️ Reversed` for detail.
- `/ask <question>`: freeform tarot Q&A over the embedding index.
- `/menu`: open the Telegram button menu.
- `/schedule HH:MM`: send a daily draw, e.g. `/schedule 08:30`.
- `/unschedule`: turn the daily draw off.
- `/answer <text>`: answer the open question so the bot can grade it.
- `/lang vi` or `/lang en`: switch the data language.
- `/status`: current chat state.

Card lists in `/learn` follow traditional deck order — Major Arcana 0–21, then
each suit from Ace through King — not alphabetical order.

App state lives in `data/bot_state/telegram_bot_state.json`; each user's 78-card
study cycle lives in `data/bot_state/study_state.json`.

Without an API key the bot still draws cards and accepts answers: Q&A falls back
to the matching reference material, and grading can use
`SUPERTAROT_GRADING_PROVIDER=prompt` to inspect the prompt.

A plain message with no command is treated as tarot Q&A. To have an answer
graded after `/random` or `/daily`, use `/answer ...` so it is not mistaken for
a question.

Ordinary replies send `remove_keyboard` so Telegram does not pop the menu open
after every message. The button menu appears only for `/menu`, `/start`,
`/help`, or when the `/learn` flow needs a choice. While Q&A or grading is
running, the bot keeps a `typing...` indicator alive until the reply is ready.

### Run with Docker

```powershell
docker compose up --build -d
docker compose logs -f supertarot-bot
docker compose down
```

Compose reads `.env`, mounts `./data` into `/app/data` so state and output
persist, and runs `python -m app`. Rebuild and recreate after changing `.env`
or dependencies:

```powershell
docker compose up -d --build --force-recreate
```

To run a published image instead of building locally:

```powershell
docker pull hairbui76/supertarot
docker run -d \
	--name supertarot-bot \
	--restart unless-stopped \
	--env-file .env \
	-v ${PWD}/data:/app/data \
	hairbui76/supertarot
```

If `${PWD}` does not mount correctly in PowerShell, use an absolute path.

## Quick local smoke test

After building the index, none of this needs an API key:

```powershell
python -m learning.embeddings search --lang vi --query "tình yêu mới" --top-k 3
python -m learning.study draw --user-id local --lang vi --mode random
python -m learning.verification prompt --lang vi --card-name "Ace of Cups" --facet upright.love --answer "tình yêu mới mở lòng và nhiều cảm xúc"
```

## 1. Crawler

Reads `tarot-meaning-links.json`, fetches and caches HTML, parses the
Labyrinthos pages, and writes the English JSON.

```powershell
python -m crawler.main
```

Output:

```text
data/output/tarot_meanings.json
data/raw/*.html
data/cheatsheets/*.png
```

- `crawler/fetch.py`: download, retry, cache into `data/raw`.
- `crawler/parser.py`: parse HTML into `TarotCard`.
- `crawler/models.py`: dataclass schema.
- `crawler/reference.py`: type, element, astrology, and yes/no lookups.
- `crawler/main.py`: orchestration and JSON output.

## 2. Enrichment

Post-processing once the crawl is done.

```powershell
python -m enrichment.download_hoctarot_images
python -m enrichment.enrich_cheatsheets
python -m enrichment.translate
python -m enrichment.enrich_vi
```

- `download_hoctarot_images`: fetch card art from Hoctarot into `data/images`.
- `enrich_cheatsheets`: read the cheatsheet images and add `symbols` plus facet
  keywords to the English JSON. Needs `ANTHROPIC_API_KEY`.
- `translate`: translate `tarot_meanings.json` into `tarot_meanings_vi.json`.
  Needs `ANTHROPIC_API_KEY`.
- `enrich_vi`: translate and merge new enrichment fields into the Vietnamese
  JSON. Needs `ANTHROPIC_API_KEY`.

Skip this module entirely if you only want to study with the existing data.

## 3. Learning

### Build the embedding index

Offline smoke test, no API key:

```powershell
python -m learning.embeddings build --provider hash --lang all
```

Production embeddings via OpenAI:

```powershell
python -m learning.embeddings build --provider openai --lang all
```

Output:

```text
data/embeddings/tarot_embeddings_en.json
data/embeddings/tarot_embeddings_vi.json
```

### Search the index

```powershell
python -m learning.embeddings search --lang vi --query "tình yêu mới và cảm xúc mở lòng" --top-k 5
```

### Draw a study question

```powershell
python -m learning.study draw --user-id local --lang vi --mode random
python -m learning.study draw --user-id local --lang vi --mode daily
```

Per-user state is stored in `data/bot_state/study_state.json`. Each user walks
their own 78-card cycle and never sees the same card twice within one cycle.

### Build a grading prompt

```powershell
python -m learning.verification prompt --lang vi --card-name "Ace of Cups" --facet upright.love --answer "tình yêu mới, mở lòng, cảm xúc tích cực"
```

This CLI only produces the JSON-grading prompt. The Telegram runtime in `app/`
calls the configured provider to grade automatically.

## 4. Android app

The Flutter app in `mobile/` bundles all 78 card meanings, the card art, and the
embedding index into the APK. Browsing, drawing, and retrieval run offline; only
AI explanation and grading need the network and an API key, which the user
enters in the app's Settings tab.

Requires Flutter stable, the Android SDK, and JDK 17.

```powershell
python mobile/tools/prepare_assets.py
cd mobile
flutter pub get
flutter test
flutter build apk --release --split-per-abi
```

APKs land in `mobile/build/app/outputs/flutter-apk/`; use
`app-arm64-v8a-release.apk` for current Android phones.

Re-run `prepare_assets.py` whenever the tarot data or the embedding index
changes, otherwise the APK ships stale content. See
[mobile/README.md](mobile/README.md).

## Web

The card meanings are also published as a static site anyone can open in a
browser, with no install and no API key:
[tarot.hairbui76.id.vn](https://tarot.hairbui76.id.vn/).

It browses, searches and draws. Q&A and answer grading stay in the Android app,
because they need an API key.

```powershell
python web/tools/prepare_web_assets.py
cd web
npm install
npm test
npm run build
```

Every push to `main` builds and deploys it through
`.github/workflows/pages.yml`. See [web/README.md](web/README.md).

## Releases

Download the latest APK from
[Releases](https://github.com/hairbui76/supertarot/releases). Every release
attaches three files; use `supertarot-<version>-arm64-v8a.apk` for current
Android phones.

Releases are automated with release-please: commit to `main` using Conventional
Commits, release-please opens a version-bump PR, and merging that PR produces
the tag, the GitHub Release, and the signed APKs. Commit conventions and the
required secrets are documented in [CONTRIBUTING.md](CONTRIBUTING.md).

## Suggested order

Full rebuild from scratch:

```powershell
python -m crawler.main
python -m enrichment.enrich_cheatsheets
python -m enrichment.translate
python -m enrichment.enrich_vi
python -m learning.embeddings build --provider openai --lang all
```

Local development without API calls:

```powershell
python -m crawler.main
python -m learning.embeddings build --provider hash --lang all
python -m learning.study draw --user-id local --lang vi --mode random
```

Rebuilding the Android app after a data change:

```powershell
python -m learning.embeddings build --provider hash --lang all
python mobile/tools/prepare_assets.py
cd mobile
flutter test
flutter build apk --release --split-per-abi
```

## Verify the output

```powershell
python -c "import json; data=json.load(open('data/output/tarot_meanings.json', encoding='utf-8')); print(len(data), data[0]['name'])"
python -c "import json; data=json.load(open('data/embeddings/tarot_embeddings_vi.json', encoding='utf-8')); print(data['chunk_count'])"
```

## Data layout

Committed to the repository:

- `data/output/`: English and Vietnamese card meaning JSON.
- `data/images/`: card art used by the bot and bundled into the app.

Generated locally and in CI, ignored by git:

- `data/embeddings/`: the embedding index used for search and grading.
- `mobile/assets/`: the Flutter asset bundle built from `data/output` and `data/images`.

Local-only working files, also ignored:

- `data/raw/`: cached Labyrinthos HTML.
- `data/cheatsheets/`: Labyrinthos cheatsheet images.
- `data/bot_state/`: per-user study state.

The `learning` CLIs configure UTF-8 stdout and stderr so Vietnamese prints
correctly in Windows PowerShell.

## Environment reference

`.env.example` lists the main environment variables. The app does not load
`.env` itself, so in PowerShell set the variables with `$env:...` before
running. Docker Compose does read `.env`.
