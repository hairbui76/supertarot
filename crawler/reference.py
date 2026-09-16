"""Static lookup tables for Type, Element, and Astrology correspondences."""
from typing import Optional

TYPE_FROM_URL: dict[str, str] = {
    "major-arcana": "Major Arcana",
    "cups":         "Cups",
    "wands":        "Wands",
    "swords":       "Swords",
    "pentacles":    "Pentacles",
}

ELEMENT_FROM_TYPE: dict[str, Optional[str]] = {
    "Cups":         "Water",
    "Wands":        "Fire",
    "Swords":       "Air",
    "Pentacles":    "Earth",
    "Major Arcana": None,
}

# Sources:
# - Astrology and Tarot Correspondences_ The Minor Arcana Pip Cards – Labyrinthos.html
# - Saved Labyrinthos card cheatsheets in data/cheatsheets
#
# Aces represent the whole element (3 zodiac signs); pip cards 2-10 have
# planet+sign. Court cards and Major Arcana are read from the card cheatsheets.
ASTROLOGY: dict[str, str] = {
    # Aces
    "Ace of Wands":     "Aries, Leo, Sagittarius",
    "Ace of Cups":      "Cancer, Scorpio, Pisces",
    "Ace of Swords":    "Libra, Gemini, Aquarius",
    "Ace of Pentacles": "Taurus, Virgo, Capricorn",
    # Aries — Cardinal Fire
    "Two of Wands":     "Mars in Aries",
    "Three of Wands":   "Sun in Aries",
    "Four of Wands":    "Venus in Aries",
    # Taurus — Fixed Earth
    "Five of Pentacles":  "Mercury in Taurus",
    "Six of Pentacles":   "Moon in Taurus",
    "Seven of Pentacles": "Saturn in Taurus",
    # Gemini — Mutable Air
    "Eight of Swords": "Jupiter in Gemini",
    "Nine of Swords":  "Mars in Gemini",
    "Ten of Swords":   "Sun in Gemini",
    # Cancer — Cardinal Water
    "Two of Cups":   "Venus in Cancer",
    "Three of Cups": "Mercury in Cancer",
    "Four of Cups":  "Moon in Cancer",
    # Leo — Fixed Fire
    "Five of Wands":  "Saturn in Leo",
    "Six of Wands":   "Jupiter in Leo",
    "Seven of Wands": "Mars in Leo",
    # Virgo — Mutable Earth
    "Eight of Pentacles": "Sun in Virgo",
    "Nine of Pentacles":  "Venus in Virgo",
    "Ten of Pentacles":   "Mercury in Virgo",
    # Libra — Cardinal Air
    "Two of Swords":   "Moon in Libra",
    "Three of Swords": "Saturn in Libra",
    "Four of Swords":  "Jupiter in Libra",
    # Scorpio — Fixed Water
    "Five of Cups":  "Mars in Scorpio",
    "Six of Cups":   "Sun in Scorpio",
    "Seven of Cups": "Venus in Scorpio",
    # Sagittarius — Mutable Fire
    "Eight of Wands": "Mercury in Sagittarius",
    "Nine of Wands":  "Moon in Sagittarius",
    "Ten of Wands":   "Saturn in Sagittarius",
    # Capricorn — Cardinal Earth
    "Two of Pentacles":   "Jupiter in Capricorn",
    "Three of Pentacles": "Mars in Capricorn",
    "Four of Pentacles":  "Sun in Capricorn",
    # Aquarius — Fixed Air
    "Five of Swords":  "Venus in Aquarius",
    "Six of Swords":   "Mercury in Aquarius",
    "Seven of Swords": "Moon in Aquarius",
    # Pisces — Mutable Water
    "Eight of Cups": "Saturn in Pisces",
    "Nine of Cups":  "Jupiter in Pisces",
    "Ten of Cups":   "Mars in Pisces",
    # Court cards
    "Page of Wands":       "Cancer, Leo, Virgo",
    "Knight of Wands":     "20° Cancer - 20° Leo",
    "Queen of Wands":      "20° Pisces - 20° Aries",
    "King of Wands":       "20° Scorpio - 20° Sagittarius",
    "Page of Cups":        "Libra, Scorpio, Sagittarius",
    "Knight of Cups":      "20° Libra - 20° Scorpio",
    "Queen of Cups":       "20° Gemini - 20° Cancer",
    "King of Cups":        "20° Aquarius - 20° Pisces",
    "Page of Swords":      "Capricorn, Aquarius, Pisces",
    "Knight of Swords":    "20° Capricorn - 20° Aquarius",
    "Queen of Swords":     "20° Virgo - 20° Libra",
    "King of Swords":      "20° Taurus - 20° Gemini",
    "Page of Pentacles":   "Aries, Taurus, Gemini",
    "Knight of Pentacles": "20° Aries - 20° Taurus",
    "Queen of Pentacles":  "20° Sagittarius - 20° Capricorn",
    "King of Pentacles":   "20° Leo - 20° Virgo",
    # Major Arcana
    "The Fool":             "Uranus",
    "The Magician":         "Mercury",
    "The High Priestess":   "Moon",
    "The Empress":          "Venus",
    "The Emperor":          "Aries",
    "The Hierophant":       "Taurus",
    "The Lovers":           "Gemini",
    "The Chariot":          "Cancer",
    "Strength":             "Leo",
    "The Hermit":           "Virgo",
    "Justice":              "Libra",
    "The Hanged Man":       "Neptune",
    "Death":                "Scorpio",
    "Temperance":           "Sagittarius",
    "The Devil":            "Capricorn",
    "The Tower":            "Mars",
    "The Star":             "Aquarius",
    "The Moon":             "Pisces",
    "The Sun":              "Sun",
    "Judgement":            "Pluto",
    "The World":            "Saturn",
    "The Wheel of Fortune": "Jupiter",
}

