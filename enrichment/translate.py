#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Dịch tarot_meanings.json sang tiếng Việt bằng Anthropic API."""

import io
import json
import re
import sys
import time
from pathlib import Path

import anthropic

# Buộc stdout/stderr dùng UTF-8 trên Windows
sys.stdout = io.TextIOWrapper(
    sys.stdout.buffer, encoding="utf-8", errors="replace"
)
sys.stderr = io.TextIOWrapper(
    sys.stderr.buffer, encoding="utf-8", errors="replace"
)

INPUT_FILE = Path("data/output/tarot_meanings.json")
OUTPUT_FILE = Path("data/output/tarot_meanings_vi.json")
PROGRESS_FILE = Path(
    "data/output/tarot_meanings_vi_progress.json"
)

TYPE_MAP = {
    "Cups": "Cốc",
    "Wands": "Gậy",
    "Swords": "Kiếm",
    "Pentacles": "Tiền Vàng",
    "Major Arcana": "Bộ Ẩn Chính",
}

ELEMENT_MAP = {
    "Water": "Nước",
    "Fire": "Lửa",
    "Air": "Không Khí",
    "Earth": "Đất",
}

ZODIAC_MAP = {
    "Aries": "Bạch Dương",
    "Taurus": "Kim Ngưu",
    "Gemini": "Song Tử",
    "Cancer": "Cự Giải",
    "Leo": "Sư Tử",
    "Virgo": "Xử Nữ",
    "Libra": "Thiên Bình",
    "Scorpio": "Thiên Yết",
    "Sagittarius": "Nhân Mã",
    "Capricorn": "Ma Kết",
    "Aquarius": "Bảo Bình",
    "Pisces": "Song Ngư",
}

PLANET_MAP = {
    "Mars": "Sao Hỏa",
    "Venus": "Sao Kim",
    "Jupiter": "Sao Mộc",
    "Saturn": "Sao Thổ",
    "Mercury": "Sao Thủy",
    "Sun": "Mặt Trời",
    "Moon": "Mặt Trăng",
    "Uranus": "Sao Thiên Vương",
    "Neptune": "Sao Hải Vương",
    "Pluto": "Sao Diêm Vương",
}


def translate_astrology(astro_str: str | None) -> str | None:
    if not astro_str:
        return astro_str
    result = astro_str
    for en, vi in {**ZODIAC_MAP, **PLANET_MAP}.items():
        result = result.replace(en, vi)
    return result


def translate_card_texts(
    client: anthropic.Anthropic, card: dict
) -> dict:
    """Gọi API để dịch toàn bộ text fields của một lá bài."""
    payload = {
        "upright_keywords": card.get("upright_keywords") or [],
        "reversed_keywords": card.get("reversed_keywords") or [],
        "description": card.get("description") or "",
        "upright": card.get("upright") or {},
        "reversed": card.get("reversed") or {},
    }

    prompt = (
        "Bạn là chuyên gia tarot với kiến thức sâu về huyền học"
        " phương Tây.\n"
        f"Nhiệm vụ: Dịch nội dung lá bài \"{card['name']}\""
        " từ tiếng Anh sang tiếng Việt.\n\n"
        "Quy tắc dịch:\n"
        "- Dịch tự nhiên, trôi chảy theo phong cách tarot"
        " chuyên nghiệp và huyền bí\n"
        "- Giữ nguyên tên riêng các lá bài tarot"
        " (ví dụ: The Fool, The Lovers)\n"
        "- Từ 'querent' → 'người hỏi bài'\n"
        "- Từ 'upright' → 'xuôi chiều',"
        " 'reversed' → 'ngược chiều'\n"
        "- Giữ nguyên cấu trúc JSON, chỉ dịch các giá trị string\n"
        "- Nếu value là null thì giữ nguyên null\n"
        "- Trả về JSON thuần túy, không có markdown code block\n\n"
        "Input JSON:\n"
        + json.dumps(payload, ensure_ascii=False, indent=2)
    )

    for attempt in range(3):
        try:
            response = client.messages.create(
                model="claude-haiku-4-5-20251001",
                max_tokens=8192,
                messages=[{"role": "user", "content": prompt}],
            )
            raw = response.content[0].text.strip()
            raw = re.sub(r"^```(?:json)?\s*", "", raw)
            raw = re.sub(r"\s*```$", "", raw)
            return json.loads(raw)
        except (json.JSONDecodeError, anthropic.APIError) as e:
            print(f"  Lỗi lần {attempt + 1}: {e}")
            if attempt < 2:
                time.sleep(3)
    raise RuntimeError(
        f"Không thể dịch lá '{card['name']}' sau 3 lần thử"
    )


def translate_card(
    client: anthropic.Anthropic, card: dict
) -> dict:
    """Dịch toàn bộ một lá bài."""
    texts = translate_card_texts(client, card)

    return {
        "name": card["name"],
        "url": card["url"],
        "type": TYPE_MAP.get(
            card.get("type", ""), card.get("type", "")
        ),
        "element": ELEMENT_MAP.get(
            card.get("element", ""), card.get("element")
        ),
        "astrology": translate_astrology(card.get("astrology")),
        "yes_no": card.get("yes_no"),
        "cheatsheet_image": card.get("cheatsheet_image"),
        "cheatsheet_image_url": card.get("cheatsheet_image_url"),
        "card_image": card.get("card_image"),
        "short_meaning": card.get("short_meaning"),
        "short_rev_meaning": card.get("short_rev_meaning"),
        "upright_keywords": texts.get("upright_keywords", []),
        "reversed_keywords": texts.get("reversed_keywords", []),
        "description": texts.get("description", ""),
        "upright": texts.get("upright", {}),
        "reversed": texts.get("reversed", {}),
    }


def main():
    client = anthropic.Anthropic()

    cards = json.loads(INPUT_FILE.read_text(encoding="utf-8"))
    print(f"Đọc {len(cards)} lá bài từ {INPUT_FILE}")

    done: dict[str, dict] = {}
    if PROGRESS_FILE.exists():
        saved = json.loads(
            PROGRESS_FILE.read_text(encoding="utf-8")
        )
        done = {c["name"]: c for c in saved}
        print(
            f"Tiếp tục: {len(done)} lá đã dịch,"
            f" còn {len(cards) - len(done)} lá"
        )

    results = list(done.values())

    for i, card in enumerate(cards):
        name = card["name"]
        if name in done:
            print(f"[{i + 1:02d}/78] Bỏ qua (đã xong): {name}")
            continue

        print(
            f"[{i + 1:02d}/78] Đang dịch: {name} ...",
            end=" ",
            flush=True,
        )
        try:
            translated = translate_card(client, card)
            results.append(translated)
            done[name] = translated
            PROGRESS_FILE.write_text(
                json.dumps(results, ensure_ascii=False, indent=2),
                encoding="utf-8",
            )
            print("OK")
        except Exception as e:
            print(f"LỖI: {e}")
            break

        time.sleep(0.5)

    if len(results) == len(cards):
        OUTPUT_FILE.write_text(
            json.dumps(results, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        print(
            f"\nHoàn thành! Đã lưu {len(results)} lá"
            f" vào {OUTPUT_FILE}"
        )
        if PROGRESS_FILE.exists():
            PROGRESS_FILE.unlink()
    else:
        print(
            f"\nDừng tại {len(results)}/{len(cards)} lá."
            " Chạy lại để tiếp tục."
        )


if __name__ == "__main__":
    main()
