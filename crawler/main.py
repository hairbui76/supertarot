import json
import logging
from pathlib import Path

from .card_images import attach_card_image_refs
from .cheatsheets import download_cheatsheet_images
from .fetch import fetch_all
from .parser import parse_card

logging.basicConfig(level=logging.WARNING, format="%(message)s")

LINKS_FILE = Path("tarot-meaning-links.json")
OUTPUT_FILE = Path("data/output/tarot_meanings.json")


def main() -> None:
    links: list[dict] = json.loads(LINKS_FILE.read_text(encoding="utf-8"))
    print(f"Crawling {len(links)} cards...\n")

    html_map = fetch_all(links)

    cards: list[dict] = []
    errors: list[str] = []

    for entry in links:
        name = entry["name"]
        url = entry["url"]
        html = html_map.get(name)

        if html is None:
            errors.append(name)
            continue

        try:
            card = parse_card(html, name, url)
            cards.append(card.to_dict())
        except Exception as exc:
            print(f"[parse error] {name}: {exc}")
            errors.append(name)

    attach_card_image_refs(cards)
    download_cheatsheet_images(cards)

    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_FILE.write_text(
        json.dumps(cards, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    print(f"\n{'='*50}")
    print(f"Done: {len(cards)}/{len(links)} cards saved to {OUTPUT_FILE}")
    if errors:
        print(f"Failed ({len(errors)}): {', '.join(errors)}")


if __name__ == "__main__":
    main()
