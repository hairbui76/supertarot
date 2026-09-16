"""Export repo data into the Flutter app's asset bundle.

The mobile app ships fully offline: card meanings, card art, and the
embedding index all live inside the APK. Embeddings are rewritten from the
JSON index into a flat little-endian float32 blob so the Dart side can mmap
them into a Float32List instead of parsing ~14MB of JSON numbers on startup.

Usage:
    python mobile/tools/prepare_assets.py
"""

from __future__ import annotations

import json
import shutil
import struct
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT))

from app.learn import load_cards_for_language  # noqa: E402
from learning.deck_order import sort_cards  # noqa: E402
from learning.embeddings import default_index_path, load_index  # noqa: E402

ASSET_ROOT = PROJECT_ROOT / "mobile" / "assets"
DATA_DIR = ASSET_ROOT / "data"
IMAGE_DIR = ASSET_ROOT / "images"
LANGUAGES = ("en", "vi")

# Fields the app never reads; dropping them keeps the bundled JSON small.
DROPPED_CARD_FIELDS = ("url", "cheatsheet_image_url", "cheatsheet_image")


def export_cards(language: str) -> int:
    cards = sort_cards(load_cards_for_language(language))
    slim: list[dict] = []
    for card in cards:
        record = {
            key: value
            for key, value in card.items()
            if key not in DROPPED_CARD_FIELDS
        }
        image = record.get("card_image")
        if image:
            record["card_image"] = Path(image).name
        slim.append(record)

    target = DATA_DIR / f"cards_{language}.json"
    target.write_text(
        json.dumps(slim, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    return len(slim)


def export_index(language: str) -> tuple[int, int]:
    index = load_index(default_index_path(language))
    chunks = index.get("chunks") or []
    dimensions = int(index.get("dimensions") or 0)
    if not chunks or not dimensions:
        raise RuntimeError(f"Empty embedding index for language {language!r}")

    meta_records: list[dict] = []
    vectors = bytearray()
    for chunk in chunks:
        embedding = chunk["embedding"]
        if len(embedding) != dimensions:
            raise RuntimeError(
                f"Chunk {chunk['id']} has {len(embedding)} dims, "
                f"expected {dimensions}"
            )
        vectors.extend(struct.pack(f"<{dimensions}f", *embedding))
        meta_records.append(
            {
                "id": chunk["id"],
                "card_name": chunk["card_name"],
                "orientation": chunk.get("orientation"),
                "facet": chunk["facet"],
                "title": chunk["title"],
                "text": chunk["text"],
            }
        )

    meta = {
        "schema": "supertarot.mobile_index.v1",
        "language": language,
        "provider": index.get("provider"),
        "model": index.get("model"),
        "dimensions": dimensions,
        "chunk_count": len(meta_records),
        "chunks": meta_records,
    }
    (DATA_DIR / f"index_{language}.json").write_text(
        json.dumps(meta, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    (DATA_DIR / f"index_{language}.f32").write_bytes(bytes(vectors))
    return len(meta_records), dimensions


def export_images() -> int:
    source = PROJECT_ROOT / "data" / "images"
    copied = 0
    for image in sorted(source.glob("*.jpg")):
        shutil.copy2(image, IMAGE_DIR / image.name)
        copied += 1
    return copied


def main() -> None:
    for directory in (DATA_DIR, IMAGE_DIR):
        if directory.exists():
            shutil.rmtree(directory)
        directory.mkdir(parents=True, exist_ok=True)

    for language in LANGUAGES:
        count = export_cards(language)
        chunk_count, dimensions = export_index(language)
        print(
            f"{language}: {count} cards, "
            f"{chunk_count} chunks x {dimensions} dims"
        )

    print(f"images: {export_images()} files")

    total = sum(
        path.stat().st_size for path in ASSET_ROOT.rglob("*") if path.is_file()
    )
    print(f"asset bundle: {total / 1024 / 1024:.1f} MB")


if __name__ == "__main__":
    main()
