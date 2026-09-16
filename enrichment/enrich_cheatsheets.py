#!/usr/bin/env python3
"""Extract symbols and category keywords from cheatsheets via Claude Vision."""

import base64
import json
import time
from pathlib import Path

import anthropic

OUTPUT_FILE = Path("data/output/tarot_meanings.json")

PROMPT = """\
Extract data from this tarot card cheatsheet image. Return ONLY valid JSON.

1. "symbols": Array of 3 objects from the "Symbols" section (top-right corner).
   Each has "name" (label in ALL CAPS) and "meaning" (description below it).

2. "upright_keywords": Object with 6 keys from the LEFT "Upright Keywords" column.
   Keys: "general", "love", "career", "finances", "feelings", "actions".
   Each value is an array of short phrase strings (split by commas).

3. "reversed_keywords": Same 6 keys from the RIGHT "Reversed Keywords" column.

Return format — no extra text, no markdown fences:
{
  "symbols": [
    {"name": "...", "meaning": "..."},
    {"name": "...", "meaning": "..."},
    {"name": "...", "meaning": "..."}
  ],
  "upright_keywords": {
    "general": [...], "love": [...], "career": [...],
    "finances": [...], "feelings": [...], "actions": [...]
  },
  "reversed_keywords": {
    "general": [...], "love": [...], "career": [...],
    "finances": [...], "feelings": [...], "actions": [...]
  }
}"""


def extract_from_image(client: anthropic.Anthropic, image_path: Path) -> dict:
    image_data = base64.standard_b64encode(
        image_path.read_bytes()
    ).decode("utf-8")

    response = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=2048,
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "image",
                        "source": {
                            "type": "base64",
                            "media_type": "image/png",
                            "data": image_data,
                        },
                    },
                    {"type": "text", "text": PROMPT},
                ],
            }
        ],
    )

    text = response.content[0].text.strip()
    if text.startswith("```"):
        start = text.index("{")
        end = text.rindex("}") + 1
        text = text[start:end]
    return json.loads(text)


def merge(card: dict, extracted: dict) -> dict:
    card["symbols"] = extracted.get("symbols", [])

    up_kw = extracted.get("upright_keywords", {})
    rev_kw = extracted.get("reversed_keywords", {})

    if up_kw.get("general"):
        card["upright_keywords"] = [
            k.strip() for k in up_kw["general"] if k.strip()
        ]
    if rev_kw.get("general"):
        card["reversed_keywords"] = [
            k.strip() for k in rev_kw["general"] if k.strip()
        ]

    for section_key, kw_dict in [("upright", up_kw), ("reversed", rev_kw)]:
        section = card.setdefault(section_key, {})
        for cat in ("love", "career", "finances", "feelings", "actions"):
            vals = kw_dict.get(cat, [])
            if vals:
                section[f"{cat}_keywords"] = [
                    k.strip() for k in vals if k.strip()
                ]

    return card


def main() -> None:
    client = anthropic.Anthropic()
    cards: list[dict] = json.loads(
        OUTPUT_FILE.read_text(encoding="utf-8")
    )
    print(f"Loaded {len(cards)} cards\n")

    updated = 0
    failed: list[str] = []

    for i, card in enumerate(cards):
        name = card.get("name", "?")

        if "symbols" in card:
            print(f"[{i+1:02d}/78] {name}: already done, skip")
            continue

        img_str = card.get("cheatsheet_image")
        if not img_str:
            print(f"[{i+1:02d}/78] {name}: no image path")
            failed.append(name)
            continue

        img = Path(img_str)
        if not img.exists():
            print(f"[{i+1:02d}/78] {name}: image missing at {img}")
            failed.append(name)
            continue

        print(f"[{i+1:02d}/78] {name}...", end=" ", flush=True)
        try:
            extracted = extract_from_image(client, img)
            cards[i] = merge(card, extracted)
            updated += 1
            print("OK")
        except Exception as exc:
            print(f"FAIL -- {exc}")
            failed.append(name)

        if i < len(cards) - 1:
            time.sleep(0.3)

        if updated > 0 and updated % 10 == 0:
            OUTPUT_FILE.write_text(
                json.dumps(cards, ensure_ascii=False, indent=2),
                encoding="utf-8",
            )
            print(f"  [saved progress: {updated} updated]\n")

    OUTPUT_FILE.write_text(
        json.dumps(cards, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"\nDone: {updated} enriched, {len(failed)} failed")
    if failed:
        print(f"Failed: {', '.join(failed)}")


if __name__ == "__main__":
    main()
