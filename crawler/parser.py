import re
from pathlib import Path
from typing import Optional
from urllib.parse import urlparse

from bs4 import BeautifulSoup, Tag

from .models import Meaning, TarotCard
from .reference import get_astrology, get_element, get_type, get_yes_no


def _clean(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def _text_of(tag: Tag) -> str:
    return _clean(tag.get_text(separator=" "))


def _find_h3_next_p(soup: Tag, *keywords: str) -> Optional[str]:
    """Find first h3 whose text contains ALL keywords, return next sibling <p> text."""
    def matches(s: Optional[str]) -> bool:
        return bool(s) and all(kw in s for kw in keywords)

    h3 = soup.find("h3", string=matches)
    if not h3:
        return None
    p = h3.find_next_sibling("p")
    return _text_of(p) if p else None


def _parse_keywords(soup: Tag) -> tuple[list[str], list[str]]:
    h2 = soup.find("h2", string=lambda s: s and "Keywords" in s)
    if not h2:
        return [], []
    table = h2.find_next("table")
    if not table:
        return [], []
    rows = table.find_all("tr")
    if len(rows) < 2:
        return [], []
    tds = rows[1].find_all("td")
    if len(tds) < 2:
        return [], []

    upright = [k.strip() for k in tds[0].get_text().split(",") if k.strip()]
    reversed_ = [k.strip() for k in tds[1].get_text().split(",") if k.strip()]
    return upright, reversed_


def _parse_description(soup: Tag) -> Optional[str]:
    h2 = soup.find("h2", string=lambda s: s and "Tarot Card Description" in s)
    if not h2:
        return None
    p = h2.find_next_sibling("p")
    return _text_of(p) if p else None


def _parse_section_desc(soup: Tag, section_id: str) -> Optional[str]:
    """Collect paragraphs after <h2 id="up/rev"> until the next <table>."""
    h2 = soup.find("h2", id=section_id)
    if not h2:
        return None

    parts: list[str] = []
    for sibling in h2.next_siblings:
        if not isinstance(sibling, Tag):
            continue
        if sibling.name == "table":
            break
        if sibling.name in ("p", "blockquote"):
            text = _text_of(sibling)
            if text:
                parts.append(text)

    return "\n\n".join(parts) if parts else None


def _normalize_image_url(src: Optional[str]) -> Optional[str]:
    if not src:
        return None
    if src.startswith("//"):
        return "https:" + src
    if src.startswith(("http://", "https://")):
        return src
    return "https://labyrinthos.co" + src


def _parse_cheatsheet_image_url(content: Tag) -> Optional[str]:
    candidates: list[Tag] = []
    for img in content.find_all("img"):
        text = " ".join(
            part
            for part in (img.get("src"), img.get("data-src"), img.get("alt"))
            if part
        ).lower()
        if "cheat" in text:
            candidates.append(img)

    if not candidates:
        return None

    img = candidates[-1]
    return _normalize_image_url(img.get("src") or img.get("data-src"))


def _card_slug_from_url(url: str) -> str:
    slug = urlparse(url).path.rstrip("/").split("/")[-1]
    for suffix in (
        "-meaning-major-arcana-tarot-card-meanings",
        "-meaning-tarot-card-meanings",
    ):
        if slug.endswith(suffix):
            return slug[: -len(suffix)]
    return slug


def _cheatsheet_image_path(card_url: str, image_url: Optional[str]) -> Optional[str]:
    if image_url is None:
        return None
    ext = Path(urlparse(image_url).path).suffix or ".png"
    return (Path("data") / "cheatsheets" / f"{_card_slug_from_url(card_url)}{ext}").as_posix()


def parse_card(html: str, name: str, url: str) -> TarotCard:
    soup = BeautifulSoup(html, "lxml")

    # Scope to article body to avoid nav/footer noise.
    # The div has itemprop=" articleBody " (with spaces) in the saved HTML;
    # fallback to class="rte" for live pages, then full soup.
    content: Tag = (
        soup.find(attrs={"itemprop": lambda v: v and "articleBody" in v})
        or soup.find("div", class_="rte")
        or soup
    )

    upright_kw, reversed_kw = _parse_keywords(content)

    upright = Meaning(
        description=_parse_section_desc(content, "up"),
        love=_find_h3_next_p(content, "Love", "Upright"),
        career=_find_h3_next_p(content, "Career", "Upright"),
        finances=_find_h3_next_p(content, "Finances", "Upright"),
        feelings=_find_h3_next_p(content, "Feelings", "Upright"),
        actions=_find_h3_next_p(content, "Actions", "Upright"),
    )

    reversed_ = Meaning(
        description=_parse_section_desc(content, "rev"),
        love=_find_h3_next_p(content, "Love", "Reversed"),
        career=_find_h3_next_p(content, "Career", "Reversed"),
        finances=_find_h3_next_p(content, "Finances", "Reversed"),
        feelings=_find_h3_next_p(content, "Feelings", "Reversed"),
        actions=_find_h3_next_p(content, "Actions", "Reversed"),
    )

    card_type = get_type(url)
    cheatsheet_image_url = _parse_cheatsheet_image_url(content)

    return TarotCard(
        name=name,
        url=url,
        type=card_type,
        element=get_element(card_type, name),
        astrology=get_astrology(name),
        yes_no=get_yes_no(name),
        cheatsheet_image=_cheatsheet_image_path(url, cheatsheet_image_url),
        cheatsheet_image_url=cheatsheet_image_url,
        upright_keywords=upright_kw,
        reversed_keywords=reversed_kw,
        description=_parse_description(content),
        upright=upright,
        reversed=reversed_,
    )
