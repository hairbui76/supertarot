"""Telegram long-polling runtime for SuperTarot."""

from __future__ import annotations

import argparse
import importlib.util
import json
import logging
import re
import time
from contextlib import contextmanager
from dataclasses import asdict
from datetime import datetime
from pathlib import Path
from threading import Event, Thread
from zoneinfo import ZoneInfo

from learning.console import configure_utf8_stdio
from learning.embeddings import SOURCE_FILES, default_index_path
from learning.study import draw_card

from .config import AppConfig, PROJECT_ROOT
from .grading import format_grade, verify_answer
from .learn import (
    LEARN_BACK_TO_SUITS_EN,
    LEARN_BACK_TO_SUITS_VI,
    LEARN_CLOSE_EN,
    LEARN_CLOSE_VI,
    card_caption,
    card_image_path,
    cards_for_suit,
    find_card_by_name,
    format_card_details,
    format_card_orientation_details,
    format_card_summary,
    load_cards_for_language,
    suit_button_label,
    suit_key_from_button,
)
from .qa import answer_tarot_question, format_telegram_answer
from .state import TelegramBotState
from .telegram_client import TelegramClient

logger = logging.getLogger(__name__)

HELP_TEXT_VI = """SuperTarot bot

/random - rút một câu hỏi học bài ngẫu nhiên
/daily - rút một câu hỏi daily ngay bây giờ
/learn [ten la bai] - xem lá bài, rồi chọn Xuôi hoặc Ngược
/ask câu hỏi - hỏi đáp tarot bằng dữ liệu embedding
/menu - mở menu nút
/schedule HH:MM - gửi daily mỗi ngày, ví dụ /schedule 08:30
/unschedule - tắt daily tự động
/answer nội dung - trả lời câu hỏi đang mở
/lang vi hoặc /lang en - đổi ngôn ngữ dữ liệu
/status - xem trạng thái hiện tại
/help - xem hướng dẫn
"""

HELP_TEXT_EN = """SuperTarot bot

/random - draw a random study question
/daily - draw a daily question now
/learn [card name] - show a card, then choose Upright or Reversed
/ask question - ask tarot questions over the embedding data
/menu - show button menu
/schedule HH:MM - send a daily question, for example /schedule 08:30
/unschedule - disable daily automation
/answer text - answer the active question
/lang vi or /lang en - change data language
/status - show current state
/help - show help
"""

MENU_KEYBOARD_VI = [
    ["🎴 Random", "📅 Daily", "📚 Learn"],
    ["📊 Status", "🌐 Đổi ngôn ngữ"],
    ["⏰ Schedule", "❓ Help"],
]

MENU_KEYBOARD_EN = [
    ["🎴 Random", "📅 Daily", "📚 Learn"],
    ["📊 Status", "🌐 Language"],
    ["⏰ Schedule", "❓ Help"],
]

BUTTON_COMMANDS = {
    "🎴 Random": "/random",
    "📅 Daily": "/daily",
    "📚 Learn": "/learn",
    "📊 Status": "/status",
    "❓ Help": "/help",
    "🌐 Đổi ngôn ngữ": "/lang",
    "🌐 Language": "/lang",
    "⏰ Schedule": "/schedule",
}

BOT_COMMANDS = [
    {"command": "random", "description": "Draw a random study card"},
    {"command": "daily", "description": "Send a daily study card now"},
    {"command": "learn", "description": "Show a card and choose orientation"},
    {"command": "ask", "description": "Ask a tarot question"},
    {"command": "menu", "description": "Show button menu"},
    {"command": "schedule", "description": "Set daily schedule HH:MM"},
    {"command": "unschedule", "description": "Disable daily schedule"},
    {"command": "answer", "description": "Answer the current question"},
    {"command": "lang", "description": "Change language vi/en"},
    {"command": "status", "description": "Show current bot status"},
    {"command": "help", "description": "Show help"},
]

LEARN_FULL_PREFIX = "learn_full"
LEARN_ORIENTATION_PREFIX = "learn_orientation"


