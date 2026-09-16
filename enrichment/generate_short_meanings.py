#!/usr/bin/env python3
"""Generate ``short_meaning`` and ``short_rev_meaning`` for all VI cards.

Reads data/output/tarot_meanings_vi.json, calls the chosen LLM for each
card that doesn't already have both fields, then saves back in-place.

Usage:
    python -m enrichment.generate_short_meanings                  # OpenAI
    python -m enrichment.generate_short_meanings --provider anthropic
    python -m enrichment.generate_short_meanings --model gpt-4.1-mini
    python -m enrichment.generate_short_meanings --force   # regenerate all
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from pathlib import Path

INPUT_FILES = {
    "vi": Path("data/output/tarot_meanings_vi.json"),
    "en": Path("data/output/tarot_meanings.json"),
}
UPRIGHT_WORDS = 100
REVERSED_WORDS = 100

_SYSTEM_PROMPTS = {
    "vi": (
        "Bạn là chuyên gia Tarot. Tóm tắt NGHĨA của lá bài "
        "(không mô tả hình ảnh, không lặp từ khóa). "
        f"Xuôi khoảng {UPRIGHT_WORDS} từ, Ngược khoảng {REVERSED_WORDS} từ. "
        "Viết tiếng Việt tự nhiên, ngắn gọn, trực tiếp. "
        'Trả về JSON: {"short_meaning": "...", "short_rev_meaning": ""}'
    ),
    "en": (
        "You are a Tarot expert. Summarize the MEANING of the card only "
        "(no artwork description, no repeating keywords). "
        f"Upright ~{UPRIGHT_WORDS} words, Reversed ~{REVERSED_WORDS} words. "
        "Write concise, natural English. "
        'Return JSON: {"short_meaning": "...", "short_rev_meaning": ""}'
    ),
}


def _build_user_prompt(card: dict) -> str:
    name = (card.get("name") or "").strip()
    upright_desc = (
        (card.get("upright") or {}).get("description") or ""
    ).strip()
    reversed_desc = (
        (card.get("reversed") or {}).get("description") or ""
    ).strip()
    kw_up = ", ".join(card.get("upright_keywords") or [])
    kw_rev = ", ".join(card.get("reversed_keywords") or [])
    return (
        f"Lá bài: {name}\n"
        f"Từ khóa xuôi: {kw_up}\n"
        f"Từ khóa ngược: {kw_rev}\n"
        f"Nghĩa xuôi: {upright_desc}\n"
        f"Nghĩa ngược: {reversed_desc}"
    )


def _parse_json_response(raw: str) -> tuple[str, str]:
    raw = raw.strip()
    raw = re.sub(r"^```(?:json)?\s*", "", raw)
    raw = re.sub(r"\s*```$", "", raw)
    result = json.loads(raw)
    short = (result.get("short_meaning") or "").strip()
    short_rev = (result.get("short_rev_meaning") or "").strip()
    if not short or not short_rev:
        raise ValueError("Empty response fields")
    return short, short_rev


def _gen_openai(
    client: object, card: dict, model: str, lang: str
) -> tuple[str, str]:
    system = _SYSTEM_PROMPTS[lang]
    response = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": system},
            {"role": "user", "content": _build_user_prompt(card)},
        ],
        temperature=0.2,
        response_format={"type": "json_object"},
    )
    return _parse_json_response(response.choices[0].message.content or "{}")


def _gen_anthropic(
    client: object, card: dict, model: str, lang: str
) -> tuple[str, str]:
    system = _SYSTEM_PROMPTS[lang]
    response = client.messages.create(
        model=model,
        max_tokens=1024,
        messages=[
            {
                "role": "user",
                "content": system + "\n\n" + _build_user_prompt(card),
            }
        ],
    )
    return _parse_json_response(response.content[0].text)


def generate_short_meaning(
    client: object,
    card: dict,
    model: str,
    provider: str,
    lang: str,
) -> tuple[str, str]:
    """Return (short_meaning, short_rev_meaning) via the chosen LLM."""
    name = (card.get("name") or "").strip()
    for attempt in range(3):
        try:
            if provider == "anthropic":
                return _gen_anthropic(client, card, model, lang)
            return _gen_openai(client, card, model, lang)
        except Exception as exc:
            print(f"  attempt {attempt + 1} failed: {exc}")
            if attempt < 2:
                time.sleep(3)
    raise RuntimeError(f"Could not generate short meaning for '{name}'")


def _process_file(
    input_file: Path,
    lang: str,
    client: object,
    model: str,
    provider: str,
    force: bool,
) -> None:
    if not input_file.exists():
        print(f"Error: {input_file} not found. Run the crawler first.")
        sys.exit(1)

    cards: list[dict] = json.loads(input_file.read_text(encoding="utf-8"))
    print(
        f"\n=== {lang.upper()} | {input_file} | "
        f"provider={provider} model={model} ==="
    )

    done = 0
    errors = 0

    for i, card in enumerate(cards, start=1):
        name = (card.get("name") or "").strip()
        has_both = bool(
            card.get("short_meaning") and card.get("short_rev_meaning")
        )

        if has_both and not force:
            print(f"[{i:02d}/{len(cards)}] skip  {name}")
            done += 1
            continue

        print(f"[{i:02d}/{len(cards)}] gen   {name} ...", end=" ", flush=True)
        try:
            short, short_rev = generate_short_meaning(
                client, card, model, provider, lang
            )
            card["short_meaning"] = short
            card["short_rev_meaning"] = short_rev
            done += 1
            print("OK")
        except RuntimeError as exc:
            print(f"ERROR: {exc}")
            errors += 1
            input_file.write_text(
                json.dumps(cards, ensure_ascii=False, indent=2),
                encoding="utf-8",
            )
            print("Progress saved. Re-run to continue from here.")
            sys.exit(1)

        input_file.write_text(
            json.dumps(cards, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        time.sleep(0.3)

    print(
        f"Finished: {done}/{len(cards)} cards OK, {errors} errors. "
        f"Saved to {input_file}"
    )


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(
        description="Pre-generate short tarot meanings."
    )
    parser.add_argument(
        "--provider",
        choices=["openai", "anthropic"],
        default="openai",
        help="LLM provider (default: openai)",
    )
    parser.add_argument(
        "--model",
        default=None,
        help="Model name override (defaults: openai=gpt-4.1-mini, "
        "anthropic=claude-haiku-4-5-20251001)",
    )
    parser.add_argument(
        "--lang",
        choices=["vi", "en", "all"],
        default="vi",
        help="Language to process: vi, en, or all (default: vi)",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Regenerate even for cards that already have short meanings.",
    )
    args = parser.parse_args(argv)

    if args.provider == "anthropic":
        api_key = os.environ.get("ANTHROPIC_API_KEY")
        if not api_key:
            # Try loading .env
            try:
                from dotenv import load_dotenv

                load_dotenv(Path(__file__).resolve().parents[1] / ".env")
                api_key = os.environ.get("ANTHROPIC_API_KEY")
            except ImportError:
                pass
        if not api_key:
            print("Error: ANTHROPIC_API_KEY not set.")
            sys.exit(1)
        import anthropic

        client: object = anthropic.Anthropic(api_key=api_key)
        default_model = "claude-haiku-4-5-20251001"
    else:
        api_key = os.environ.get("OPENAI_API_KEY")
        if not api_key:
            try:
                from dotenv import load_dotenv

                load_dotenv(Path(__file__).resolve().parents[1] / ".env")
                api_key = os.environ.get("OPENAI_API_KEY")
            except ImportError:
                pass
        if not api_key:
            print("Error: OPENAI_API_KEY not set.")
            sys.exit(1)
        from openai import OpenAI

        client = OpenAI(api_key=api_key)
        default_model = os.environ.get("OPENAI_CHAT_MODEL", "gpt-4.1-mini")

    model = args.model or default_model

    langs = ["vi", "en"] if args.lang == "all" else [args.lang]

    for lang in langs:
        input_file = INPUT_FILES[lang]
        _process_file(
            input_file, lang, client, model, args.provider, args.force
        )


if __name__ == "__main__":
    main()
