from __future__ import annotations

import os
from html import escape
from pathlib import Path

from learning.deck_order import sort_cards
from learning.embeddings import SOURCE_FILES, clean_text, load_cards

SUIT_DEFINITIONS = {
    "major": {
        "en": "Major Arcana",
        "vi": "Bộ Ẩn Chính",
        "button_en": "🃏 Major Arcana",
        "button_vi": "🃏 Ẩn chính",
    },
    "cups": {
        "en": "Cups",
        "vi": "Cốc",
        "button_en": "🥤 Cups",
        "button_vi": "🥤 Cups",
    },
    "wands": {
        "en": "Wands",
        "vi": "Gậy",
        "button_en": "🪄 Wands",
        "button_vi": "🪄 Wands",
    },
    "swords": {
        "en": "Swords",
        "vi": "Kiếm",
        "button_en": "🗡️ Swords",
        "button_vi": "🗡️ Swords",
    },
    "pentacles": {
        "en": "Pentacles",
        "vi": "Tiền Vàng",
        "button_en": "🪙 Pentacles",
        "button_vi": "🪙 Pentacles",
    },
}

LEARN_BACK_TO_SUITS_VI = "⬅️ Chọn bộ"
LEARN_BACK_TO_SUITS_EN = "⬅️ Choose suit"
LEARN_CLOSE_VI = "🏠 Menu chính"
LEARN_CLOSE_EN = "🏠 Main menu"

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


def load_cards_for_language(language: str) -> list[dict]:
    cards = load_cards(SOURCE_FILES[language])
    if language == "vi":
        cards = backfill_vi_metadata(cards)
    return cards


def backfill_vi_metadata(cards: list[dict]) -> list[dict]:
    english_cards = load_cards(SOURCE_FILES["en"])
    english_by_name = {
        clean_text(card.get("name")): card for card in english_cards
    }

    merged: list[dict] = []
    for card in cards:
        current = dict(card)
        english = english_by_name.get(clean_text(card.get("name"))) or {}

        if not clean_text(current.get("type")) and english.get("type"):
            current["type"] = TYPE_MAP.get(english["type"], english["type"])
        if not clean_text(current.get("element")) and english.get("element"):
            element = english["element"]
            current["element"] = ELEMENT_MAP.get(element, element)
        if (
            not clean_text(current.get("astrology"))
            and english.get("astrology")
        ):
            current["astrology"] = translate_astrology(english["astrology"])

        for field in (
            "yes_no",
            "cheatsheet_image",
            "cheatsheet_image_url",
            "card_image",
            "short_meaning",
            "short_rev_meaning",
        ):
            if not current.get(field) and english.get(field):
                current[field] = english[field]

        merged.append(current)

    return merged


def translate_astrology(value: str) -> str:
    result = value
    for source, target in {**ZODIAC_MAP, **PLANET_MAP}.items():
        result = result.replace(source, target)
    return result


def normalize_lookup(value: str) -> str:
    return clean_text(value).casefold()


def find_card_by_name(cards: list[dict], query: str) -> dict | None:
    normalized = normalize_lookup(query)
    if not normalized:
        return None

    for card in cards:
        name = card.get("name") or ""
        if normalize_lookup(name) == normalized:
            return card

    slug_like = normalized.replace(" ", "-")
    for card in cards:
        name = card.get("name") or ""
        if normalize_lookup(name).replace(" ", "-") == slug_like:
            return card

    return None


def cards_for_suit(
    cards: list[dict],
    suit_key: str,
    language: str,
) -> list[dict]:
    expected_type = SUIT_DEFINITIONS[suit_key][language]
    return sort_cards(
        [
            card
            for card in cards
            if clean_text(card.get("type")) == expected_type
        ]
    )


def suit_button_label(suit_key: str, language: str) -> str:
    return SUIT_DEFINITIONS[suit_key][f"button_{language}"]


def suit_key_from_button(text: str, language: str) -> str | None:
    for suit_key in SUIT_DEFINITIONS:
        if text == suit_button_label(suit_key, language):
            return suit_key
    return None


def card_caption(card: dict, language: str) -> str:
    return f"<b>{escape(clean_text(card.get('name')))}</b>"


