"""Freeform tarot question answering over the embedding index."""

from __future__ import annotations

from dataclasses import dataclass
from html import escape
import re
from typing import Any

from learning.embeddings import default_index_path, load_index, search_index

from .config import AppConfig
from .llm import call_llm, model_for_provider, resolve_llm_provider


@dataclass(frozen=True)
class QAResult:
    mode: str
    query: str
    answer: str
    reference_chunks: list[dict[str, Any]]
    error: str | None = None


def answer_tarot_question(
    *,
    config: AppConfig,
    query: str,
    language: str,
) -> QAResult:
    index = load_index(default_index_path(language))
    chunks = search_index(
        index=index,
        query=query,
        top_k=config.qa_top_k,
    )

    if config.qa_provider == "context":
        return QAResult(
            mode="context",
            query=query,
            answer=format_context_answer(query, chunks, language),
            reference_chunks=chunks,
        )

    if config.qa_provider == "auto" and not any(
        (
            config.has_openai_key,
            config.has_anthropic_key,
            config.has_google_key,
        )
    ):
        return QAResult(
            mode="context",
            query=query,
            answer=format_context_answer(
                query,
                chunks,
                language,
                error=(
                    "No Q&A LLM provider is configured. Set OPENAI_API_KEY, "
                    "ANTHROPIC_API_KEY, GOOGLE_API_KEY, or GEMINI_API_KEY."
                ),
            ),
            reference_chunks=chunks,
            error=(
                "No Q&A LLM provider is configured. Set OPENAI_API_KEY, "
                "ANTHROPIC_API_KEY, GOOGLE_API_KEY, or GEMINI_API_KEY."
            ),
        )

    try:
        provider = resolve_llm_provider(config, config.qa_provider)
        answer = call_qa_model(
            query=query,
            chunks=chunks,
            language=language,
            provider=provider,
            model=model_for_provider(config, provider),
        )
        return QAResult(
            mode=provider,
            query=query,
            answer=clean_answer_text(answer, language),
            reference_chunks=chunks,
        )
    except Exception as exc:
        return QAResult(
            mode="context",
            query=query,
            answer=format_context_answer(query, chunks, language, error=str(exc)),
            reference_chunks=chunks,
            error=str(exc),
        )


def call_qa_model(
    *,
    query: str,
    chunks: list[dict[str, Any]],
    language: str,
    provider: str,
    model: str,
) -> str:
    return call_llm(
        provider=provider,
        model=model,
        system_prompt=system_prompt(language),
        user_prompt=build_user_prompt(query, chunks, language),
        temperature=0.2,
        json_mode=False,
    )


def system_prompt(language: str) -> str:
    if language == "vi":
        return (
            "Bạn là SuperTarot, trợ lý học tarot. "
            "Trả lời bằng tiếng Việt tự nhiên, ưu tiên câu hỏi tarot. "
            "Xâu chuỗi các mảnh dữ liệu được retrieve từ embedding index: "
            "nghĩa xuôi/ngược, tình yêu, sự nghiệp, tài chính, cảm xúc, "
            "hành động, biểu tượng, nguyên tố, chiêm tinh và yes/no nếu liên quan. "
            "Không bịa chi tiết trái với dữ liệu. Không thêm mục Lưu ý, "
            "không thêm mục Tham chiếu/Nguồn ở cuối, và không nhắc tới chunk, "
            "embedding hay tài liệu tham chiếu. Dùng <b>...</b> khi cần in đậm "
            "và dùng ký tự • cho danh sách; không dùng Markdown ** hoặc *."
        )
    return (
        "You are SuperTarot, a tarot study assistant. "
        "Answer in natural English and prioritize tarot questions. "
        "Synthesize retrieved tarot data chunks from the embedding index: "
        "upright/reversed meanings, love, career, finances, feelings, actions, "
        "symbols, elements, astrology, and yes/no where relevant. "
        "Do not invent details that contradict the data. Do not add Note, "
        "References, or Sources sections, and do not mention chunks, embeddings, "
        "or reference material. Use <b>...</b> for emphasis and • for bullets; "
        "do not use Markdown ** or *."
    )


def build_user_prompt(
    query: str,
    chunks: list[dict[str, Any]],
    language: str,
) -> str:
    references = "\n\n".join(
        format_reference_chunk(index, chunk)
        for index, chunk in enumerate(chunks, start=1)
    )
    if language == "vi":
        return (
            f"Câu hỏi người dùng:\n{query}\n\n"
            f"Dữ liệu tarot đã retrieve:\n{references}\n\n"
            "Hãy trả lời 4-8 câu hoặc vài gạch đầu dòng ngắn. "
            "Nếu có nhiều lá bài liên quan, hãy so sánh và kết nối chúng. "
            "Không thêm dòng Lưu ý, Tham chiếu hoặc Nguồn."
        )
    return (
        f"User question:\n{query}\n\n"
        f"Retrieved tarot data:\n{references}\n\n"
        "Answer in 4-8 sentences or a few short bullets. "
        "If several cards are relevant, compare and connect them. "
        "Do not add Note, References, or Sources lines."
    )


