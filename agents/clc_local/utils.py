# agents/clc_local/utils.py
"""
Utility functions for the local executor. (v0.1)
"""
from __future__ import annotations
from pathlib import Path

def write_file(path_str: str, content: str):
    """
    Creates or overwrites a file with the given content.
    Ensures parent directories are created.
    """
    path = Path(path_str)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        f.write(content)
    print(f"    - Wrote {len(content)} chars to {path_str}")

def apply_patch(path_str: str, patch_text: str):
    """
    Applies a unified diff patch to a file.
    Placeholder for a more robust implementation.
    """
    # In a real implementation, we would use a library like `patch`
    # or a more robust `subprocess.run(['patch', ...])` call.
    # For this skeleton, we will raise a NotImplementedError to indicate
    # that this is a placeholder for GMX/CLS to implement.
    print(f"    - NOTE: 'apply_patch' is not fully implemented in this skeleton.")
    
    # A simple, naive implementation for demonstration purposes:
    # This is NOT robust and should be replaced.
    if not Path(path_str).exists():
        if patch_text.startswith("---" + " /dev/null"):
            # This is a new file patch
            new_content = "\n".join([line[1:] for line in patch_text.splitlines() if line.startswith('+') and not line.startswith('+++')])
            write_file(path_str, new_content)
        else:
            raise FileNotFoundError(f"Cannot apply patch: file {path_str} does not exist.")
    else:
         raise NotImplementedError("'apply_patch' for existing files is not implemented in this skeleton.")
    
