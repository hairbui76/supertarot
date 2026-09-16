"""Console helpers for Windows-safe UTF-8 CLI output."""

from __future__ import annotations

import io
import sys


def configure_utf8_stdio() -> None:
    """Use UTF-8 for stdout/stderr when the host terminal defaults to cp125x."""
    for stream_name in ("stdout", "stderr"):
        stream = getattr(sys, stream_name)
        encoding = (getattr(stream, "encoding", None) or "").lower()
        if encoding == "utf-8":
            continue

        buffer = getattr(stream, "buffer", None)
        if buffer is None:
            continue

        setattr(
            sys,
            stream_name,
            io.TextIOWrapper(
                buffer,
                encoding="utf-8",
                errors="replace",
                line_buffering=True,
            ),
        )