def format_card_details(card: dict, language: str) -> str:
    headings = {
        "vi": {
            "description": "Mô tả lá bài",
            "symbols": "Biểu tượng",
            "upright": "Xuôi",
            "reversed": "Ngược",
            "love": "Tình yêu",
            "career": "Sự nghiệp",
            "finances": "Tài chính",
            "feelings": "Cảm xúc",
            "actions": "Hành động",
        },
        "en": {
            "description": "Card description",
            "symbols": "Symbols",
            "upright": "Upright",
            "reversed": "Reversed",
            "love": "Love",
            "career": "Career",
            "finances": "Finances",
            "feelings": "Feelings",
            "actions": "Actions",
        },
    }[language]

    lines = [f"<b>{escape(clean_text(card.get('name')))}</b>"]

    description = clean_text(card.get("description"))
    if description:
        lines.extend(
            [
                "",
                f"🖼️ <b>{escape(headings['description'])}</b>",
                escape(description),
            ]
        )

    symbols = card.get("symbols") or []
    if symbols:
        lines.extend(["", f"🔍 <b>{escape(headings['symbols'])}</b>"])
        for symbol in symbols:
            name = clean_text(symbol.get("name"))
            meaning = clean_text(symbol.get("meaning"))
            if name or meaning:
                if name and meaning:
                    lines.append(
                        f"• <b>{escape(name)}</b>: {escape(meaning)}"
                    )
                elif name:
                    lines.append(f"• <b>{escape(name)}</b>")
                else:
                    lines.append(f"• {escape(meaning)}")

    for orientation in ("upright", "reversed"):
        section = card.get(orientation) or {}
        section_lines: list[str] = []
        description = clean_text(section.get("description"))
        if description:
            section_lines.append(escape(description))
        for field in ("love", "career", "finances", "feelings", "actions"):
            value = clean_text(section.get(field))
            if value:
                icon = {
                    "love": "❤️",
                    "career": "💼",
                    "finances": "💰",
                    "feelings": "💭",
                    "actions": "🎯",
                }[field]
                section_lines.extend(
                    [
                        f"{icon} <b>{escape(headings[field])}</b>",
                        escape(value),
                    ]
                )
        if section_lines:
            section_icon = "⬆️" if orientation == "upright" else "⬇️"
            lines.extend(
                [
                    "",
                    f"{section_icon} <b>{escape(headings[orientation])}</b>",
                ]
            )
            lines.extend(section_lines)

    return "\n".join(lines)


def format_card_orientation_details(
    card: dict,
    language: str,
    orientation: str,
) -> str:
    headings = {
        "vi": {
            "upright": "Xuôi",
            "reversed": "Ngược",
            "keywords": "Từ khóa",
            "meaning": "Ý nghĩa",
            "love": "Tình yêu",
            "career": "Sự nghiệp",
            "finances": "Tài chính",
            "feelings": "Cảm xúc",
            "actions": "Hành động",
        },
        "en": {
            "upright": "Upright",
            "reversed": "Reversed",
            "keywords": "Keywords",
            "meaning": "Meaning",
            "love": "Love",
            "career": "Career",
            "finances": "Finances",
            "feelings": "Feelings",
            "actions": "Actions",
        },
    }[language]
    if orientation not in {"upright", "reversed"}:
        raise ValueError(f"Unsupported orientation: {orientation}")

    section = card.get(orientation) or {}
    section_icon = "⬆️" if orientation == "upright" else "⬇️"
    lines = [
        f"<b>{escape(clean_text(card.get('name')))}</b>",
        f"{section_icon} <b>{escape(headings[orientation])}</b>",
    ]

    keyword_field = f"{orientation}_keywords"
    keywords = clean_text(card.get(keyword_field))
    if keywords:
        lines.extend(
            [
                "",
                f"🏷️ <b>{escape(headings['keywords'])}</b>",
                escape(keywords),
            ]
        )

    description = clean_text(section.get("description"))
    if description:
        lines.extend(
            [
                "",
                f"📖 <b>{escape(headings['meaning'])}</b>",
                escape(description),
            ]
        )

    for field in ("love", "career", "finances", "feelings", "actions"):
        value = clean_text(section.get(field))
        if value:
            icon = {
                "love": "❤️",
                "career": "💼",
                "finances": "💰",
                "feelings": "💭",
                "actions": "🎯",
            }[field]
            lines.extend(
                [
                    "",
                    f"{icon} <b>{escape(headings[field])}</b>",
                    escape(value),
                ]
            )

    return "\n".join(lines)


