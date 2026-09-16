"""Canonical tarot deck ordering.

The crawled JSON is stored in alphabetical order because that is how the
source site lists the cards. Anywhere a human browses the deck we want the
traditional order instead: Major Arcana 0-21, then each suit from Ace to
King. Card names are English in both the EN and VI datasets, so a single
lookup table covers both languages.
"""

from __future__ import annotations

MAJOR_ARCANA_ORDER = [
    "The Fool",
    "The Magician",
    "The High Priestess",
    "The Empress",
    "The Emperor",
    "The Hierophant",
    "The Lovers",
    "The Chariot",
    "Strength",
    "The Hermit",
    "The Wheel of Fortune",
    "Justice",
    "The Hanged Man",
    "Death",
    "Temperance",
    "The Devil",
    "The Tower",
    "The Star",
    "The Moon",
    "The Sun",
    "Judgement",
    "The World",
]

SUIT_ORDER = ["Wands", "Cups", "Swords", "Pentacles"]

RANK_ORDER = [
    "Ace",
    "Two",
    "Three",
    "Four",
    "Five",
    "Six",
    "Seven",
    "Eight",
    "Nine",
    "Ten",
    "Page",
    "Knight",
    "Queen",
    "King",
]

_MAJOR_INDEX = {
    name.casefold(): index for index, name in enumerate(MAJOR_ARCANA_ORDER)
}
_SUIT_INDEX = {name.casefold(): index for index, name in enumerate(SUIT_ORDER)}
_RANK_INDEX = {name.casefold(): index for index, name in enumerate(RANK_ORDER)}

# Major Arcana first, then the four suits.
_MAJOR_GROUP = 0
_MINOR_GROUP_OFFSET = 1
# Unknown names sort last instead of raising, so a data typo degrades to an
# alphabetical tail rather than breaking the menu.
_UNKNOWN_GROUP = _MINOR_GROUP_OFFSET + len(SUIT_ORDER)


def deck_position(name: str) -> tuple[int, int, str]:
    """Sort key placing a card name in traditional deck order."""
    cleaned = " ".join((name or "").split())
    folded = cleaned.casefold()

    major = _MAJOR_INDEX.get(folded)
    if major is not None:
        return (_MAJOR_GROUP, major, folded)

    rank, separator, suit = cleaned.partition(" of ")
    if separator:
        suit_index = _SUIT_INDEX.get(suit.casefold())
        rank_index = _RANK_INDEX.get(rank.casefold())
        if suit_index is not None and rank_index is not None:
            return (_MINOR_GROUP_OFFSET + suit_index, rank_index, folded)

    return (_UNKNOWN_GROUP, 0, folded)


def sort_cards(cards: list[dict]) -> list[dict]:
    """Return cards ordered by traditional deck position."""
    return sorted(cards, key=lambda card: deck_position(card.get("name") or ""))
