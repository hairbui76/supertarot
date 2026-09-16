"""Small Telegram Bot API client based on requests."""

from __future__ import annotations

from pathlib import Path
import json
from typing import Any

import requests

TELEGRAM_MESSAGE_LIMIT = 4096
TELEGRAM_CAPTION_LIMIT = 1024


class TelegramClient:
    def __init__(self, token: str) -> None:
        self.base_url = f"https://api.telegram.org/bot{token}"
        self.session = requests.Session()

    def request(
        self,
        method: str,
        *,
        data: dict[str, Any] | None = None,
        files: dict[str, Any] | None = None,
        timeout: int = 30,
    ) -> Any:
        response = self.session.post(
            f"{self.base_url}/{method}",
            data=data,
            files=files,
            timeout=timeout,
        )
        response.raise_for_status()
        payload = response.json()
        if not payload.get("ok"):
            raise RuntimeError(f"Telegram API error in {method}: {payload}")
        return payload.get("result")

    def get_updates(self, *, offset: int | None, timeout: int) -> list[dict]:
        data: dict[str, Any] = {
            "timeout": timeout,
            "allowed_updates": '["message", "callback_query"]',
        }
        if offset is not None:
            data["offset"] = offset
        result = self.request("getUpdates", data=data, timeout=timeout + 10)
        return list(result or [])

    def send_chat_action(
        self,
        chat_id: int | str,
        action: str = "typing",
    ) -> None:
        self.request(
            "sendChatAction",
            data={"chat_id": str(chat_id), "action": action},
        )

    def send_message(
        self,
        chat_id: int | str,
        text: str,
        *,
        reply_markup: dict[str, Any] | None = None,
        parse_mode: str | None = None,
    ) -> None:
        chunks = split_text(text, TELEGRAM_MESSAGE_LIMIT)
        for chunk in chunks:
            data: dict[str, Any] = {
                "chat_id": str(chat_id),
                "text": chunk,
                "disable_web_page_preview": "true",
            }
            if reply_markup is not None:
                data["reply_markup"] = json.dumps(reply_markup)
            if parse_mode is not None:
                data["parse_mode"] = parse_mode
            self.request(
                "sendMessage",
                data=data,
            )

    def send_photo(
        self,
        chat_id: int | str,
        photo_path: Path,
        caption: str,
        *,
        reply_markup: dict[str, Any] | None = None,
        parse_mode: str | None = None,
    ) -> None:
        with photo_path.open("rb") as handle:
            data: dict[str, Any] = {
                "chat_id": str(chat_id),
                "caption": caption[:TELEGRAM_CAPTION_LIMIT],
            }
            if reply_markup is not None:
                data["reply_markup"] = json.dumps(reply_markup)
            if parse_mode is not None:
                data["parse_mode"] = parse_mode
            self.request(
                "sendPhoto",
                data=data,
                files={"photo": handle},
                timeout=60,
            )

    def set_my_commands(self, commands: list[dict[str, str]]) -> None:
        self.request(
            "setMyCommands",
            data={"commands": json.dumps(commands)},
        )

    def answer_callback_query(
        self,
        callback_query_id: str,
        *,
        text: str | None = None,
    ) -> None:
        data: dict[str, Any] = {"callback_query_id": callback_query_id}
        if text:
            data["text"] = text
        self.request("answerCallbackQuery", data=data)


def split_text(text: str, limit: int) -> list[str]:
    if len(text) <= limit:
        return [text]

    chunks: list[str] = []
    current = text
    while len(current) > limit:
        split_at = current.rfind("\n", 0, limit)
        if split_at < limit // 2:
            split_at = limit
        chunks.append(current[:split_at].rstrip())
        current = current[split_at:].lstrip()

    if current:
        chunks.append(current)
    return chunks
