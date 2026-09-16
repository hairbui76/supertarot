"""Compatibility wrapper for the learning embedding CLI.

Prefer `python -m learning.embeddings` for new usage.
"""

from learning.embeddings import *  # noqa: F401,F403
from learning.embeddings import main


if __name__ == "__main__":
    main()
