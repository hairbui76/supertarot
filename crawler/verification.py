"""Compatibility wrapper for the learning verification-prompt CLI.

Prefer `python -m learning.verification` for new usage.
"""

from learning.verification import *  # noqa: F401,F403
from learning.verification import main


if __name__ == "__main__":
    main()
