"""Compatibility wrapper for the enrichment translation CLI.

Prefer `python -m enrichment.translate` for new usage.
"""

from enrichment.translate import *  # noqa: F401,F403
from enrichment.translate import main


if __name__ == "__main__":
    main()