class SuperTarotTelegramBot:
    def __init__(self, config: AppConfig) -> None:
        self.config = config
        self.state = TelegramBotState(config.app_state_path)
        self.client = TelegramClient(config.telegram_bot_token)
        self._last_schedule_check = 0.0

    def run(self) -> None:
        if not self.config.telegram_bot_token:
            raise SystemExit("Set TELEGRAM_BOT_TOKEN before running the app.")

        logger.info("Starting SuperTarot Telegram bot")
        logger.info("Runtime config: %s", json.dumps(self.config.redacted_summary(), ensure_ascii=False))
        self.configure_bot_ui()
        offset: int | None = None
        while True:
            self.check_schedules()
            try:
                updates = self.client.get_updates(
                    offset=offset,
                    timeout=self.config.polling_timeout,
                )
            except Exception:
                logger.exception("Failed to poll Telegram updates")
                time.sleep(5)
                continue

            for update in updates:
                offset = int(update["update_id"]) + 1
                try:
                    self.handle_update(update)
                except Exception:
                    logger.exception("Failed to handle update")
            self.check_schedules()

    def handle_update(self, update: dict) -> None:
        callback_query = update.get("callback_query")
        if callback_query:
            self.handle_callback_query(callback_query)
            return

        message = update.get("message")
        if not message:
            return

        text = (message.get("text") or "").strip()
        if not text:
            return

        chat_id = message["chat"]["id"]
        telegram_user_id = (message.get("from") or {}).get("id")
        self.state.set_user(chat_id, telegram_user_id)

        button_command = BUTTON_COMMANDS.get(text)
        if button_command == "/lang":
            self.send_message(chat_id, self.lang_help_text(chat_id))
            return
        if button_command == "/schedule":
            self.send_message(chat_id, self.schedule_help_text(chat_id))
            return
        if button_command:
            command, args = parse_command(button_command)
            self.handle_command(chat_id, telegram_user_id, command, args)
            return

        if self.handle_learn_menu_input(chat_id, text):
            return

        if text.startswith("/"):
            command, args = parse_command(text)
            self.handle_command(chat_id, telegram_user_id, command, args)
            return

        self.handle_freeform_question(chat_id, text)

    def handle_callback_query(self, callback_query: dict) -> None:
        callback_id = callback_query.get("id")
        data = (callback_query.get("data") or "").strip()
        message = callback_query.get("message") or {}
        chat = message.get("chat") or {}
        chat_id = chat.get("id")

        if not callback_id or not chat_id:
            return

        if not (
            data.startswith(f"{LEARN_FULL_PREFIX}|")
            or data.startswith(f"{LEARN_ORIENTATION_PREFIX}|")
        ):
            self.client.answer_callback_query(callback_id)
            return

        parts = data.split("|", maxsplit=3)
        if parts[0] == LEARN_ORIENTATION_PREFIX:
            if len(parts) != 4:
                self.client.answer_callback_query(callback_id)
                return
            _, language, orientation, card_name = parts
            if orientation not in {"upright", "reversed"}:
                self.client.answer_callback_query(callback_id)
                return
        else:
            _, language, card_name = data.split("|", maxsplit=2)
            orientation = None

        cards = load_cards_for_language(language)
        card = find_card_by_name(cards, card_name)
        if card is None:
            error_text = (
                "Không tìm thấy lá bài"
                if language == "vi"
                else "Card not found"
            )
            self.client.answer_callback_query(
                callback_id,
                text=error_text,
            )
            return

        text = (
            format_card_orientation_details(card, language, orientation)
            if orientation
            else format_card_details(card, language)
        )
        self.send_message(
            chat_id,
            text,
            show_menu=False,
            parse_mode="HTML",
        )
        self.client.answer_callback_query(callback_id)

    def configure_bot_ui(self) -> None:
        try:
            self.client.set_my_commands(BOT_COMMANDS)
        except Exception:
            logger.exception("Failed to configure Telegram bot commands")

    def send_message(
        self,
        chat_id: int | str,
        text: str,
        *,
        reply_markup: dict[str, object] | None = None,
        show_menu: bool = False,
        remove_menu: bool = True,
        parse_mode: str | None = None,
    ) -> None:
        if reply_markup is not None:
            effective_reply_markup = reply_markup
        elif show_menu:
            effective_reply_markup = self.reply_markup(chat_id)
        elif remove_menu:
            effective_reply_markup = {"remove_keyboard": True}
        else:
            effective_reply_markup = None

        self.client.send_message(
            chat_id,
            text,
            reply_markup=effective_reply_markup,
            parse_mode=parse_mode,
        )

    def send_typing(self, chat_id: int | str, action: str = "typing") -> None:
        try:
            self.client.send_chat_action(chat_id, action)
        except Exception:
            logger.debug("Failed to send Telegram typing action", exc_info=True)

    @contextmanager
    def typing_indicator(
        self,
        chat_id: int | str,
        *,
        action: str = "typing",
        interval: float = 4.0,
    ):
        stop_event = Event()

        def keep_typing() -> None:
            while not stop_event.is_set():
                self.send_typing(chat_id, action)
                stop_event.wait(interval)

        thread = Thread(
            target=keep_typing,
            name=f"telegram-{action}-{chat_id}",
            daemon=True,
        )
        thread.start()
        try:
            yield
        finally:
            stop_event.set()
            thread.join(timeout=1.0)

    def send_photo(
        self,
        chat_id: int | str,
        photo_path: Path,
        caption: str,
        *,
        reply_markup: dict[str, object] | None = None,
        show_menu: bool = False,
        remove_menu: bool = True,
        parse_mode: str | None = None,
    ) -> None:
        if reply_markup is not None:
            effective_reply_markup = reply_markup
        elif show_menu:
            effective_reply_markup = self.reply_markup(chat_id)
        elif remove_menu:
            effective_reply_markup = {"remove_keyboard": True}
        else:
            effective_reply_markup = None

        self.client.send_photo(
            chat_id,
            photo_path,
            caption,
            reply_markup=effective_reply_markup,
            parse_mode=parse_mode,
        )

    def reply_markup(self, chat_id: int | str) -> dict[str, object]:
        language = (
            self.state.chat(chat_id).get("language")
            or self.config.language
        )
        learn_menu = self.state.chat(chat_id).get("learn_menu") or {}
        if learn_menu.get("step") == "suit":
            keyboard = self.learn_suit_keyboard(language)
        elif learn_menu.get("step") == "card":
            keyboard = self.learn_card_keyboard(chat_id, language)
        else:
            keyboard = (
                MENU_KEYBOARD_VI if language == "vi" else MENU_KEYBOARD_EN
            )
        return {
            "keyboard": keyboard,
            "resize_keyboard": True,
            "is_persistent": False,
            "one_time_keyboard": True,
        }

    def learn_suit_keyboard(self, language: str) -> list[list[str]]:
        rows = [
            [
                LEARN_CLOSE_VI if language == "vi" else LEARN_CLOSE_EN,
            ],
            [
                suit_button_label("major", language),
                suit_button_label("wands", language),
            ],
            [
                suit_button_label("cups", language),
                suit_button_label("swords", language),
            ],
            [
                suit_button_label("pentacles", language),
            ],
        ]
        return rows

    def learn_card_keyboard(
        self,
        chat_id: int | str,
        language: str,
    ) -> list[list[str]]:
        learn_menu = self.state.chat(chat_id).get("learn_menu") or {}
        suit = learn_menu.get("suit")
        cards = cards_for_suit(
            load_cards_for_language(language),
            suit,
            language,
        )
        rows: list[list[str]] = [
            [
                (
                    LEARN_BACK_TO_SUITS_VI
                    if language == "vi"
                    else LEARN_BACK_TO_SUITS_EN
                ),
                LEARN_CLOSE_VI if language == "vi" else LEARN_CLOSE_EN,
            ]
        ]
        current_row: list[str] = []
        for card in cards:
            current_row.append(card["name"])
            if len(current_row) == 2:
                rows.append(current_row)
                current_row = []
        if current_row:
            rows.append(current_row)
        return rows

    def handle_learn_menu_input(self, chat_id: int | str, text: str) -> bool:
        chat = self.state.chat(chat_id)
        learn_menu = chat.get("learn_menu") or {}
        step = learn_menu.get("step")
        if not step:
            return False

        language = chat.get("language") or self.config.language
        back_label = (
            LEARN_BACK_TO_SUITS_VI
            if language == "vi"
            else LEARN_BACK_TO_SUITS_EN
        )
        close_label = LEARN_CLOSE_VI if language == "vi" else LEARN_CLOSE_EN

        if text == close_label:
            self.state.clear_learn_menu(chat_id)
            self.send_message(chat_id, self.menu_text(chat_id), show_menu=True)
            return True

        if step == "suit":
            suit = suit_key_from_button(text, language)
            if suit is None:
                return False
            self.state.set_learn_menu(chat_id, step="card", suit=suit)
            self.send_message(
                chat_id,
                self.learn_card_prompt(chat_id),
                show_menu=True,
            )
            return True

        if step == "card":
            if text == back_label:
                self.state.set_learn_menu(chat_id, step="suit", suit=None)
                self.send_message(
                    chat_id,
                    self.learn_suit_prompt(chat_id),
                    show_menu=True,
                )
                return True

            cards = load_cards_for_language(language)
            card = find_card_by_name(cards, text)
            if card is None:
                return False
            self.send_learn_card(chat_id, card, language)
            return True

        return False

    def handle_command(
        self,
        chat_id: int | str,
        telegram_user_id: int | str | None,
        command: str,
        args: str,
    ) -> None:
        if command in {"start", "help"}:
            self.state.clear_learn_menu(chat_id)
            self.send_message(chat_id, self.help_text(chat_id), show_menu=True)
            return

        if command == "menu":
            self.state.clear_learn_menu(chat_id)
            self.send_message(chat_id, self.menu_text(chat_id), show_menu=True)
            return

        if command == "random":
            self.send_draw(chat_id, telegram_user_id, mode="random")
            return

        if command == "daily":
            self.send_draw(chat_id, telegram_user_id, mode="daily")
            return

        if command == "learn":
            self.handle_learn(chat_id, args)
            return

        if command == "ask":
            if not args.strip():
                self.send_message(chat_id, self.ask_help_text(chat_id))
                return
            self.handle_freeform_question(chat_id, args.strip())
            return

        if command == "schedule":
            self.handle_schedule(chat_id, telegram_user_id, args)
            return

        if command == "unschedule":
            self.state.clear_schedule(chat_id)
            self.send_message(chat_id, "Đã tắt daily tự động.")
            return

        if command == "answer":
            if not args.strip():
                self.send_message(
                    chat_id,
                    "Hãy gửi: /answer câu trả lời của bạn",
                )
                return
            self.handle_answer(chat_id, args.strip())
            return

        if command == "lang":
            if not args.strip():
                self.send_message(chat_id, self.lang_help_text(chat_id))
                return
            self.handle_lang(chat_id, args.strip().lower())
            return

        if command == "status":
            self.send_message(chat_id, self.format_status(chat_id))
            return

        self.send_message(chat_id, self.help_text(chat_id))

    def handle_freeform_question(self, chat_id: int | str, question: str) -> None:
        language = (
            self.state.chat(chat_id).get("language")
            or self.config.language
        )
        try:
            with self.typing_indicator(chat_id):
                result = answer_tarot_question(
                    config=self.config,
                    query=question,
                    language=language,
                )
        except FileNotFoundError:
            self.send_message(
                chat_id,
                "Chưa có embedding index. Chạy: "
                "python -m learning.embeddings build "
                "--provider hash --lang all",
            )
            return
        except Exception as exc:
            logger.exception("Failed to answer freeform tarot question")
            self.send_message(
                chat_id,
                f"Không trả lời được câu hỏi lúc này: {exc}",
            )
            return

        self.send_message(
            chat_id,
            format_telegram_answer(result.answer, language),
            parse_mode="HTML",
        )

    def handle_learn(self, chat_id: int | str, args: str) -> None:
        language = (
            self.state.chat(chat_id).get("language")
            or self.config.language
        )
        cards = load_cards_for_language(language)

        if not args.strip():
            self.state.set_learn_menu(chat_id, step="suit", suit=None)
            self.send_message(
                chat_id,
                self.learn_suit_prompt(chat_id),
                show_menu=True,
            )
            return

        card = find_card_by_name(cards, args)
        if card is None:
            self.send_message(
                chat_id,
                self.learn_not_found_text(chat_id, args),
            )
            return

        self.state.clear_learn_menu(chat_id)
        self.send_learn_card(chat_id, card, language)

    def send_learn_card(
        self,
        chat_id: int | str,
        card: dict,
        language: str,
    ) -> None:
        image_path = card_image_path(card)
        if image_path is not None:
            resolved = resolve_project_path(image_path.as_posix())
            if self.config.send_images and resolved and resolved.exists():
                try:
                    self.send_photo(
                        chat_id,
                        resolved,
                        card_caption(card, language),
                        parse_mode="HTML",
                    )
                except Exception:
                    logger.exception("Failed to send learn card image")

        self.send_message(
            chat_id,
            format_card_summary(card, language),
            reply_markup={
                "inline_keyboard": [
                    [
                        {
                            "text": (
                                "⬆️ Xuôi"
                                if language == "vi"
                                else "⬆️ Upright"
                            ),
                            "callback_data": f"{LEARN_ORIENTATION_PREFIX}|"
                            f"{language}|upright|{card['name']}",
                        },
                        {
                            "text": (
                                "⬇️ Ngược"
                                if language == "vi"
                                else "⬇️ Reversed"
                            ),
                            "callback_data": f"{LEARN_ORIENTATION_PREFIX}|"
                            f"{language}|reversed|{card['name']}",
                        },
                    ]
                ]
            },
            remove_menu=False,
            parse_mode="HTML",
        )

    def learn_suit_prompt(self, chat_id: int | str) -> str:
        language = (
            self.state.chat(chat_id).get("language")
            or self.config.language
        )
        if language == "vi":
            return (
                "Chọn bộ ẩn mà bạn muốn học. "
                "Sau đó tôi sẽ hiện danh sách lá bài để bạn chọn."
            )
        return (
            "Choose the suit or arcana you want to study. "
            "Then I will show the card list."
        )

    def learn_card_prompt(self, chat_id: int | str) -> str:
        language = (
            self.state.chat(chat_id).get("language")
            or self.config.language
        )
        if language == "vi":
            return "Chọn lá bài bạn muốn xem toàn bộ nội dung."
        return "Choose the card you want to inspect in full."

    def learn_not_found_text(self, chat_id: int | str, query: str) -> str:
        language = (
            self.state.chat(chat_id).get("language")
            or self.config.language
        )
        if language == "vi":
            return (
                f"Không tìm thấy lá bài: {query}\n"
                "Dùng /learn rồi chọn bộ, hoặc gõ đúng tên lá bài như "
                "/learn The Fool"
            )
        return (
            f"Card not found: {query}\n"
            "Use /learn and choose a suit, or type an exact card name "
            "like /learn The Fool"
        )

    def send_draw(
        self,
        chat_id: int | str,
        telegram_user_id: int | str | None,
        *,
        mode: str,
    ) -> None:
        language = (
            self.state.chat(chat_id).get("language")
            or self.config.language
        )
        draw = draw_card(
            user_id=study_user_id(telegram_user_id or chat_id),
            language=language,
            mode=mode,
            state_path=self.config.study_state_path,
        )
        self.state.set_active_draw(chat_id, draw)

        text = format_draw(draw)
        image_path = resolve_project_path(draw.card_image)
        if self.config.send_images and image_path and image_path.exists():
            try:
                self.send_photo(chat_id, image_path, text)
                return
            except Exception:
                logger.exception(
                    "Failed to send Telegram photo; falling back to text"
                )

        self.send_message(chat_id, text)

    def handle_answer(self, chat_id: int | str, answer: str) -> None:
        chat = self.state.chat(chat_id)
        active_draw = chat.get("active_draw")
        if not active_draw:
            self.send_message(
                chat_id,
                "Chưa có câu hỏi đang mở. Dùng /random trước.",
            )
            return

        language = (
            active_draw.get("language")
            or chat.get("language")
            or self.config.language
        )
        try:
            with self.typing_indicator(chat_id):
                result = verify_answer(
                    config=self.config,
                    card_name=active_draw["card_name"],
                    facet=active_draw["facet"],
                    language=language,
                    answer=answer,
                )
        except FileNotFoundError:
            self.send_message(
                chat_id,
                "Chưa có embedding index. Chạy: "
                "python -m learning.embeddings build "
                "--provider hash --lang all",
            )
            return
        except Exception as exc:
            logger.exception("Failed to verify answer")
            self.send_message(
                chat_id,
                f"Không chấm được câu trả lời lúc này: {exc}",
            )
            return

        self.send_message(chat_id, format_grade(result, language))
        self.state.clear_active_draw(chat_id)

    def handle_schedule(
        self,
        chat_id: int | str,
        telegram_user_id: int | str | None,
        args: str,
    ) -> None:
        match = re.search(r"\b([01]\d|2[0-3]):([0-5]\d)\b", args)
        if not match:
            self.send_message(chat_id, self.schedule_help_text(chat_id))
            return

        language = (
            self.state.chat(chat_id).get("language")
            or self.config.language
        )
        hhmm = f"{match.group(1)}:{match.group(2)}"
        self.state.set_schedule(
            chat_id,
            telegram_user_id=telegram_user_id,
            language=language,
            hhmm=hhmm,
            timezone=self.config.timezone,
        )
        self.send_message(
            chat_id,
            f"Đã bật daily lúc {hhmm} mỗi ngày ({self.config.timezone}).",
        )

    def handle_lang(self, chat_id: int | str, language: str) -> None:
        if language not in {"en", "vi"}:
            self.send_message(chat_id, self.lang_help_text(chat_id))
            return
        self.state.set_language(chat_id, language)
        self.send_message(chat_id, f"Đã đổi ngôn ngữ sang {language}.")

    def check_schedules(self) -> None:
        now_monotonic = time.monotonic()
        if now_monotonic - self._last_schedule_check < 10:
            return
        self._last_schedule_check = now_monotonic

        for chat_id, chat in self.state.scheduled_chats():
            timezone = ZoneInfo(chat.get("timezone") or self.config.timezone)
            now = datetime.now(timezone)
            hhmm = now.strftime("%H:%M")
            today = now.date().isoformat()
            if chat.get("schedule") != hhmm:
                continue
            if chat.get("last_daily_date") == today:
                continue

            try:
                self.send_draw(
                    chat_id,
                    chat.get("telegram_user_id") or chat_id,
                    mode="daily",
                )
                self.state.mark_daily_sent(chat_id, today)
            except Exception:
                logger.exception("Failed to send scheduled daily draw")

    def help_text(self, chat_id: int | str) -> str:
        language = (
            self.state.chat(chat_id).get("language")
            or self.config.language
        )
        return HELP_TEXT_VI if language == "vi" else HELP_TEXT_EN

    def menu_text(self, chat_id: int | str) -> str:
        language = (
            self.state.chat(chat_id).get("language")
            or self.config.language
        )
        if language == "vi":
            return (
                "Menu đã được mở. Bạn cũng có thể nhắn trực tiếp câu hỏi "
                "tarot bất kỳ."
            )
        return "Menu is open. You can also send any tarot question directly."

    def lang_help_text(self, chat_id: int | str) -> str:
        language = (
            self.state.chat(chat_id).get("language")
            or self.config.language
        )
        if language == "vi":
            return "Dùng: /lang vi hoặc /lang en"
        return "Use: /lang vi or /lang en"

    def ask_help_text(self, chat_id: int | str) -> str:
        language = (
            self.state.chat(chat_id).get("language")
            or self.config.language
        )
        if language == "vi":
            return (
                "Bạn có thể nhắn trực tiếp một câu hỏi tarot, ví dụ: "
                "'Ace of Cups trong tình yêu mới nói gì?' hoặc "
                "'The Star liên hệ với cung Bảo Bình như thế nào?'. "
                "Nếu đang học bài và muốn chấm câu trả lời, dùng /answer ..."
            )
        return (
            "You can send a tarot question directly, for example: "
            "'What does Ace of Cups mean for new love?' or "
            "'How does The Star relate to Aquarius?'. "
            "If you want to grade an active study answer, use /answer ..."
        )

    def schedule_help_text(self, chat_id: int | str) -> str:
        language = (
            self.state.chat(chat_id).get("language")
            or self.config.language
        )
        if language == "vi":
            return "Dùng dạng: /schedule 08:30"
        return "Use: /schedule 08:30"

    def format_status(self, chat_id: int | str) -> str:
        chat = self.state.chat(chat_id)
        active = chat.get("active_draw") or {}
        lines = [
            f"Ngôn ngữ: {chat.get('language') or self.config.language}",
            f"Daily: {chat.get('schedule') or 'off'}",
            f"Timezone: {chat.get('timezone') or self.config.timezone}",
        ]
        if active:
            lines.extend(
                [
                    "",
                    f"Câu hỏi đang mở: {active.get('card_name')}",
                    f"Facet: {active.get('facet')}",
                ]
            )
        return "\n".join(lines)


