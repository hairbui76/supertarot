"""Compatibility wrapper for the VI enrichment CLI.

Prefer `python -m enrichment.enrich_vi` for new usage.
"""

from enrichment.enrich_vi import *  # noqa: F401,F403
from enrichment.enrich_vi import main


if __name__ == "__main__":
    main()
