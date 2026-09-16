"""Answer verification and GPT grading for the Telegram app."""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from typing import Any

from learning.embeddings import default_index_path, load_index
from learning.verification import build_verification_prompt, retrieve_reference_chunks

from .config import AppConfig
from .llm import call_llm, model_for_provider, resolve_llm_provider


@dataclass(frozen=True)
class GradeResult:
    mode: str
    card_name: str
    facet: str
    prompt: str
    reference_count: int
    grade: dict[str, Any] | None = None
    error: str | None = None


def verify_answer(
    *,
    config: AppConfig,
    card_name: str,
    facet: str,
    language: str,
    answer: str,
) -> GradeResult:
    index = load_index(default_index_path(language))
    chunks = retrieve_reference_chunks(
        index=index,
        card_name=card_name,
        facet=facet,
        language=language,
        top_k=config.answer_top_k,
    )
    prompt = build_verification_prompt(
        card_name=card_name,
        facet=facet,
        user_answer=answer,
        reference_chunks=chunks,
        language=language,
    )

    if config.grading_provider == "prompt":
        return GradeResult(
            mode="prompt",
            card_name=card_name,
            facet=facet,
            prompt=prompt,
            reference_count=len(chunks),
        )

    if config.grading_provider == "auto" and not any(
        (
            config.has_openai_key,
            config.has_anthropic_key,
            config.has_google_key,
        )
    ):
        return GradeResult(
            mode="prompt",
            card_name=card_name,
            facet=facet,
            prompt=prompt,
            reference_count=len(chunks),
            error=(
                "No grading LLM provider is configured. Set OPENAI_API_KEY, "
                "ANTHROPIC_API_KEY, GOOGLE_API_KEY, or GEMINI_API_KEY."
            ),
        )

    try:
        provider = resolve_llm_provider(config, config.grading_provider)
        grade = call_grader(
            prompt=prompt,
            provider=provider,
            model=model_for_provider(config, provider),
        )
    except Exception as exc:
        return GradeResult(
            mode=config.grading_provider,
            card_name=card_name,
            facet=facet,
            prompt=prompt,
            reference_count=len(chunks),
            error=str(exc),
        )

    return GradeResult(
        mode=provider,
        card_name=card_name,
        facet=facet,
        prompt=prompt,
        reference_count=len(chunks),
        grade=grade,
    )


def call_grader(prompt: str, provider: str, model: str) -> dict[str, Any]:
    text = call_llm(
        provider=provider,
        model=model,
        system_prompt="Return valid JSON only. Do not wrap it in markdown.",
        user_prompt=prompt,
        temperature=0,
        json_mode=True,
    )
    return parse_json_object(text)


def parse_json_object(text: str) -> dict[str, Any]:
    text = text.strip()
    text = re.sub(r"^```(?:json)?\s*", "", text)
    text = re.sub(r"\s*```$", "", text)
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        start = text.find("{")
        end = text.rfind("}")
        if start >= 0 and end > start:
            return json.loads(text[start : end + 1])
        raise


def format_grade(result: GradeResult, language: str) -> str:
    if result.grade:
        score = result.grade.get("score", "?")
        passed = result.grade.get("passed", False)
        lines = [
            f"Điểm: {score}/100" if language == "vi" else f"Score: {score}/100",
            "Kết quả: đạt" if passed and language == "vi" else "",
            "Kết quả: chưa đạt" if not passed and language == "vi" else "",
            "Result: passed" if passed and language == "en" else "",
            "Result: not passed" if not passed and language == "en" else "",
        ]
        for key, label_vi, label_en in (
            ("correct_points", "Ý đúng", "Correct points"),
            ("missing_points", "Ý còn thiếu", "Missing points"),
            ("incorrect_points", "Ý sai/lệch", "Incorrect points"),
        ):
            values = result.grade.get(key) or []
            if values:
                label = label_vi if language == "vi" else label_en
                lines.append(f"{label}:")
                lines.extend(f"- {item}" for item in values)

        feedback = result.grade.get("feedback")
        if feedback:
            lines.append(("Nhận xét: " if language == "vi" else "Feedback: ") + feedback)

        hint = result.grade.get("next_hint")
        if hint:
            lines.append(("Gợi ý tiếp: " if language == "vi" else "Next hint: ") + hint)

        return "\n".join(line for line in lines if line)

    if language == "vi":
        message = (
            "Đã retrieve tài liệu tham chiếu, nhưng bot chưa chấm bằng GPT. "
            "Cấu hình API key và SUPERTAROT_GRADING_PROVIDER=auto/openai/anthropic/google "
            "để bật chấm tự động."
        )
    else:
        message = (
            "Reference chunks were retrieved, but GPT grading is not enabled. "
            "Set an API key and SUPERTAROT_GRADING_PROVIDER=auto/openai/anthropic/google to enable it."
        )

    if result.error:
        message += f"\n\nRuntime note: {result.error}"
    message += f"\nReference chunks: {result.reference_count}"
    return message
