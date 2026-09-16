"""Export repo data into the Astro site's inputs.

The web build needs far less than the Android app: no embedding index, because
there is no AI on the web, and no cheatsheets. Just the card meanings, the card
art, and a few branding images derived from the launcher icon.

Usage:
    python web/tools/prepare_web_assets.py
"""

from __future__ import annotations

import json
import re
import shutil
import struct
import sys
import unicodedata
import zlib
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT))

from app.learn import load_cards_for_language  # noqa: E402
from learning.deck_order import sort_cards  # noqa: E402

WEB_ROOT = PROJECT_ROOT / "web"
DATA_DIR = WEB_ROOT / "src" / "data"
PUBLIC_DIR = WEB_ROOT / "public"
IMAGE_DIR = PUBLIC_DIR / "cards"
ICON_SOURCE = PROJECT_ROOT / "mobile" / "icon" / "app_icon.png"
LANGUAGES = ("en", "vi")

# Matches adaptive_icon_background in mobile/pubspec.yaml, so the site and the
# launcher icon read as the same mark.
BEIGE = (0xDF, 0xC7, 0x9A)

# Fields no page reads. Dropping them keeps the JSON that Astro inlines small.
DROPPED_FIELDS = ("url", "cheatsheet_image_url", "cheatsheet_image")


def slugify(name: str) -> str:
    """URL slug from a card name. Names are English in both datasets, so the
    slug is stable across languages and the two builds share a URL shape."""
    normalized = unicodedata.normalize("NFKD", name)
    ascii_only = normalized.encode("ascii", "ignore").decode("ascii").lower()
    return re.sub(r"[^a-z0-9]+", "-", ascii_only).strip("-")


