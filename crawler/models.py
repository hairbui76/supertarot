from dataclasses import dataclass, field
from typing import Optional


@dataclass
class Meaning:
    description: Optional[str] = None
    love: Optional[str] = None
    career: Optional[str] = None
    finances: Optional[str] = None
    feelings: Optional[str] = None
    actions: Optional[str] = None

    def to_dict(self) -> dict:
        return {
            "description": self.description,
            "love": self.love,
            "career": self.career,
            "finances": self.finances,
            "feelings": self.feelings,
            "actions": self.actions,
        }


@dataclass
class TarotCard:
    name: str
    url: str
    type: Optional[str] = None
    element: Optional[str] = None
    astrology: Optional[str] = None
    yes_no: Optional[str] = None
    cheatsheet_image: Optional[str] = None
    cheatsheet_image_url: Optional[str] = None
    upright_keywords: list = field(default_factory=list)
    reversed_keywords: list = field(default_factory=list)
    description: Optional[str] = None
    upright: Meaning = field(default_factory=Meaning)
    reversed: Meaning = field(default_factory=Meaning)

    def to_dict(self) -> dict:
        return {
            "name": self.name,
            "url": self.url,
            "type": self.type,
            "element": self.element,
            "astrology": self.astrology,
            "yes_no": self.yes_no,
            "cheatsheet_image": self.cheatsheet_image,
            "cheatsheet_image_url": self.cheatsheet_image_url,
            "upright_keywords": self.upright_keywords,
            "reversed_keywords": self.reversed_keywords,
            "description": self.description,
            "upright": self.upright.to_dict(),
            "reversed": self.reversed.to_dict(),
        }