ELEMENT_BY_CARD: dict[str, str] = {
    "The Fool":             "Air",
    "The Magician":         "Air",
    "The High Priestess":   "Water",
    "The Empress":          "Earth",
    "The Emperor":          "Fire",
    "The Hierophant":       "Earth",
    "The Lovers":           "Air",
    "The Chariot":          "Water",
    "Strength":             "Fire",
    "The Hermit":           "Earth",
    "Justice":              "Air",
    "The Hanged Man":       "Water",
    "Death":                "Water",
    "Temperance":           "Fire",
    "The Devil":            "Earth",
    "The Tower":            "Fire",
    "The Star":             "Air",
    "The Moon":             "Water",
    "The Sun":              "Fire",
    "Judgement":            "Fire",
    "The World":            "Earth",
    "The Wheel of Fortune": "Fire",
}

YES_NO: dict[str, str] = {
    # Wands
    "Ace of Wands":    "Yes",
    "Two of Wands":    "Yes",
    "Three of Wands":  "Yes",
    "Four of Wands":   "Yes",
    "Five of Wands":   "No",
    "Six of Wands":    "Yes",
    "Seven of Wands":  "No",
    "Eight of Wands":  "Yes",
    "Nine of Wands":   "Yes",
    "Ten of Wands":    "No",
    "Page of Wands":   "Yes",
    "Knight of Wands": "Yes",
    "Queen of Wands":  "Yes",
    "King of Wands":   "Yes",
    # Cups
    "Ace of Cups":    "Yes",
    "Two of Cups":    "Yes",
    "Three of Cups":  "Yes",
    "Four of Cups":   "Maybe",
    "Five of Cups":   "No",
    "Six of Cups":    "Yes",
    "Seven of Cups":  "No",
    "Eight of Cups":  "Maybe",
    "Nine of Cups":   "Yes",
    "Ten of Cups":    "Yes",
    "Page of Cups":   "Yes",
    "Knight of Cups": "Yes",
    "Queen of Cups":  "Yes",
    "King of Cups":   "Yes",
    # Swords
    "Ace of Swords":    "Yes",
    "Two of Swords":    "Maybe",
    "Three of Swords":  "No",
    "Four of Swords":   "Maybe",
    "Five of Swords":   "No",
    "Six of Swords":    "Yes",
    "Seven of Swords":  "No",
    "Eight of Swords":  "No",
    "Nine of Swords":   "No",
    "Ten of Swords":    "No",
    "Page of Swords":   "Yes",
    "Knight of Swords": "Yes",
    "Queen of Swords":  "Yes",
    "King of Swords":   "Yes",
    # Pentacles
    "Ace of Pentacles":    "Yes",
    "Two of Pentacles":    "Maybe",
    "Three of Pentacles":  "Yes",
    "Four of Pentacles":   "No",
    "Five of Pentacles":   "No",
    "Six of Pentacles":    "Yes",
    "Seven of Pentacles":  "Maybe",
    "Eight of Pentacles":  "Yes",
    "Nine of Pentacles":   "Yes",
    "Ten of Pentacles":    "Yes",
    "Page of Pentacles":   "Yes",
    "Knight of Pentacles": "Yes",
    "Queen of Pentacles":  "Yes",
    "King of Pentacles":   "Yes",
    # Major Arcana
    "The Fool":             "Yes",
    "The Magician":         "Yes",
    "The High Priestess":   "Maybe",
    "The Empress":          "Yes",
    "The Emperor":          "Maybe",
    "The Hierophant":       "Maybe",
    "The Lovers":           "Yes",
    "The Chariot":          "Yes",
    "Strength":             "Yes",
    "The Hermit":           "Maybe",
    "Justice":              "Maybe",
    "The Hanged Man":       "Maybe",
    "Death":                "No",
    "Temperance":           "Yes",
    "The Devil":            "No",
    "The Tower":            "No",
    "The Star":             "Yes",
    "The Moon":             "No",
    "The Sun":              "Yes",
    "Judgement":            "Yes",
    "The World":            "Yes",
    "The Wheel of Fortune": "Yes",
}


def get_type(url: str) -> Optional[str]:
    url_lower = url.lower()
    for keyword, type_name in TYPE_FROM_URL.items():
        if keyword in url_lower:
            return type_name
    return None


def get_element(card_type: Optional[str], card_name: Optional[str] = None) -> Optional[str]:
    if card_name is not None and card_name in ELEMENT_BY_CARD:
        return ELEMENT_BY_CARD[card_name]
    if card_type is None:
        return None
    return ELEMENT_FROM_TYPE.get(card_type)


def get_astrology(card_name: str) -> Optional[str]:
    return ASTROLOGY.get(card_name)


def get_yes_no(card_name: str) -> Optional[str]:
    return YES_NO.get(card_name)
