import json
import re
import time
from pathlib import Path
from typing import Iterable, Optional
from urllib.parse import urljoin, urlparse

import requests
from bs4 import BeautifulSoup, Tag

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/120.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "vi,en-US;q=0.9,en;q=0.8",
}
TIMEOUT = 20
MAX_RETRIES = 3
REQUEST_DELAY = 1.0
IMAGE_DELAY = 0.25
START_URL = "https://hoctarot.com/category/78-l-bi/"
OUTPUT_DIR = Path("data/images")
MANIFEST_PATH = OUTPUT_DIR / "manifest.json"
CARD_LINK_RE = re.compile(r"^https://hoctarot\.com/y-nghia-la-bai-[^/]+/?$")
BAD_IMAGE_HINTS = (
    "avatar",
    "author",
    "logo",
    "icon",
    "banner",
    "asset-",
    "facebook",
    "youtube",
    "ads",
)


def _slug_from_url(url: str) -> str:
    return urlparse(url).path.rstrip("/").split("/")[-1]


def _card_slug_from_page_url(url: str) -> str:
    slug = _slug_from_url(url)
    prefix = "y-nghia-la-bai-"
    suffix = "-trong-tarot"

    if slug.startswith(prefix):
        slug = slug[len(prefix):]
    if slug.endswith(suffix):
        slug = slug[: -len(suffix)]
    if slug.startswith("la-"):
        slug = slug[3:]

    return slug


def _request(session: requests.Session, url: str, *, stream: bool = False) -> requests.Response:
    last_error: Optional[Exception] = None
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            response = session.get(url, timeout=TIMEOUT, stream=stream)
            response.raise_for_status()
            return response
        except requests.RequestException as exc:
            last_error = exc
            if attempt < MAX_RETRIES:
                time.sleep(2 ** attempt)
    raise RuntimeError(f"request failed for {url}: {last_error}")


def _get_html(session: requests.Session, url: str) -> str:
    response = _request(session, url)
    response.encoding = response.encoding or "utf-8"
    return response.text


def _discover_card_links(session: requests.Session) -> list[str]:
    links: list[str] = []
    seen_pages: set[str] = set()
    seen_links: set[str] = set()
    next_url: Optional[str] = START_URL

    while next_url and next_url not in seen_pages:
        seen_pages.add(next_url)
        html = _get_html(session, next_url)
        soup = BeautifulSoup(html, "lxml")

        for anchor in soup.select("main a[href], .site-main a[href], article a[href]"):
            href = anchor.get("href")
            if not href:
                continue
            absolute = urljoin(next_url, href)
            if CARD_LINK_RE.match(absolute) and absolute not in seen_links:
                seen_links.add(absolute)
                links.append(absolute)

        next_anchor = soup.select_one("a.next.page-numbers[href]")
        next_url = urljoin(next_url, next_anchor["href"]) if next_anchor else None

        if next_url:
            time.sleep(REQUEST_DELAY)

    return links


def _candidate_image_urls(soup: BeautifulSoup, page_url: str) -> Iterable[str]:
    meta_selectors = (
        'meta[property="og:image"]',
        'meta[name="twitter:image"]',
        'meta[property="og:image:secure_url"]',
    )
    for selector in meta_selectors:
        for meta in soup.select(selector):
            content = meta.get("content")
            if content:
                yield urljoin(page_url, content)

    image_selectors = (
        "article img.wp-post-image",
        ".single-content img",
        ".entry-content img",
        "article img",
    )
    for selector in image_selectors:
        for img in soup.select(selector):
            src = img.get("data-src") or img.get("data-lazy-src") or img.get("src")
            if src:
                yield urljoin(page_url, src)


def _looks_like_card_image(image_url: str, page_slug: str) -> bool:
    lower_url = image_url.lower()
    if any(hint in lower_url for hint in BAD_IMAGE_HINTS):
        return False

    filename = Path(urlparse(lower_url).path).name
    if not filename:
        return False

    slug_tokens = [token for token in re.split(r"[-_]+", page_slug) if token and token not in {"y", "nghia", "la", "bai", "trong", "tarot"}]
    if slug_tokens and sum(token in filename for token in slug_tokens) >= 2:
        return True

    return "/wp-content/uploads/" in lower_url


def _pick_image_url(page_url: str, html: str) -> str:
    soup = BeautifulSoup(html, "lxml")
    page_slug = _slug_from_url(page_url)
    seen: set[str] = set()

    fallback: Optional[str] = None
    for candidate in _candidate_image_urls(soup, page_url):
        if candidate in seen:
            continue
        seen.add(candidate)
        if fallback is None:
            fallback = candidate
        if _looks_like_card_image(candidate, page_slug):
            return candidate

    if fallback:
        return fallback
    raise RuntimeError(f"no image found for {page_url}")


def _download_image(session: requests.Session, page_url: str, image_url: str) -> str:
    suffix = Path(urlparse(image_url).path).suffix or ".jpg"
    output_path = OUTPUT_DIR / f"{_card_slug_from_page_url(page_url)}{suffix}"

    if output_path.exists() and output_path.stat().st_size > 0:
        return output_path.as_posix()

    output_path.parent.mkdir(parents=True, exist_ok=True)
    response = _request(session, image_url, stream=True)
    with output_path.open("wb") as handle:
        for chunk in response.iter_content(chunk_size=8192):
            if chunk:
                handle.write(chunk)
    return output_path.as_posix()


def main() -> None:
    session = requests.Session()
    session.headers.update(HEADERS)

    print("Discovering hoctarot card links...")
    card_links = _discover_card_links(session)
    print(f"Found {len(card_links)} card links")

    manifest: list[dict[str, str]] = []
    failures: list[str] = []

    for index, page_url in enumerate(card_links, start=1):
        print(f"[{index:02}/{len(card_links):02}] {page_url}")
        try:
            html = _get_html(session, page_url)
            image_url = _pick_image_url(page_url, html)
            image_path = _download_image(session, page_url, image_url)
            manifest.append(
                {
                    "page_url": page_url,
                    "image_url": image_url,
                    "image_path": image_path,
                }
            )
        except Exception as exc:
            print(f"  failed: {exc}")
            failures.append(page_url)

        time.sleep(REQUEST_DELAY)
        time.sleep(IMAGE_DELAY)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    print(f"Saved {len(manifest)} images to {OUTPUT_DIR}")
    if failures:
        print(f"Failed ({len(failures)}):")
        for page_url in failures:
            print(f"- {page_url}")


if __name__ == "__main__":
    main()
