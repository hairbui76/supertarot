import time
import logging
from pathlib import Path
from typing import Optional

import requests

logger = logging.getLogger(__name__)

DELAY = 1.5
MAX_RETRIES = 3
TIMEOUT = 15
CACHE_DIR = Path("data/raw")
HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/120.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
}


def _slug(url: str) -> str:
    return url.rstrip("/").split("/")[-1]


def _cache_path(url: str) -> Path:
    return CACHE_DIR / f"{_slug(url)}.html"


def fetch_one(url: str) -> Optional[str]:
    cache = _cache_path(url)
    if cache.exists():
        logger.debug(f"[cache] {cache.name}")
        return cache.read_text(encoding="utf-8")

    for attempt in range(1, MAX_RETRIES + 1):
        try:
            resp = requests.get(url, headers=HEADERS, timeout=TIMEOUT)
            resp.raise_for_status()
            html = resp.text
            cache.write_text(html, encoding="utf-8")
            return html
        except requests.RequestException as e:
            logger.warning(f"[attempt {attempt}/{MAX_RETRIES}] {url}: {e}")
            if attempt < MAX_RETRIES:
                time.sleep(2 ** attempt)

    logger.error(f"[failed] {url}")
    return None


def fetch_all(links: list[dict]) -> dict[str, Optional[str]]:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    results: dict[str, Optional[str]] = {}
    total = len(links)

    for i, entry in enumerate(links, 1):
        name = entry["name"]
        url = entry["url"]
        cached = _cache_path(url).exists()

        print(f"[{i:3}/{total}] {'(cache)' if cached else '(fetch)'} {name}")
        html = fetch_one(url)
        results[name] = html

        if not cached and html is not None:
            time.sleep(DELAY)

    return results
