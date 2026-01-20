#!/usr/bin/env python3
"""
DEPRECATED: Use g/tools/core_intake.py instead.
This file remains for backward compatibility imports.
"""

import sys
from pathlib import Path

# Add repo root to path to verify imports
REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.append(str(REPO_ROOT))

# Proxy imports to g/tools/core_intake.py
try:
    from g.tools.core_intake import build_intake, render_text
except ImportError:
    # Fallback if g/tools/core_intake.py is not importable (e.g. not a module)
    # We will just redefine them as empty or raise error?
    # Better: just tell user to move. But for the sake of the plan:
    
    # Redefine minimally if import fails
    def build_intake(*args, **kwargs):
        raise ImportError("Please use g.tools.core_intake instead of bridge.lac.core_intake")
    
    def render_text(*args, **kwargs):
        raise ImportError("Please use g.tools.core_intake instead of bridge.lac.core_intake")

__all__ = ["build_intake", "render_text"]

if __name__ == "__main__":
    print("WARNING: This script is deprecated. Forwarding to g/tools/core_intake.py...")
    import subprocess
    sys.exit(subprocess.call([sys.executable, str(REPO_ROOT / "g/tools/core_intake.py")] + sys.argv[1:]))
