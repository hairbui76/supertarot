from pathlib import Path
from typing import Iterable

IMAGE_DIR = Path("data/images")


def card_image_path(card_name: str) -> str | None:
    slug = card_name.lower().replace(" ", "-")
    candidates = [slug]
    if slug.startswith("the-"):
        candidates.append(slug[4:])

    for candidate in candidates:
        path = IMAGE_DIR / f"{candidate}.jpg"
        if path.exists():
            return path.as_posix()

    return None


def attach_card_image_refs(cards: Iterable[dict]) -> None:
    for card in cards:
        card["card_image"] = card_image_path(card.get("name", ""))