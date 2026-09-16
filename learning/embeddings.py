"""Build and query tarot meaning embedding indexes.

The production provider is OpenAI embeddings. A deterministic hash provider is
included for offline smoke tests and local development when no API key is set.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable, Sequence

from .console import configure_utf8_stdio

PROJECT_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = PROJECT_ROOT / "data" / "embeddings"
SOURCE_FILES = {
    "en": PROJECT_ROOT / "data" / "output" / "tarot_meanings.json",
    "vi": PROJECT_ROOT / "data" / "output" / "tarot_meanings_vi.json",
}

INDEX_SCHEMA = "supertarot.embedding_index.v1"
OPENAI_EMBEDDING_MODEL = "text-embedding-3-small"
HASH_EMBEDDING_MODEL = "hash-word-v1"
HASH_DIMENSIONS = 512
TEXT_FIELDS = ("description", "love", "career", "finances", "feelings", "actions")


@dataclass(frozen=True)
class TextChunk:
    id: str
    card_name: str
    language: str
    orientation: str | None
    facet: str
    title: str
    text: str
    keywords: list[str]
    url: str | None
    card_image: str | None
    cheatsheet_image: str | None

    def to_index_record(self) -> dict:
        return {
            "id": self.id,
            "card_name": self.card_name,
            "language": self.language,
            "orientation": self.orientation,
            "facet": self.facet,
            "title": self.title,
            "text": self.text,
            "keywords": self.keywords,
            "url": self.url,
            "card_image": self.card_image,
            "cheatsheet_image": self.cheatsheet_image,
            "text_hash": sha256_text(self.text),
        }


def clean_text(value: object) -> str:
    if value is None:
        return ""
    if isinstance(value, list):
        return clean_text(", ".join(str(item) for item in value if item))
    return re.sub(r"\s+", " ", str(value)).strip()


def sha256_text(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def slugify(value: str) -> str:
    value = value.lower().strip()
    value = re.sub(r"[^a-z0-9]+", "-", value)
    return value.strip("-")


def rel_path(path: Path) -> str:
    try:
        return path.resolve().relative_to(PROJECT_ROOT).as_posix()
    except ValueError:
        return path.resolve().as_posix()


def load_cards(path: Path) -> list[dict]:
    return json.loads(path.read_text(encoding="utf-8"))


def card_lookup_text(card: dict) -> str:
    parts = [
        clean_text(card.get("name")),
        clean_text(card.get("type")),
        clean_text(card.get("element")),
        clean_text(card.get("astrology")),
        clean_text(card.get("yes_no")),
    ]
    return " | ".join(part for part in parts if part)


def symbol_text(card: dict) -> str:
    parts: list[str] = []
    for symbol in card.get("symbols") or []:
        name = clean_text(symbol.get("name"))
        meaning = clean_text(symbol.get("meaning"))
        if name or meaning:
            parts.append(f"{name}: {meaning}".strip(": "))
    return "; ".join(parts)


def section_keywords(section: dict) -> list[str]:
    keywords: list[str] = []
    for field in TEXT_FIELDS:
        keywords.extend(section.get(f"{field}_keywords") or [])
    return [clean_text(item) for item in keywords if clean_text(item)]


def make_chunk(
    *,
    language: str,
    card: dict,
    orientation: str | None,
    facet: str,
    title: str,
    text_parts: Iterable[object],
    keywords: Iterable[str] = (),
) -> TextChunk | None:
    text = clean_text(" ".join(clean_text(part) for part in text_parts if clean_text(part)))
    if not text:
        return None

    card_name = clean_text(card.get("name"))
    chunk_id = ":".join(
        part
        for part in (
            language,
            slugify(card_name),
            orientation or "card",
            slugify(facet),
        )
        if part
    )
    return TextChunk(
        id=chunk_id,
        card_name=card_name,
        language=language,
        orientation=orientation,
        facet=facet,
        title=title,
        text=text,
        keywords=[clean_text(item) for item in keywords if clean_text(item)],
        url=card.get("url"),
        card_image=card.get("card_image"),
        cheatsheet_image=card.get("cheatsheet_image"),
    )


def iter_card_chunks(card: dict, language: str) -> Iterable[TextChunk]:
    name = clean_text(card.get("name"))
    upright_keywords = [clean_text(item) for item in card.get("upright_keywords") or []]
    reversed_keywords = [clean_text(item) for item in card.get("reversed_keywords") or []]
    symbols = symbol_text(card)
    metadata = card_lookup_text(card)

    overview = make_chunk(
        language=language,
        card=card,
        orientation=None,
        facet="overview",
        title=f"{name} overview",
        text_parts=[
            metadata,
            card.get("description"),
            "Upright keywords: " + ", ".join(upright_keywords),
            "Reversed keywords: " + ", ".join(reversed_keywords),
            "Symbols: " + symbols if symbols else "",
        ],
        keywords=[*upright_keywords, *reversed_keywords],
    )
    if overview:
        yield overview

    correspondences = make_chunk(
        language=language,
        card=card,
        orientation=None,
        facet="correspondences",
        title=f"{name} correspondences",
        text_parts=[
            f"Type: {card.get('type')}",
            f"Element: {card.get('element')}",
            f"Astrology: {card.get('astrology')}",
            f"Yes or no: {card.get('yes_no')}",
        ],
    )
    if correspondences:
        yield correspondences

    if symbols:
        chunk = make_chunk(
            language=language,
            card=card,
            orientation=None,
            facet="symbols",
            title=f"{name} symbols",
            text_parts=[symbols],
        )
        if chunk:
            yield chunk

    for orientation in ("upright", "reversed"):
        section = card.get(orientation) or {}
        general_keywords = upright_keywords if orientation == "upright" else reversed_keywords
        orientation_summary = make_chunk(
            language=language,
            card=card,
            orientation=orientation,
            facet="summary",
            title=f"{name} {orientation} summary",
            text_parts=[
                section.get("description"),
                "Keywords: " + ", ".join(general_keywords),
                "Facet keywords: " + ", ".join(section_keywords(section)),
            ],
            keywords=general_keywords,
        )
        if orientation_summary:
            yield orientation_summary

        for field in TEXT_FIELDS:
            if field == "description":
                continue
            facet_keywords = [clean_text(item) for item in section.get(f"{field}_keywords") or []]
            chunk = make_chunk(
                language=language,
                card=card,
                orientation=orientation,
                facet=field,
                title=f"{name} {orientation} {field}",
                text_parts=[
                    section.get(field),
                    "Keywords: " + ", ".join(facet_keywords),
                ],
                keywords=facet_keywords,
            )
            if chunk:
                yield chunk


def build_chunks(cards: Sequence[dict], language: str) -> list[TextChunk]:
    chunks: list[TextChunk] = []
    seen_ids: set[str] = set()
    for card in cards:
        for chunk in iter_card_chunks(card, language):
            if chunk.id in seen_ids:
                raise ValueError(f"Duplicate embedding chunk id: {chunk.id}")
            seen_ids.add(chunk.id)
            chunks.append(chunk)
    return chunks


class HashEmbeddingProvider:
    name = "hash"

    def __init__(self, dimensions: int = HASH_DIMENSIONS) -> None:
        self.model = HASH_EMBEDDING_MODEL
        self.dimensions = dimensions

    def embed(self, texts: Sequence[str], batch_size: int = 64) -> list[list[float]]:
        return [self._embed_one(text) for text in texts]

    def _embed_one(self, text: str) -> list[float]:
        vector = [0.0] * self.dimensions
        tokens = re.findall(r"\w+", text.lower(), flags=re.UNICODE)
        features = list(tokens)
        features.extend(" ".join(pair) for pair in zip(tokens, tokens[1:]))

        for feature in features:
            digest = hashlib.blake2b(feature.encode("utf-8"), digest_size=8).digest()
            value = int.from_bytes(digest, "big")
            index = value % self.dimensions
            sign = 1.0 if value & 1 else -1.0
            vector[index] += sign

        norm = math.sqrt(sum(item * item for item in vector))
        if norm == 0:
            return vector
        return [item / norm for item in vector]


class OpenAIEmbeddingProvider:
    name = "openai"

    def __init__(
        self,
        model: str = OPENAI_EMBEDDING_MODEL,
        dimensions: int | None = None,
    ) -> None:
        from openai import OpenAI

        self.client = OpenAI()
        self.model = model
        self.dimensions = dimensions

    def embed(self, texts: Sequence[str], batch_size: int = 64) -> list[list[float]]:
        embeddings: list[list[float]] = []
        for start in range(0, len(texts), batch_size):
            batch = texts[start : start + batch_size]
            kwargs: dict[str, object] = {"model": self.model, "input": list(batch)}
            if self.dimensions is not None:
                kwargs["dimensions"] = self.dimensions
            response = self.client.embeddings.create(**kwargs)
            embeddings.extend(item.embedding for item in response.data)
        return embeddings


def make_provider(
    provider_name: str,
    *,
    model: str | None = None,
    dimensions: int | None = None,
):
    if provider_name == "hash":
        return HashEmbeddingProvider(dimensions or HASH_DIMENSIONS)
    if provider_name == "openai":
        return OpenAIEmbeddingProvider(model or OPENAI_EMBEDDING_MODEL, dimensions)
    raise ValueError(f"Unsupported provider: {provider_name}")


def build_index(
    *,
    language: str,
    source_path: Path,
    output_path: Path,
    provider_name: str,
    model: str | None,
    dimensions: int | None,
    batch_size: int,
    dry_run: bool = False,
) -> dict:
    cards = load_cards(source_path)
    chunks = build_chunks(cards, language)

    if dry_run:
        return {
            "language": language,
            "source_file": rel_path(source_path),
            "card_count": len(cards),
            "chunk_count": len(chunks),
            "sample_chunks": [chunk.to_index_record() for chunk in chunks[:5]],
        }

    provider = make_provider(provider_name, model=model, dimensions=dimensions)
    embeddings = provider.embed([chunk.text for chunk in chunks], batch_size=batch_size)
    if len(embeddings) != len(chunks):
        raise RuntimeError(
            f"Provider returned {len(embeddings)} embeddings for {len(chunks)} chunks"
        )

    records = []
    for chunk, embedding in zip(chunks, embeddings):
        record = chunk.to_index_record()
        record["embedding"] = embedding
        records.append(record)

    index = {
        "schema": INDEX_SCHEMA,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "language": language,
        "source_file": rel_path(source_path),
        "source_sha256": sha256_text(source_path.read_text(encoding="utf-8")),
        "provider": provider.name,
        "model": provider.model,
        "request_dimensions": getattr(provider, "dimensions", None),
        "dimensions": len(records[0]["embedding"]) if records else 0,
        "card_count": len(cards),
        "chunk_count": len(records),
        "chunks": records,
    }

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(index, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    return index


def load_index(path: Path) -> dict:
    index = json.loads(path.read_text(encoding="utf-8"))
    if index.get("schema") != INDEX_SCHEMA:
        raise ValueError(f"Unsupported index schema in {path}")
    return index


def cosine_similarity(a: Sequence[float], b: Sequence[float]) -> float:
    numerator = sum(left * right for left, right in zip(a, b))
    norm_a = math.sqrt(sum(item * item for item in a))
    norm_b = math.sqrt(sum(item * item for item in b))
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return numerator / (norm_a * norm_b)


def search_index(
    *,
    index: dict,
    query: str,
    top_k: int,
    card_name: str | None = None,
    orientation: str | None = None,
    facet: str | None = None,
) -> list[dict]:
    provider = make_provider(
        index["provider"],
        model=index.get("model"),
        dimensions=index.get("request_dimensions"),
    )
    query_embedding = provider.embed([query], batch_size=1)[0]
    scored: list[dict] = []

    for chunk in index.get("chunks", []):
        if card_name and chunk.get("card_name") != card_name:
            continue
        if orientation and chunk.get("orientation") != orientation:
            continue
        if facet and chunk.get("facet") != facet:
            continue
        scored.append(
            {
                "score": cosine_similarity(query_embedding, chunk["embedding"]),
                "id": chunk["id"],
                "card_name": chunk["card_name"],
                "orientation": chunk.get("orientation"),
                "facet": chunk["facet"],
                "title": chunk["title"],
                "text": chunk["text"],
                "keywords": chunk.get("keywords") or [],
                "card_image": chunk.get("card_image"),
                "cheatsheet_image": chunk.get("cheatsheet_image"),
            }
        )

    scored.sort(key=lambda item: item["score"], reverse=True)
    return scored[:top_k]


def default_index_path(language: str, output_dir: Path = OUTPUT_DIR) -> Path:
    return output_dir / f"tarot_embeddings_{language}.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    build = subparsers.add_parser("build", help="Build embedding indexes")
    build.add_argument("--lang", choices=["en", "vi", "all"], default="all")
    build.add_argument("--provider", choices=["openai", "hash"], default="openai")
    build.add_argument("--model", default=None)
    build.add_argument("--dimensions", type=int, default=None)
    build.add_argument("--batch-size", type=int, default=64)
    build.add_argument("--output-dir", type=Path, default=OUTPUT_DIR)
    build.add_argument("--dry-run", action="store_true")

    search = subparsers.add_parser("search", help="Search an embedding index")
    search.add_argument("--lang", choices=["en", "vi"], default="vi")
    search.add_argument("--index", type=Path, default=None)
    search.add_argument("--query", required=True)
    search.add_argument("--top-k", type=int, default=5)
    search.add_argument("--card-name", default=None)
    search.add_argument("--orientation", choices=["upright", "reversed"], default=None)
    search.add_argument("--facet", default=None)

    return parser.parse_args()


def main() -> None:
    configure_utf8_stdio()
    args = parse_args()

    if args.command == "build":
        languages = SOURCE_FILES.keys() if args.lang == "all" else [args.lang]
        for language in languages:
            source_path = SOURCE_FILES[language]
            output_path = default_index_path(language, args.output_dir)
            result = build_index(
                language=language,
                source_path=source_path,
                output_path=output_path,
                provider_name=args.provider,
                model=args.model,
                dimensions=args.dimensions,
                batch_size=args.batch_size,
                dry_run=args.dry_run,
            )
            if args.dry_run:
                print(json.dumps(result, ensure_ascii=False, indent=2))
            else:
                print(
                    f"Built {result['chunk_count']} {language} chunks "
                    f"with {result['provider']}:{result['model']} -> {output_path}"
                )
        return

    if args.command == "search":
        index_path = args.index or default_index_path(args.lang)
        index = load_index(index_path)
        results = search_index(
            index=index,
            query=args.query,
            top_k=args.top_k,
            card_name=args.card_name,
            orientation=args.orientation,
            facet=args.facet,
        )
        print(json.dumps(results, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