def export_cards(language: str) -> int:
    cards = sort_cards(load_cards_for_language(language))
    slim: list[dict] = []

    for index, card in enumerate(cards):
        record = {
            key: value
            for key, value in card.items()
            if key not in DROPPED_FIELDS
        }
        image = record.get("card_image")
        record["card_image"] = Path(image).name if image else ""
        record["slug"] = slugify(card["name"])
        # Deck position, so pages can offer previous/next without re-sorting.
        record["order"] = index
        slim.append(record)

    target = DATA_DIR / f"cards_{language}.json"
    target.write_text(
        json.dumps(slim, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    return len(slim)


def export_images() -> int:
    source = PROJECT_ROOT / "data" / "images"
    copied = 0
    for image in sorted(source.glob("*.jpg")):
        shutil.copy2(image, IMAGE_DIR / image.name)
        copied += 1
    return copied


# --- Minimal PNG read/write --------------------------------------------------
#
# The site needs a small logo, a favicon and an Open Graph card, all derived
# from the one launcher icon. Doing that here with the standard library keeps
# the web build free of an image dependency and keeps a single source of truth
# for the mark.


def read_png(path: Path) -> tuple[int, int, list[bytearray]]:
    data = path.read_bytes()
    pos, idat, ihdr = 8, b"", None
    while pos < len(data):
        length = struct.unpack(">I", data[pos : pos + 4])[0]
        kind = data[pos + 4 : pos + 8]
        if kind == b"IHDR":
            ihdr = struct.unpack(">IIBBBBB", data[pos + 8 : pos + 8 + length])
        elif kind == b"IDAT":
            idat += data[pos + 8 : pos + 8 + length]
        pos += 12 + length

    if ihdr is None:
        raise RuntimeError(f"{path} has no IHDR chunk")

    width, height, depth, colour = ihdr[0], ihdr[1], ihdr[2], ihdr[3]
    if depth != 8 or colour != 6:
        raise RuntimeError(
            f"{path} must be 8-bit RGBA, got depth={depth} colour={colour}"
        )

    raw = zlib.decompress(idat)
    stride, bpp = width * 4, 4
    previous = bytearray(stride)
    rows: list[bytearray] = []
    offset = 0
    for _ in range(height):
        filter_type = raw[offset]
        offset += 1
        line = bytearray(raw[offset : offset + stride])
        offset += stride
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0
            b = previous[x]
            c = previous[x - bpp] if x >= bpp else 0
            if filter_type == 1:
                line[x] = (line[x] + a) & 0xFF
            elif filter_type == 2:
                line[x] = (line[x] + b) & 0xFF
            elif filter_type == 3:
                line[x] = (line[x] + (a + b) // 2) & 0xFF
            elif filter_type == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[x] = (line[x] + pr) & 0xFF
        rows.append(line)
        previous = line
    return width, height, rows


def write_png(path: Path, rows: list[bytearray]) -> None:
    height = len(rows)
    width = len(rows[0]) // 4
    raw = b"".join(bytes([0]) + bytes(row) for row in rows)

    def chunk(kind: bytes, payload: bytes) -> bytes:
        return (
            struct.pack(">I", len(payload))
            + kind
            + payload
            + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)
        )

    signature = bytes([137, 80, 78, 71, 13, 10, 26, 10])
    path.write_bytes(
        signature
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )


def box_resize(
    rows: list[bytearray],
    width: int,
    height: int,
    size: int,
) -> list[bytearray]:
    """Box filter. Good enough for a downscale and needs no dependency."""
    out: list[bytearray] = []
    for y in range(size):
        line = bytearray(size * 4)
        y0 = y * height // size
        y1 = max((y + 1) * height // size, y0 + 1)
        for x in range(size):
            x0 = x * width // size
            x1 = max((x + 1) * width // size, x0 + 1)
            r = g = b = a = n = 0
            for sy in range(y0, y1):
                row = rows[sy]
                for sx in range(x0, x1):
                    o = sx * 4
                    alpha = row[o + 3]
                    # Weight colour by alpha so transparent edges do not drag
                    # the visible pixels toward black.
                    r += row[o] * alpha
                    g += row[o + 1] * alpha
                    b += row[o + 2] * alpha
                    a += alpha
                    n += 1
            o = x * 4
            if a:
                line[o] = min(255, r // a)
                line[o + 1] = min(255, g // a)
                line[o + 2] = min(255, b // a)
            line[o + 3] = a // n if n else 0
        out.append(line)
    return out


def export_branding() -> None:
    width, height, rows = read_png(ICON_SOURCE)

    for name, size in (("logo.png", 96), ("favicon.png", 64)):
        write_png(PUBLIC_DIR / name, box_resize(rows, width, height, size))

    # Open Graph card: 1200x630 beige with the mark centred. No text, because
    # rendering a font here would mean pulling in a dependency.
    og_width, og_height, mark = 1200, 630, 360
    scaled = box_resize(rows, width, height, mark)
    background = bytes(BEIGE) + bytes([255])
    canvas = [bytearray(background * og_width) for _ in range(og_height)]

    left, top = (og_width - mark) // 2, (og_height - mark) // 2
    for y in range(mark):
        row = scaled[y]
        target = canvas[top + y]
        for x in range(mark):
            o = x * 4
            alpha = row[o + 3]
            if not alpha:
                continue
            t = (left + x) * 4
            for channel in range(3):
                target[t + channel] = (
                    row[o + channel] * alpha
                    + target[t + channel] * (255 - alpha)
                ) // 255
    write_png(PUBLIC_DIR / "og.png", canvas)


def main() -> None:
    for directory in (DATA_DIR, IMAGE_DIR):
        if directory.exists():
            shutil.rmtree(directory)
        directory.mkdir(parents=True, exist_ok=True)

    for language in LANGUAGES:
        print(f"{language}: {export_cards(language)} cards")
    print(f"images: {export_images()} files")

    export_branding()
    print("branding: logo.png, favicon.png, og.png")

    total = sum(
        item.stat().st_size
        for directory in (DATA_DIR, PUBLIC_DIR)
        for item in directory.rglob("*")
        if item.is_file()
    )
    print(f"web inputs: {total / 1024 / 1024:.1f} MB")


if __name__ == "__main__":
    main()