def parse_command(text: str) -> tuple[str, str]:
    first, _, args = text.partition(" ")
    command = first[1:].split("@", maxsplit=1)[0].lower()
    return command, args


def study_user_id(telegram_user_id: int | str) -> str:
    return f"telegram:{telegram_user_id}"


def resolve_project_path(path_text: str | None) -> Path | None:
    if not path_text:
        return None
    path = Path(path_text)
    if path.is_absolute():
        return path
    return PROJECT_ROOT / path


def format_draw(draw: object) -> str:
    data = asdict(draw)
    hint_label = "Gợi ý" if data.get("language") == "vi" else "Hint"
    return "\n".join(
        [
            f"Mục hỏi: {data['facet_label']}",
            "",
            data["question"],
            f"{hint_label}: {data['hint']}",
            "",
            (
                f"Cycle: {data['cycle']} | Còn lại: "
                f"{data['remaining_in_cycle']}/78"
            ),
            "Chấm bài bằng: /answer nội dung của bạn",
            "Nhắn thường sẽ được hiểu là câu hỏi tarot Q&A.",
        ]
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="Validate local files/config without contacting Telegram.",
    )
    parser.add_argument("--log-level", default="INFO")
    return parser.parse_args()


def check_runtime(config: AppConfig) -> dict:
    openai_available = importlib.util.find_spec("openai") is not None
    anthropic_available = importlib.util.find_spec("anthropic") is not None
    checks = {
        "config": config.redacted_summary(),
        "data_files": {
            lang: path.exists() for lang, path in SOURCE_FILES.items()
        },
        "embedding_indexes": {
            lang: default_index_path(lang).exists() for lang in SOURCE_FILES
        },
        "python_packages": {
            "openai": openai_available,
            "anthropic": anthropic_available,
            "google": True,
        },
    }
    missing = [
        label
        for group in ("data_files", "embedding_indexes")
        for label, exists in checks[group].items()
        if not exists
    ]
    selected_openai = config.qa_provider == "openai" or config.grading_provider == "openai"
    selected_anthropic = (
        config.qa_provider == "anthropic"
        or config.grading_provider == "anthropic"
    )
    selected_google = config.qa_provider == "google" or config.grading_provider == "google"

    if selected_openai and not config.has_openai_key:
        missing.append("OPENAI_API_KEY")
    if selected_anthropic and not config.has_anthropic_key:
        missing.append("ANTHROPIC_API_KEY")
    if selected_google and not config.has_google_key:
        missing.append("GOOGLE_API_KEY or GEMINI_API_KEY")

    if (
        selected_openai
        or (config.qa_provider == "auto" and config.has_openai_key)
        or (config.grading_provider == "auto" and config.has_openai_key)
    ) and not openai_available:
        missing.append("python package openai")
    if (
        selected_anthropic
        or (config.qa_provider == "auto" and config.has_anthropic_key)
        or (config.grading_provider == "auto" and config.has_anthropic_key)
    ) and not anthropic_available:
        missing.append("python package anthropic")
    checks["ok"] = not missing
    checks["missing"] = missing
    return checks


def main() -> None:
    configure_utf8_stdio()
    args = parse_args()
    logging.basicConfig(level=getattr(logging, args.log_level.upper()))

    config = AppConfig.from_env()
    if args.check:
        print(json.dumps(check_runtime(config), ensure_ascii=False, indent=2))
        return

    SuperTarotTelegramBot(config).run()


if __name__ == "__main__":
    main()
