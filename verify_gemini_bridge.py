import os
import time
import subprocess
import sys
from pathlib import Path

# Setup paths
venv_python = Path(".tmp/venv_gemini/bin/python").resolve()
bridge_script = Path("gemini_bridge.py").resolve()
watch_dir = Path("magic_bridge").resolve()
test_file = watch_dir / "test_verify.txt"
summary_file = watch_dir / "test_verify.txt.summary.txt"

# Ensure API Key is present
if not os.getenv("GEMINI_API_KEY"):
    # Try to load from .env.local
    env_local = Path(".env.local")
    if env_local.exists():
        with open(env_local) as f:
            for line in f:
                if line.startswith("GEMINI_API_KEY="):
                    os.environ["GEMINI_API_KEY"] = line.strip().split("=", 1)[1]
                    break

if not os.getenv("GEMINI_API_KEY"):
    print("❌ Checking API Key: FAILED (Not found in env or .env.local)")
    sys.exit(1)
else:
    print("✅ Checking API Key: FOUND")

# 1. Start Bridge in background
print("🚀 Starting Gemini Bridge...")
env = os.environ.copy()
env.pop("PYTHONPATH", None) # Prevent leakage
env["PYTHONUNBUFFERED"] = "1" # Force stdout flush

process = subprocess.Popen(
    [str(venv_python), str(bridge_script)],
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
    env=env
)

# Give it a moment to start
time.sleep(2)
if process.poll() is not None:
    print("❌ Bridge failed to start:")
    print(process.stdout.read())
    print(process.stderr.read())
    sys.exit(1)

try:
    # 2. Trigger Event
    print(f"📝 Writing test file to {test_file}...")
    watch_dir.mkdir(exist_ok=True)
    test_file.write_text("What is 2 + 2? Answer briefly.", encoding="utf-8")

    # 3. Wait for processing (Debounce 1s + Network)
    print("⏳ Waiting for summary (max 10s)...")
    start = time.time()
    while time.time() - start < 10:
        if summary_file.exists():
            print("✅ Summary file detected!")
            content = summary_file.read_text(encoding="utf-8")
            print("---------------------------------------------------")
            print(f"📄 Content: {content.strip()}")
            print("---------------------------------------------------")
            if len(content) > 0:
                print("✅ Verification SUCCESS")
                sys.exit(0)
            else:
                print("❌ Verification FAILED (File empty)")
                sys.exit(1)
        time.sleep(1)
    
    print("❌ Verification FAILED (Timeout waiting for summary file)")
    sys.exit(1)

finally:
    # 4. Cleanup
    print("🛑 Stopping Bridge...")
    process.terminate()
    try:
        process.wait(timeout=2)
    except subprocess.TimeoutExpired:
        process.kill()
    
    # Cleanup files
    if test_file.exists(): test_file.unlink()
    if summary_file.exists(): summary_file.unlink()
