#!/usr/bin/env python3
"""Translate new cheatsheet fields from EN JSON into the VI JSON."""

import json
import time
from pathlib import Path

import anthropic

EN_FILE = Path("data/output/tarot_meanings.json")
VI_FILE = Path("data/output/tarot_meanings_vi.json")

YES_NO_MAP = {"Yes": "Co", "No": "Khong", "Neutral": "Trung lap"}

TRANSLATE_PROMPT = """\
Dich cac truong du lieu bai tarot tu tieng Anh sang tieng Viet.
Chi tra ve JSON hop le, khong them van ban khac, khong dung markdown.

Yeu cau:
- symbols: dich ca "name" (ten bieu tuong) va "meaning" (y nghia)
- upright_keywords va reversed_keywords: dich tung cum tu ngan trong moi mang
- Giu nguyen cau truc JSON va so luong phan tu trong mang
- Su dung tieng Viet tu nhien, co dau

Input JSON:
{input_json}"""


def translate_card_fields(
    client: anthropic.Anthropic, en_card: dict
) -> dict:
    payload = {
        "symbols": en_card.get("symbols", []),
        "upright_keywords": {
            "general": en_card.get("upright_keywords", []),
            "love": en_card.get("upright", {}).get("love_keywords", []),
            "career": en_card.get("upright", {}).get("career_keywords", []),
            "finances": en_card.get("upright", {}).get(
                "finances_keywords", []
            ),
            "feelings": en_card.get("upright", {}).get(
                "feelings_keywords", []
            ),
            "actions": en_card.get("upright", {}).get("actions_keywords", []),
        },
        "reversed_keywords": {
            "general": en_card.get("reversed_keywords", []),
            "love": en_card.get("reversed", {}).get("love_keywords", []),
            "career": en_card.get("reversed", {}).get("career_keywords", []),
            "finances": en_card.get("reversed", {}).get(
                "finances_keywords", []
            ),
            "feelings": en_card.get("reversed", {}).get(
                "feelings_keywords", []
            ),
            "actions": en_card.get("reversed", {}).get(
                "actions_keywords", []
            ),
        },
    }

    prompt = TRANSLATE_PROMPT.format(
        input_json=json.dumps(payload, ensure_ascii=False, indent=2)
    )

    response = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=2048,
        messages=[{"role": "user", "content": prompt}],
    )

    text = response.content[0].text.strip()
    if text.startswith("```"):
        start = text.index("{")
        end = text.rindex("}") + 1
        text = text[start:end]
    return json.loads(text)


def merge_into_vi(vi_card: dict, en_card: dict, translated: dict) -> dict:
    # Copy non-translated fields
    vi_card["yes_no"] = en_card.get("yes_no", "")
    vi_card["cheatsheet_image"] = en_card.get("cheatsheet_image", "")
    vi_card["cheatsheet_image_url"] = en_card.get(
        "cheatsheet_image_url", ""
    )
    vi_card["card_image"] = en_card.get("card_image", "")

    # Symbols (translated)
    vi_card["symbols"] = translated.get("symbols", [])

    # Update general keywords with translated cheatsheet version
    up_kw = translated.get("upright_keywords", {})
    rev_kw = translated.get("reversed_keywords", {})

    if up_kw.get("general"):
        vi_card["upright_keywords"] = up_kw["general"]
    if rev_kw.get("general"):
        vi_card["reversed_keywords"] = rev_kw["general"]

    # Add *_keywords into upright/reversed sections
    for section_key, kw_dict in [("upright", up_kw), ("reversed", rev_kw)]:
        section = vi_card.setdefault(section_key, {})
        for cat in ("love", "career", "finances", "feelings", "actions"):
            vals = kw_dict.get(cat, [])
            if vals:
                section[f"{cat}_keywords"] = vals

    return vi_card


def main() -> None:
    client = anthropic.Anthropic()

    en_cards: list[dict] = json.loads(
        EN_FILE.read_text(encoding="utf-8")
    )
    vi_cards: list[dict] = json.loads(
        VI_FILE.read_text(encoding="utf-8")
    )

    en_by_name = {c["name"]: c for c in en_cards}
    print(f"Loaded {len(en_cards)} EN cards, {len(vi_cards)} VI cards\n")

    updated = 0
    failed: list[str] = []

    for i, vi_card in enumerate(vi_cards):
        name = vi_card.get("name", "?")

        if "symbols" in vi_card:
            print(f"[{i+1:02d}/78] {name}: already done, skip")
            continue

        en_card = en_by_name.get(name)
        if not en_card:
            print(f"[{i+1:02d}/78] {name}: not found in EN JSON")
            failed.append(name)
            continue

        if not en_card.get("symbols"):
            print(f"[{i+1:02d}/78] {name}: EN card missing symbols")
            failed.append(name)
            continue

        print(f"[{i+1:02d}/78] {name}...", end=" ", flush=True)
        try:
            translated = translate_card_fields(client, en_card)
            vi_cards[i] = merge_into_vi(vi_card, en_card, translated)
            updated += 1
            print("OK")
        except Exception as exc:
            print(f"FAIL -- {exc}")
            failed.append(name)

        if i < len(vi_cards) - 1:
            time.sleep(0.3)

        if updated > 0 and updated % 10 == 0:
            VI_FILE.write_text(
                json.dumps(vi_cards, ensure_ascii=False, indent=2),
                encoding="utf-8",
            )
            print(f"  [saved progress: {updated} updated]\n")

    VI_FILE.write_text(
        json.dumps(vi_cards, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"\nDone: {updated} enriched, {len(failed)} failed")
    if failed:
        print(f"Failed: {', '.join(failed)}")


if __name__ == "__main__":
    main()
