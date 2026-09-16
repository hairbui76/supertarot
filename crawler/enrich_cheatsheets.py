"""Compatibility wrapper for the cheatsheet enrichment CLI.

Prefer `python -m enrichment.enrich_cheatsheets` for new usage.
"""

from enrichment.enrich_cheatsheets import *  # noqa: F401,F403
from enrichment.enrich_cheatsheets import main


if __name__ == "__main__":
    main()