def format_reference_chunk(index: int, chunk: dict[str, Any]) -> str:
    orientation = chunk.get("orientation") or "card"
    return "\n".join(
        [
            f"[{index}] {chunk.get('card_name')} | {orientation}.{chunk.get('facet')}",
            f"score={float(chunk.get('score', 0.0)):.4f}",
            str(chunk.get("text") or ""),
        ]
    )


def format_context_answer(
    query: str,
    chunks: list[dict[str, Any]],
    language: str,
    error: str | None = None,
) -> str:
    if not chunks:
        if language == "vi":
            return (
                "Mình chưa tìm thấy mảnh tham chiếu phù hợp trong dữ liệu tarot. "
                "Bạn có thể hỏi rõ tên lá bài, lĩnh vực như tình yêu/sự nghiệp, "
                "hoặc yếu tố chiêm tinh/nguyên tố muốn liên hệ."
            )
        return (
            "I could not find matching tarot references. Ask with a card name, "
            "a facet such as love/career, or an astrology/element angle."
        )

    if language == "vi":
        if error:
            lines = [
                "Mình đã đọc được câu hỏi và tìm được dữ liệu liên quan, nhưng phần tổng hợp bằng LLM đang lỗi nên tạm trả về nội dung gần nhất.",
                f"Lỗi LLM/config: {compact_text(error, 500)}",
                "",
                "Gợi ý đọc nhanh:",
            ]
        else:
            lines = [
                "Mình tìm được các mảnh dữ liệu liên quan. "
                "Để có phần diễn giải tổng hợp mượt hơn, bật API key "
                "và SUPERTAROT_QA_PROVIDER=openai/anthropic/google.",
                "",
                "Gợi ý đọc nhanh:",
            ]
    else:
        if error:
            lines = [
                "I found related tarot data, but LLM synthesis failed, so I am returning the closest content instead.",
                f"LLM/config error: {compact_text(error, 500)}",
                "",
                "Quick notes:",
            ]
        else:
            lines = [
                "I found related tarot data. Enable an API key and "
                "SUPERTAROT_QA_PROVIDER=openai/anthropic/google for a synthesized answer.",
                "",
                "Quick notes:",
            ]

    for chunk in chunks[:4]:
        title = f"{chunk.get('card_name')} - {chunk.get('facet')}"
        text = compact_text(str(chunk.get("text") or ""), 320)
        lines.append(f"- {title}: {text}")

    return "\n".join(lines)


REFERENCE_FOOTER_RE = re.compile(
    r"(?ims)\n+\s*(?:\*\*)?\s*(?:Tham chiếu|References|Nguồn|Sources)"
    r"\s*(?:\*\*)?\s*:\s*.*\Z"
)
NOTE_BLOCK_RE = re.compile(
    r"(?ims)\n?\s*[*_]*\(\s*(?:Lưu ý|Note)\s*:.*?\)\s*[*_]*"
)
NOTE_LINE_RE = re.compile(r"(?im)^\s*[*_()]*\s*(?:Lưu ý|Note)\s*:.*$")
REFERENCE_MENTION_RE = re.compile(
    r"(?i)\b(tài liệu tham chiếu|reference material|embedding reference)\b"
)
HTML_B_OPEN = "%%SUPERTAROT_B_OPEN%%"
HTML_B_CLOSE = "%%SUPERTAROT_B_CLOSE%%"


def clean_answer_text(answer: str, language: str) -> str:
    del language
    text = REFERENCE_FOOTER_RE.sub("", answer or "")
    text = NOTE_BLOCK_RE.sub("", text)
    text = NOTE_LINE_RE.sub("", text)
    lines = [
        line.rstrip()
        for line in text.splitlines()
        if not REFERENCE_MENTION_RE.search(line)
    ]
    return "\n".join(lines).strip()


def format_telegram_answer(answer: str, language: str = "vi") -> str:
    fallback = (
        "Mình chưa có câu trả lời phù hợp."
        if language == "vi"
        else "I do not have a suitable answer yet."
    )
    text = clean_answer_text(answer, language)
    if not text:
        text = fallback

    text = re.sub(r"(?m)^\s*[-*]\s+", "• ", text)
    text = re.sub(r"(?m)^\s{0,3}#{1,6}\s+", "", text)
    text = re.sub(r"\*\*(.+?)\*\*", rf"{HTML_B_OPEN}\1{HTML_B_CLOSE}", text, flags=re.S)
    text = re.sub(r"(?is)<\s*(?:b|strong)\s*>", HTML_B_OPEN, text)
    text = re.sub(r"(?is)<\s*/\s*(?:b|strong)\s*>", HTML_B_CLOSE, text)
    text = text.replace("*", "")

    formatted = escape(text, quote=False)
    return (
        formatted.replace(HTML_B_OPEN, "<b>")
        .replace(HTML_B_CLOSE, "</b>")
        .strip()
    )


def compact_text(value: str, limit: int) -> str:
    value = " ".join(value.split())
    if len(value) <= limit:
        return value
    return value[: limit - 1].rstrip() + "…"
