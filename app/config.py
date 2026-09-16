"""Runtime configuration for the SuperTarot app."""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from dotenv import load_dotenv

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_LANGUAGE = "vi"
DEFAULT_TIMEZONE = "Asia/Saigon"
DEFAULT_OPENAI_CHAT_MODEL = "gpt-4.1-mini"
DEFAULT_ANTHROPIC_CHAT_MODEL = "claude-haiku-4-5-20251001"
DEFAULT_GOOGLE_CHAT_MODEL = "gemini-2.5-flash"

load_dotenv(PROJECT_ROOT / ".env", override=True)


def env_bool(name: str, default: bool) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


def env_int(name: str, default: int) -> int:
    raw = os.environ.get(name)
    if raw is None or raw.strip() == "":
        return default
    return int(raw)


@dataclass(frozen=True)
class AppConfig:
    telegram_bot_token: str
    language: str
    timezone: str
    study_state_path: Path
    app_state_path: Path
    polling_timeout: int
    send_images: bool
    grading_provider: str
    qa_provider: str
    openai_chat_model: str
    anthropic_chat_model: str
    google_chat_model: str
    answer_top_k: int
    qa_top_k: int

    @classmethod
    def from_env(cls) -> "AppConfig":
        language = (
            os.environ.get(
                "SUPERTAROT_LANGUAGE",
                DEFAULT_LANGUAGE,
            )
            .strip()
            .lower()
        )
        if language not in {"en", "vi"}:
            raise ValueError("SUPERTAROT_LANGUAGE must be 'en' or 'vi'")

        grading_provider = (
            os.environ.get(
                "SUPERTAROT_GRADING_PROVIDER",
                "auto",
            )
            .strip()
            .lower()
        )
        if grading_provider not in {
            "auto",
            "openai",
            "anthropic",
            "google",
            "prompt",
        }:
            raise ValueError(
                "SUPERTAROT_GRADING_PROVIDER must be auto, openai, "
                "anthropic, google, or prompt"
            )

        qa_provider = (
            os.environ.get(
                "SUPERTAROT_QA_PROVIDER",
                "auto",
            )
            .strip()
            .lower()
        )
        if qa_provider not in {"auto", "openai", "anthropic", "google", "context"}:
            raise ValueError(
                "SUPERTAROT_QA_PROVIDER must be auto, openai, anthropic, "
                "google, or context"
            )

        return cls(
            telegram_bot_token=os.environ.get(
                "TELEGRAM_BOT_TOKEN",
                "",
            ).strip(),
            language=language,
            timezone=os.environ.get("SUPERTAROT_TIMEZONE", DEFAULT_TIMEZONE).strip(),
            study_state_path=PROJECT_ROOT
            / os.environ.get(
                "SUPERTAROT_STUDY_STATE",
                "data/bot_state/study_state.json",
            ),
            app_state_path=PROJECT_ROOT
            / os.environ.get(
                "SUPERTAROT_APP_STATE",
                "data/bot_state/telegram_bot_state.json",
            ),
            polling_timeout=env_int("TELEGRAM_POLLING_TIMEOUT", 25),
            send_images=env_bool("TELEGRAM_SEND_IMAGES", True),
            grading_provider=grading_provider,
            qa_provider=qa_provider,
            openai_chat_model=os.environ.get(
                "OPENAI_CHAT_MODEL",
                DEFAULT_OPENAI_CHAT_MODEL,
            ).strip(),
            anthropic_chat_model=os.environ.get(
                "ANTHROPIC_CHAT_MODEL",
                DEFAULT_ANTHROPIC_CHAT_MODEL,
            ).strip(),
            google_chat_model=os.environ.get(
                "GOOGLE_CHAT_MODEL",
                DEFAULT_GOOGLE_CHAT_MODEL,
            ).strip(),
            answer_top_k=env_int("SUPERTAROT_ANSWER_TOP_K", 6),
            qa_top_k=env_int("SUPERTAROT_QA_TOP_K", 8),
        )

    @property
    def has_openai_key(self) -> bool:
        return bool(os.environ.get("OPENAI_API_KEY"))

    @property
    def has_anthropic_key(self) -> bool:
        return bool(os.environ.get("ANTHROPIC_API_KEY"))

    @property
    def has_google_key(self) -> bool:
        return bool(os.environ.get("GOOGLE_API_KEY") or os.environ.get("GEMINI_API_KEY"))

    def redacted_summary(self) -> dict:
        return {
            "telegram_bot_token": (
                "set" if self.telegram_bot_token else "missing"
            ),
            "language": self.language,
            "timezone": self.timezone,
            "study_state_path": self.study_state_path.as_posix(),
            "app_state_path": self.app_state_path.as_posix(),
            "polling_timeout": self.polling_timeout,
            "send_images": self.send_images,
            "grading_provider": self.grading_provider,
            "qa_provider": self.qa_provider,
            "openai_chat_model": self.openai_chat_model,
            "anthropic_chat_model": self.anthropic_chat_model,
            "google_chat_model": self.google_chat_model,
            "openai_api_key": "set" if self.has_openai_key else "missing",
            "anthropic_api_key": "set" if self.has_anthropic_key else "missing",
            "google_api_key": "set" if self.has_google_key else "missing",
            "answer_top_k": self.answer_top_k,
            "qa_top_k": self.qa_top_k,
        }
