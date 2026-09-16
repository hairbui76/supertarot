"""Study-session helpers for Telegram bot commands.

This module owns card rotation and question selection only. Transport concerns
such as Telegram commands and schedulers should call into this layer.
"""

from __future__ import annotations

import argparse
import json
import random
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

from .embeddings import SOURCE_FILES, clean_text
from .console import configure_utf8_stdio

PROJECT_ROOT = Path(__file__).resolve().parents[1]
STATE_FILE = PROJECT_ROOT / "data" / "bot_state" / "study_state.json"
STATE_SCHEMA = "supertarot.study_state.v1"

FACET_LABELS = {
    "overview": {
        "en": "overall card meaning",
        "vi": "ý nghĩa tổng quan của lá bài",
    },
    "correspondences": {
        "en": "element, astrology, and yes/no correspondences",
        "vi": "nguyên tố, chiêm tinh và yes/no",
    },
    "symbols": {
        "en": "main symbols",
        "vi": "các biểu tượng chính",
    },
    "upright.summary": {
        "en": "upright meaning",
        "vi": "ý nghĩa xuôi chiều",
    },
    "upright.love": {
        "en": "upright love meaning",
        "vi": "ý nghĩa tình yêu khi xuôi chiều",
    },
    "upright.career": {
        "en": "upright career meaning",
        "vi": "ý nghĩa sự nghiệp khi xuôi chiều",
    },
    "upright.finances": {
        "en": "upright finances meaning",
        "vi": "ý nghĩa tài chính khi xuôi chiều",
    },
    "upright.feelings": {
        "en": "upright feelings meaning",
        "vi": "ý nghĩa cảm xúc khi xuôi chiều",
    },
    "upright.actions": {
        "en": "upright actions meaning",
        "vi": "ý nghĩa hành động khi xuôi chiều",
    },
    "reversed.summary": {
        "en": "reversed meaning",
        "vi": "ý nghĩa ngược chiều",
    },
    "reversed.love": {
        "en": "reversed love meaning",
        "vi": "ý nghĩa tình yêu khi ngược chiều",
    },
    "reversed.career": {
        "en": "reversed career meaning",
        "vi": "ý nghĩa sự nghiệp khi ngược chiều",
    },
    "reversed.finances": {
        "en": "reversed finances meaning",
        "vi": "ý nghĩa tài chính khi ngược chiều",
    },
    "reversed.feelings": {
        "en": "reversed feelings meaning",
        "vi": "ý nghĩa cảm xúc khi ngược chiều",
    },
    "reversed.actions": {
        "en": "reversed actions meaning",
        "vi": "ý nghĩa hành động khi ngược chiều",
    },
}

DEFAULT_FACET_ORDER = (
    "overview",
    "upright.summary",
    "reversed.summary",
    "upright.love",
    "reversed.love",
    "upright.career",
    "reversed.career",
    "upright.finances",
    "reversed.finances",
    "upright.feelings",
    "reversed.feelings",
    "upright.actions",
    "reversed.actions",
    "symbols",
    "correspondences",
)


@dataclass(frozen=True)
class StudyDraw:
    user_id: str
    mode: str
    language: str
    cycle: int
    remaining_in_cycle: int
    card_name: str
    card_image: str | None
    cheatsheet_image: str | None
    facet: str
    facet_label: str
    question: str
    hint: str
    created_at: str


def load_cards(language: str) -> list[dict]:
    return json.loads(SOURCE_FILES[language].read_text(encoding="utf-8"))


def load_state(path: Path = STATE_FILE) -> dict:
    if not path.exists():
        return {"schema": STATE_SCHEMA, "users": {}}
    state = json.loads(path.read_text(encoding="utf-8"))
    if state.get("schema") != STATE_SCHEMA:
        raise ValueError(f"Unsupported study state schema in {path}")
    return state


def save_state(state: dict, path: Path = STATE_FILE) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8")


def _card_names(cards: Iterable[dict]) -> list[str]:
    return [clean_text(card.get("name")) for card in cards if clean_text(card.get("name"))]


def _reshuffle(cards: list[dict], rng: random.Random) -> list[str]:
    names = _card_names(cards)
    rng.shuffle(names)
    return names


def _user_state(state: dict, user_id: str) -> dict:
    users = state.setdefault("users", {})
    return users.setdefault(
        user_id,
        {
            "cycle": 1,
            "remaining": [],
            "seen": [],
            "facet_cursor": 0,
            "history": [],
        },
    )


def _has_card_value(card: dict, facet: str) -> bool:
    if facet == "overview":
        return bool(card.get("description") or card.get("upright_keywords"))
    if facet == "correspondences":
        return any(card.get(key) for key in ("type", "element", "astrology", "yes_no"))
    if facet == "symbols":
        return bool(card.get("symbols"))

    orientation, field = facet.split(".", maxsplit=1)
    section = card.get(orientation) or {}
    if field == "summary":
        return bool(section.get("description"))
    return bool(section.get(field) or section.get(f"{field}_keywords"))


def available_facets(card: dict) -> list[str]:
    return [facet for facet in DEFAULT_FACET_ORDER if _has_card_value(card, facet)]


def choose_facet(card: dict, user_state: dict) -> str:
    facets = available_facets(card)
    if not facets:
        return "overview"

    cursor = int(user_state.get("facet_cursor", 0))
    ordered = list(DEFAULT_FACET_ORDER)
    for offset in range(len(ordered)):
        candidate = ordered[(cursor + offset) % len(ordered)]
        if candidate in facets:
            user_state["facet_cursor"] = cursor + offset + 1
            return candidate

    user_state["facet_cursor"] = cursor + 1
    return facets[0]


