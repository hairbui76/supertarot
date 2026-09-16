"""Compatibility wrapper for the learning study-session CLI.

Prefer `python -m learning.study` for new usage.
"""

from learning.study import *  # noqa: F401,F403
from learning.study import main


if __name__ == "__main__":
    main()
