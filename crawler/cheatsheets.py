from pathlib import Path
from typing import Iterable

import requests

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/120.0.0.0 Safari/537.36"
    )
}
TIMEOUT = 30


def download_cheatsheet_images(cards: Iterable[dict]) -> None:
    """Download missing card cheatsheet images referenced by parsed cards."""
    session = requests.Session()
    session.headers.update(HEADERS)

    saved = 0
    skipped = 0
    failed: list[str] = []

    for card in cards:
        image_url = card.get("cheatsheet_image_url")
        image_path = card.get("cheatsheet_image")
        if not image_url or not image_path:
            failed.append(card.get("name", "<unknown>"))
            continue

        path = Path(image_path)
        if path.exists() and path.stat().st_size > 0:
            skipped += 1
            continue

        try:
            path.parent.mkdir(parents=True, exist_ok=True)
            response = session.get(image_url, timeout=TIMEOUT)
            response.raise_for_status()
            path.write_bytes(response.content)
            saved += 1
        except requests.RequestException:
            failed.append(card.get("name", "<unknown>"))

    print(f"Cheatsheets: {saved} downloaded, {skipped} cached")
    if failed:
        print(f"Cheatsheet download failed ({len(failed)}): {', '.join(failed)}")