def facet_label(facet: str, language: str) -> str:
    return FACET_LABELS.get(facet, FACET_LABELS["overview"]).get(
        language,
        FACET_LABELS.get(facet, FACET_LABELS["overview"])["en"],
    )


def build_question(card_name: str, facet: str, language: str) -> str:
    label = facet_label(facet, language)
    if language == "vi":
        return (
            f"Lá bài: {card_name}. Hãy giải thích {label}. "
            "Trả lời 3-5 ý chính, có ví dụ ngắn nếu nhớ được."
        )
    return (
        f"Card: {card_name}. Explain the {label}. "
        "Answer with 3-5 key points and a short example if you can."
    )


def build_hint(facet: str, language: str) -> str:
    hints = {
        "overview": {
            "vi": "Nêu năng lượng cốt lõi, tình huống thường gặp và một lời khuyên.",
            "en": "Name the core energy, a common situation, and one practical advice.",
        },
        "correspondences": {
            "vi": "Liên hệ bộ bài, nguyên tố, chiêm tinh hoặc yes/no với cách lá vận hành.",
            "en": "Connect suit, element, astrology, or yes/no to how the card behaves.",
        },
        "symbols": {
            "vi": "Chọn 1-2 biểu tượng nổi bật và giải thích chúng gợi điều gì.",
            "en": "Pick 1-2 strong symbols and explain what they suggest.",
        },
        "upright.summary": {
            "vi": "Tập trung vào mặt thuận dòng, bài học chính và hướng hành động.",
            "en": "Focus on the aligned expression, main lesson, and action direction.",
        },
        "reversed.summary": {
            "vi": "Nghĩ về năng lượng bị chặn, thái quá hoặc điểm cần điều chỉnh.",
            "en": "Think about blocked, excessive, or corrective expressions of the card.",
        },
    }

    facet_parts = facet.split(".", maxsplit=1)
    if len(facet_parts) == 2:
        orientation, field = facet_parts
        if language == "vi":
            orientation_text = "xuôi" if orientation == "upright" else "ngược"
            field_text = {
                "love": "tình yêu",
                "career": "sự nghiệp",
                "finances": "tài chính",
                "feelings": "cảm xúc",
                "actions": "hành động",
            }.get(field, "ý nghĩa")
            if orientation == "reversed":
                return (
                    f"Với {field_text}, nhìn mặt {orientation_text}: điều gì đang "
                    "bị kẹt, lệch nhịp hoặc cần điều chỉnh?"
                )
            return (
                f"Với {field_text}, nhìn mặt {orientation_text}: năng lượng này "
                "hỗ trợ điều gì và nên ứng xử ra sao?"
            )

        orientation_text = "upright" if orientation == "upright" else "reversed"
        field_text = {
            "love": "love",
            "career": "career",
            "finances": "finances",
            "feelings": "feelings",
            "actions": "actions",
        }.get(field, "meaning")
        if orientation == "reversed":
            return (
                f"For {field_text}, read the {orientation_text} side: what is "
                "blocked, distorted, or asking for adjustment?"
            )
        return (
            f"For {field_text}, read the {orientation_text} side: what does this "
            "energy support, and what response fits?"
        )

    return hints.get(facet, hints["overview"]).get(language, hints["overview"]["en"])


def draw_card(
    *,
    user_id: str,
    language: str = "vi",
    mode: str = "random",
    state_path: Path = STATE_FILE,
    seed: int | None = None,
) -> StudyDraw:
    cards = load_cards(language)
    cards_by_name = {clean_text(card.get("name")): card for card in cards}
    rng = random.Random(seed)
    state = load_state(state_path)
    current_user = _user_state(state, user_id)

    if not current_user.get("remaining"):
        if current_user.get("seen"):
            current_user["cycle"] = int(current_user.get("cycle", 1)) + 1
        current_user["remaining"] = _reshuffle(cards, rng)
        current_user["seen"] = []

    card_name = current_user["remaining"].pop(0)
    card = cards_by_name[card_name]
    current_user["seen"].append(card_name)
    facet = choose_facet(card, current_user)
    now = datetime.now(timezone.utc).isoformat()

    draw = StudyDraw(
        user_id=user_id,
        mode=mode,
        language=language,
        cycle=int(current_user.get("cycle", 1)),
        remaining_in_cycle=len(current_user["remaining"]),
        card_name=card_name,
        card_image=card.get("card_image"),
        cheatsheet_image=card.get("cheatsheet_image"),
        facet=facet,
        facet_label=facet_label(facet, language),
        question=build_question(card_name, facet, language),
        hint=build_hint(facet, language),
        created_at=now,
    )

    history = current_user.setdefault("history", [])
    history.append(asdict(draw))
    current_user["history"] = history[-250:]
    save_state(state, state_path)
    return draw


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["draw"])
    parser.add_argument("--user-id", default="local")
    parser.add_argument("--lang", choices=["en", "vi"], default="vi")
    parser.add_argument("--mode", choices=["daily", "random"], default="random")
    parser.add_argument("--state", type=Path, default=STATE_FILE)
    parser.add_argument("--seed", type=int, default=None)
    return parser.parse_args()


def main() -> None:
    configure_utf8_stdio()
    args = parse_args()
    if args.command == "draw":
        draw = draw_card(
            user_id=args.user_id,
            language=args.lang,
            mode=args.mode,
            state_path=args.state,
            seed=args.seed,
        )
        print(json.dumps(asdict(draw), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
