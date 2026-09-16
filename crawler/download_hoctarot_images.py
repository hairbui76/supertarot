"""Compatibility wrapper for the Hoctarot image downloader CLI.

Prefer `python -m enrichment.download_hoctarot_images` for new usage.
"""

from enrichment.download_hoctarot_images import *  # noqa: F401,F403
from enrichment.download_hoctarot_images import main


if __name__ == "__main__":
    main()