def format_card_summary(
    card: dict,
    language: str,
    *,
    word_limit: int = 150,
) -> str:
    headings = {
        "vi": {
            "type": "Bộ",
            "element": "Nguyên tố",
            "astrology": "Chiêm tinh",
            "yes_no": "Yes/No",
            "upright_keywords": "Từ khóa xuôi",
            "reversed_keywords": "Từ khóa ngược",
            "overview": "Nghĩa cô đọng",
            "upright": "Xuôi",
            "reversed": "Ngược",
        },
        "en": {
            "type": "Type",
            "element": "Element",
            "astrology": "Astrology",
            "yes_no": "Yes/No",
            "upright_keywords": "Upright keywords",
            "reversed_keywords": "Reversed keywords",
            "overview": "Concise meaning",
            "upright": "Upright",
            "reversed": "Reversed",
        },
    }[language]

    lines = [f"<b>{escape(clean_text(card.get('name')))}</b>"]
    for field in ("type", "element", "astrology", "yes_no"):
        value = clean_text(card.get(field))
        if value:
            icon = {
                "type": "🃏",
                "element": "🌿",
                "astrology": "🔮",
                "yes_no": "❓",
            }[field]
            lines.append(
                f"{icon} <b>{escape(headings[field])}:</b> {escape(value)}"
            )

    for field in ("upright_keywords", "reversed_keywords"):
        value = clean_text(card.get(field))
        if value:
            icon = "⬆️" if field == "upright_keywords" else "⬇️"
            lines.append(
                f"{icon} <b>{escape(headings[field])}:</b> {escape(value)}"
            )

    # Use pre-computed short meanings when available; fall back to
    # the first word_limit words of the raw upright/reversed descriptions.
    upright_summary = clean_text(card.get("short_meaning"))
    reversed_summary = clean_text(card.get("short_rev_meaning"))

    if not upright_summary:
        upright_description = clean_text(
            (card.get("upright") or {}).get("description")
        )
        words = upright_description.split()
        upright_summary = " ".join(words[:word_limit])
        if len(words) > word_limit:
            upright_summary += "…"

    if not reversed_summary:
        reversed_description = clean_text(
            (card.get("reversed") or {}).get("description")
        )
        words = reversed_description.split()
        reversed_summary = " ".join(words[:word_limit])
        if len(words) > word_limit:
            reversed_summary += "…"

    if upright_summary or reversed_summary:
        lines.extend(
            [
                "",
                f"✨ <b>{escape(headings['overview'])}</b>",
                "",
            ]
        )
        if upright_summary:
            lines.extend(
                [
                    f"⬆️ <b>{escape(headings['upright'])}</b>",
                    escape(upright_summary),
                    "",
                ]
            )
        if reversed_summary:
            lines.extend(
                [
                    f"⬇️ <b>{escape(headings['reversed'])}</b>",
                    escape(reversed_summary),
                ]
            )

    return "\n".join(lines)


def card_image_path(card: dict) -> Path | None:
    image_path = clean_text(card.get("card_image"))
    if not image_path:
        return None
    return Path(image_path)


def summarize_card_meaning(
    card: dict,
    language: str,
    *,
    model: str,
    word_limit: int,
) -> str:
    if not os.environ.get("OPENAI_API_KEY"):
        raise RuntimeError("OPENAI_API_KEY is not configured.")

    from openai import OpenAI

    upright_description = clean_text(
        (card.get("upright") or {}).get("description")
    )
    reversed_description = clean_text(
        (card.get("reversed") or {}).get("description")
    )
    upright_keywords = clean_text(card.get("upright_keywords"))
    reversed_keywords = clean_text(card.get("reversed_keywords"))

    if language == "vi":
        system_prompt = (
            "Bạn là chuyên gia Tarot. "
            "Tóm tắt NGHĨA của lá bài, không mô tả hình ảnh. "
            "Chỉ dùng nghĩa xuôi và nghĩa ngược. "
            "Viết tiếng Việt tự nhiên, ngắn gọn, "
            f"tối đa khoảng {word_limit} từ. "
            "Trả về plain text với đúng 2 nhãn: "
            '"Xuôi:" và "Ngược:".'
        )
    else:
        system_prompt = (
            "You are a Tarot expert. "
            "Summarize the card meanings only, not the artwork. "
            "Use only the upright and reversed meanings. "
            "Write concise natural English, "
            f"within about {word_limit} words. "
            "Return plain text with exactly two labels: "
            '"Upright:" and "Reversed:".'
        )

    prompt = (
        f"Card: {clean_text(card.get('name'))}\n"
        f"Upright keywords: {upright_keywords}\n"
        f"Reversed keywords: {reversed_keywords}\n"
        f"Upright meaning: {upright_description}\n"
        f"Reversed meaning: {reversed_description}"
    )

    client = OpenAI()
    response = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": prompt},
        ],
        temperature=0.2,
    )
    content = response.choices[0].message.content or ""
    return clean_text(content)


def split_summary_sections(text: str, language: str) -> tuple[str, str]:
    cleaned = clean_text(text)
    if not cleaned:
        return "", ""

    if language == "vi":
        upright_label = "Xuôi:"
        reversed_label = "Ngược:"
    else:
        upright_label = "Upright:"
        reversed_label = "Reversed:"

    upright = ""
    reversed_text = ""

    if upright_label in cleaned and reversed_label in cleaned:
        _, after_upright = cleaned.split(upright_label, maxsplit=1)
        upright, reversed_text = after_upright.split(
            reversed_label,
            maxsplit=1,
        )
        return upright.strip(), reversed_text.strip()

    if upright_label in cleaned:
        upright = cleaned.split(upright_label, maxsplit=1)[1].strip()
    else:
        upright = cleaned

    if reversed_label in cleaned:
        reversed_text = cleaned.split(reversed_label, maxsplit=1)[1].strip()

    return upright, reversed_text
