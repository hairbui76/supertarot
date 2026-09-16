"""LLM provider adapters for OpenAI, Anthropic, and Google Gemini."""

from __future__ import annotations

import os
from typing import Literal

import requests

from .config import AppConfig

LLMProvider = Literal["openai", "anthropic", "google"]

GOOGLE_GENERATE_URL = (
    "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
)


def resolve_llm_provider(config: AppConfig, requested: str) -> LLMProvider:
    if requested in {"openai", "anthropic", "google"}:
        ensure_provider_ready(config, requested)
        return requested

    if requested != "auto":
        raise ValueError(f"Unsupported LLM provider: {requested}")

    for provider in ("openai", "anthropic", "google"):
        if provider_ready(config, provider):
            return provider

    raise RuntimeError(
        "No LLM provider is configured. Set one of OPENAI_API_KEY, "
        "ANTHROPIC_API_KEY, GOOGLE_API_KEY, or GEMINI_API_KEY."
    )


def provider_ready(config: AppConfig, provider: str) -> bool:
    if provider == "openai":
        return config.has_openai_key
    if provider == "anthropic":
        return config.has_anthropic_key
    if provider == "google":
        return config.has_google_key
    return False


def ensure_provider_ready(config: AppConfig, provider: str) -> None:
    if provider == "openai" and not config.has_openai_key:
        raise RuntimeError("OPENAI_API_KEY is not configured.")
    if provider == "anthropic" and not config.has_anthropic_key:
        raise RuntimeError("ANTHROPIC_API_KEY is not configured.")
    if provider == "google" and not config.has_google_key:
        raise RuntimeError("GOOGLE_API_KEY or GEMINI_API_KEY is not configured.")


def model_for_provider(config: AppConfig, provider: str) -> str:
    if provider == "openai":
        return config.openai_chat_model
    if provider == "anthropic":
        return config.anthropic_chat_model
    if provider == "google":
        return config.google_chat_model
    raise ValueError(f"Unsupported LLM provider: {provider}")


def call_llm(
    *,
    provider: str,
    model: str,
    system_prompt: str,
    user_prompt: str,
    temperature: float,
    json_mode: bool = False,
) -> str:
    if provider == "openai":
        return call_openai(
            model=model,
            system_prompt=system_prompt,
            user_prompt=user_prompt,
            temperature=temperature,
            json_mode=json_mode,
        )
    if provider == "anthropic":
        return call_anthropic(
            model=model,
            system_prompt=system_prompt,
            user_prompt=user_prompt,
            temperature=temperature,
        )
    if provider == "google":
        return call_google(
            model=model,
            system_prompt=system_prompt,
            user_prompt=user_prompt,
            temperature=temperature,
            json_mode=json_mode,
        )
    raise ValueError(f"Unsupported LLM provider: {provider}")


def call_openai(
    *,
    model: str,
    system_prompt: str,
    user_prompt: str,
    temperature: float,
    json_mode: bool,
) -> str:
    if not os.environ.get("OPENAI_API_KEY"):
        raise RuntimeError("OPENAI_API_KEY is not configured.")

    from openai import OpenAI

    client = OpenAI()
    kwargs: dict[str, object] = {
        "model": model,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        "temperature": temperature,
    }
    if json_mode:
        kwargs["response_format"] = {"type": "json_object"}

    try:
        response = client.chat.completions.create(**kwargs)
    except TypeError:
        kwargs.pop("response_format", None)
        response = client.chat.completions.create(**kwargs)

    return (response.choices[0].message.content or "").strip()


def call_anthropic(
    *,
    model: str,
    system_prompt: str,
    user_prompt: str,
    temperature: float,
) -> str:
    if not os.environ.get("ANTHROPIC_API_KEY"):
        raise RuntimeError("ANTHROPIC_API_KEY is not configured.")

    import anthropic

    client = anthropic.Anthropic()
    response = client.messages.create(
        model=model,
        max_tokens=4096,
        temperature=temperature,
        system=system_prompt,
        messages=[{"role": "user", "content": user_prompt}],
    )
    parts: list[str] = []
    for block in response.content:
        text = getattr(block, "text", None)
        if text:
            parts.append(text)
    return "\n".join(parts).strip()


def call_google(
    *,
    model: str,
    system_prompt: str,
    user_prompt: str,
    temperature: float,
    json_mode: bool,
) -> str:
    api_key = os.environ.get("GOOGLE_API_KEY") or os.environ.get("GEMINI_API_KEY")
    if not api_key:
        raise RuntimeError("GOOGLE_API_KEY or GEMINI_API_KEY is not configured.")

    payload: dict[str, object] = {
        "systemInstruction": {"parts": [{"text": system_prompt}]},
        "contents": [
            {
                "role": "user",
                "parts": [{"text": user_prompt}],
            }
        ],
        "generationConfig": {
            "temperature": temperature,
        },
    }
    if json_mode:
        payload["generationConfig"]["responseMimeType"] = "application/json"  # type: ignore[index]

    response = requests.post(
        GOOGLE_GENERATE_URL.format(model=model),
        params={"key": api_key},
        json=payload,
        timeout=60,
    )
    response.raise_for_status()
    data = response.json()
    try:
        parts = data["candidates"][0]["content"]["parts"]
    except (KeyError, IndexError) as exc:
        raise RuntimeError(f"Unexpected Google response: {data}") from exc

    return "\n".join(part.get("text", "") for part in parts).strip()
