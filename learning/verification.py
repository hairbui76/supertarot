"""Build GPT verification prompts from retrieved tarot reference chunks."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .console import configure_utf8_stdio
from .embeddings import default_index_path, load_index, search_index
from .study import facet_label


def index_filters_for_facet(facet: str) -> tuple[str | None, str | None]:
    if "." not in facet:
        return None, facet

    orientation, field = facet.split(".", maxsplit=1)
    if field == "summary":
        return orientation, "summary"
    return orientation, field


def retrieve_reference_chunks(
    *,
    index: dict,
    card_name: str,
    facet: str,
    language: str,
    top_k: int = 6,
) -> list[dict]:
    orientation, index_facet = index_filters_for_facet(facet)
    query = f"{card_name} {facet_label(facet, language)}"

    results = search_index(
        index=index,
        query=query,
        top_k=top_k,
        card_name=card_name,
        orientation=orientation,
        facet=index_facet,
    )
    if results:
        return results

    return search_index(
        index=index,
        query=query,
        top_k=top_k,
        card_name=card_name,
    )


def build_verification_prompt(
    *,
    card_name: str,
    facet: str,
    user_answer: str,
    reference_chunks: list[dict],
    language: str = "vi",
) -> str:
    references = []
    for index, chunk in enumerate(reference_chunks, start=1):
        references.append(
            "\n".join(
                [
                    f"[{index}] {chunk['title']}",
                    f"score={chunk['score']:.4f}",
                    chunk["text"],
                ]
            )
        )
    reference_text = "\n\n".join(references)

    if language == "vi":
        return f"""Bạn là bot học tarot. Hãy chấm câu trả lời của người học dựa trên tài liệu tham chiếu.

Lá bài: {card_name}
Mục hỏi: {facet_label(facet, language)}

Câu trả lời của người học:
{user_answer}

Tài liệu tham chiếu đã retrieve bằng embedding:
{reference_text}

Quy tắc chấm:
- Không yêu cầu đúng từng chữ; chấp nhận diễn giải tương đương.
- Ưu tiên các ý nghĩa cốt lõi của đúng lá bài và đúng mục hỏi.
- Nếu người học nói đúng nhưng thiếu ý, ghi rõ ý còn thiếu.
- Nếu người học trộn sang lá khác, hướng khác, hoặc bịa ý trái nghĩa, ghi rõ.
- Trả về JSON thuần túy, không markdown.

Schema:
{{
  "score": 0,
  "passed": false,
  "correct_points": [],
  "missing_points": [],
  "incorrect_points": [],
  "feedback": "",
  "next_hint": ""
}}"""

    return f"""You are a tarot study bot. Grade the learner answer against the retrieved reference material.

Card: {card_name}
Asked facet: {facet_label(facet, language)}

Learner answer:
{user_answer}

Embedding-retrieved reference material:
{reference_text}

Grading rules:
- Do not require exact wording; accept equivalent phrasing.
- Prioritize core meanings for the correct card and asked facet.
- If the learner is correct but incomplete, name the missing ideas.
- If the learner mixes in another card, another orientation, or a contradictory idea, name it.
- Return plain JSON only, no markdown.

Schema:
{{
  "score": 0,
  "passed": false,
  "correct_points": [],
  "missing_points": [],
  "incorrect_points": [],
  "feedback": "",
  "next_hint": ""
}}"""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["prompt"])
    parser.add_argument("--lang", choices=["en", "vi"], default="vi")
    parser.add_argument("--index", type=Path, default=None)
    parser.add_argument("--card-name", required=True)
    parser.add_argument("--facet", required=True)
    parser.add_argument("--answer", required=True)
    parser.add_argument("--top-k", type=int, default=6)
    return parser.parse_args()


def main() -> None:
    configure_utf8_stdio()
    args = parse_args()
    if args.command == "prompt":
        index = load_index(args.index or default_index_path(args.lang))
        chunks = retrieve_reference_chunks(
            index=index,
            card_name=args.card_name,
            facet=args.facet,
            language=args.lang,
            top_k=args.top_k,
        )
        prompt = build_verification_prompt(
            card_name=args.card_name,
            facet=args.facet,
            user_answer=args.answer,
            reference_chunks=chunks,
            language=args.lang,
        )
        print(prompt)


if __name__ == "__main__":
    main()
