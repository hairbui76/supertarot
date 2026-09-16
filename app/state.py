"""Persistent Telegram bot runtime state."""

from __future__ import annotations

import json
from dataclasses import asdict, is_dataclass
from pathlib import Path
from typing import Iterable

SCHEMA = "supertarot.telegram_bot_state.v1"


class TelegramBotState:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.data = self._load()

    def _load(self) -> dict:
        if not self.path.exists():
            return {"schema": SCHEMA, "chats": {}}

        data = json.loads(self.path.read_text(encoding="utf-8"))
        if data.get("schema") != SCHEMA:
            raise ValueError(
                f"Unsupported Telegram bot state schema in {self.path}"
            )
        data.setdefault("chats", {})
        return data

    def save(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.path.write_text(
            json.dumps(self.data, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

    def chat(self, chat_id: int | str) -> dict:
        return self.data.setdefault("chats", {}).setdefault(
            str(chat_id),
            {
                "language": "vi",
                "schedule": None,
                "timezone": None,
                "telegram_user_id": None,
                "last_daily_date": None,
                "active_draw": None,
                "learn_menu": None,
            },
        )

    def set_language(self, chat_id: int | str, language: str) -> None:
        self.chat(chat_id)["language"] = language
        self.save()

    def set_user(
        self,
        chat_id: int | str,
        telegram_user_id: int | str | None,
    ) -> None:
        if telegram_user_id is not None:
            self.chat(chat_id)["telegram_user_id"] = str(telegram_user_id)
            self.save()

    def set_active_draw(self, chat_id: int | str, draw: object) -> None:
        self.chat(chat_id)["active_draw"] = (
            asdict(draw) if is_dataclass(draw) else draw
        )
        self.save()

    def clear_active_draw(self, chat_id: int | str) -> None:
        self.chat(chat_id)["active_draw"] = None
        self.save()

    def set_learn_menu(
        self,
        chat_id: int | str,
        *,
        step: str,
        suit: str | None = None,
    ) -> None:
        self.chat(chat_id)["learn_menu"] = {
            "step": step,
            "suit": suit,
        }
        self.save()

    def clear_learn_menu(self, chat_id: int | str) -> None:
        self.chat(chat_id)["learn_menu"] = None
        self.save()

    def set_schedule(
        self,
        chat_id: int | str,
        *,
        telegram_user_id: int | str | None,
        language: str,
        hhmm: str,
        timezone: str,
    ) -> None:
        chat = self.chat(chat_id)
        chat["telegram_user_id"] = str(telegram_user_id or chat_id)
        chat["language"] = language
        chat["schedule"] = hhmm
        chat["timezone"] = timezone
        chat["last_daily_date"] = None
        self.save()

    def clear_schedule(self, chat_id: int | str) -> None:
        chat = self.chat(chat_id)
        chat["schedule"] = None
        chat["last_daily_date"] = None
        self.save()

    def mark_daily_sent(self, chat_id: int | str, date_text: str) -> None:
        self.chat(chat_id)["last_daily_date"] = date_text
        self.save()

    def scheduled_chats(self) -> Iterable[tuple[str, dict]]:
        for chat_id, chat in self.data.get("chats", {}).items():
            if chat.get("schedule"):
                yield chat_id, chat
