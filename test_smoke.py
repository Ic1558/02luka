import sys
import os
import logging

# Configure logging to stdout
logging.basicConfig(level=logging.INFO, stream=sys.stdout)

print(f"DEBUG: LAC_BASE_DIR={os.environ.get('LAC_BASE_DIR')}")
sys.path.append(os.environ["LAC_BASE_DIR"])

try:
    from shared.policy import apply_patch
    print("DEBUG: Import successful")
    result = apply_patch("g/src/antigravity/TEST_LAC_WRITE.txt", "hello from LAC", dry_run=True)
    print(f"DEBUG: Result={result}")
except Exception as e:
    print(f"DEBUG: Error={e}")
