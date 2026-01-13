import os
import time
import sys
import vertexai
from vertexai.generative_models import GenerativeModel
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type

# >>> 02LUKA_DECISION_SUMMARIZER_IMPORT >>>
try:
    from decision_summarizer import summarize_decision, build_decision_block_for_logs
except ImportError:
    summarize_decision = None
    build_decision_block_for_logs = None
# <<< 02LUKA_DECISION_SUMMARIZER_IMPORT <<<

# >>> PHASE 18: IDEMPOTENCY LEDGER >>>
# Feature flag: set IDEMPOTENCY_LEDGER=on to enable
IDEMPOTENCY_ENABLED = os.environ.get("IDEMPOTENCY_LEDGER", "off").lower() == "on"
_ledger = None

def get_ledger():
    """Lazy-load idempotency ledger."""
    global _ledger
    if _ledger is None and IDEMPOTENCY_ENABLED:
        try:
            from idempotency_ledger import IdempotencyLedger
            _ledger = IdempotencyLedger()
            print("   📒 Idempotency ledger enabled")
        except ImportError:
            print("   ⚠️ Idempotency ledger module not found")
    return _ledger
# <<< PHASE 18: IDEMPOTENCY LEDGER <<<

# --- Configuration ---
PROJECT_ID = "luka-cloud-471113" 
LOCATION = "us-central1"
MODEL_NAME = "gemini-2.0-flash-001"
WATCH_DIR = "./magic_bridge/inbox"
PID_FILE = "/tmp/gemini_bridge.pid"
IGNORE_DIRS = {".git", ".DS_Store", "__pycache__", "gemini_env", "infra", ".gemini", "node_modules"}
MAX_READ_TURNS = 3

def acquire_lock():
    if os.path.exists(PID_FILE):
        try:
            with open(PID_FILE, "r") as f:
                old_pid = int(f.read().strip())
            # Check if process is actually running
            os.kill(old_pid, 0)
            print(f"❌ Error: Gemini Bridge is already running (PID {old_pid})")
            sys.exit(1)
        except (ValueError, OSError, ProcessLookupError):
            # Stale PID file, overwrite it
            pass
    
    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))

def release_lock():
    if os.path.exists(PID_FILE):
        try:
            with open(PID_FILE, "r") as f:
                pid = int(f.read().strip())
            if pid == os.getpid():
                os.remove(PID_FILE)
        except Exception:
            pass

class GeminiHandler(FileSystemEventHandler):
    def __init__(self, model):
        self.model = model

    @retry(
        stop=stop_after_attempt(5),
        wait=wait_exponential(multiplier=1, min=2, max=10),
        retry=retry_if_exception_type(Exception),
        reraise=True
    )
    def generate_with_retry(self, prompt):
        return self.model.generate_content(prompt)

    def get_file_tree(self, start_path="."):
        """Generates a visual tree of the project structure."""
        tree_lines = []
        for root, dirs, files in os.walk(start_path):
            # Modify dirs in-place to skip ignored ones
            dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]
            
            level = root.replace(start_path, '').count(os.sep)
            indent = ' ' * 4 * (level)
            tree_lines.append(f"{indent}{os.path.basename(root)}/")
            subindent = ' ' * 4 * (level + 1)
            for f in files:
                if f not in IGNORE_DIRS and not f.endswith(".summary.txt"):
                    tree_lines.append(f"{subindent}{f}")
        return "\n".join(tree_lines)

    def on_created(self, event):
        """Handle new file creation events."""
        if event.is_directory: return
        filename = os.path.basename(event.src_path)
        if filename == ".DS_Store" or filename.endswith(".summary.txt"): return

        print(f"📝 Detected new file: {filename}")
        time.sleep(1) # Debounce
        self.process_file(event.src_path)

    def on_modified(self, event):
        if event.is_directory: return
        filename = os.path.basename(event.src_path)
        if filename == ".DS_Store" or filename.endswith(".summary.txt"): return

        print(f"📝 Detected change in: {filename}")
        time.sleep(1) # Debounce
        self.process_file(event.src_path)

    def process_file(self, file_path):
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                content = f.read()

            # >>> 02LUKA_DECISION_SUMMARIZER_LOG >>>
            # Log decision analysis (telemetry, non-blocking)
            if content.strip() and summarize_decision is not None:
                try:
                    decision_info = summarize_decision(content)
                    # Use repo root (parent of this file)
                    repo_root = os.path.dirname(os.path.abspath(__file__))
                    log_path = os.path.join(repo_root, 'g/telemetry/decision_log.jsonl')
                    os.makedirs(os.path.dirname(log_path), exist_ok=True)
                    with open(log_path, "a", encoding="utf-8") as _log:
                        _log.write(decision_info.to_json() + "\n")
                except Exception:
                    pass  # Silent fail, don't break bridge
            # <<< 02LUKA_DECISION_SUMMARIZER_LOG <<<

            if not content.strip(): return

            # >>> PHASE 18: IDEMPOTENCY CHECK >>>
            ledger = get_ledger()
            idempotency_key = None
            if ledger:
                idempotency_key = ledger.compute_key(file_path, content)
                if ledger.is_processed(idempotency_key):
                    cached_output = ledger.get_cached_output(idempotency_key)
                    print(f"   ⏭️ Skipped (duplicate): {os.path.basename(file_path)} → {cached_output}")
                    ledger.record_skipped(idempotency_key, file_path, cached_output)
                    return
            # <<< PHASE 18: IDEMPOTENCY CHECK <<<

            # 1. Build Initial Context
            tree = self.get_file_tree(".")
            current_prompt = (
                f"[PROJECT STRUCTURE]\n{tree}\n\n"
                f"[CURRENT FILE: {os.path.basename(file_path)}]\n{content}\n\n"
                "INSTRUCTIONS:\n"
                "1. Analyze the Current File in the context of the Project Structure.\n"
                "2. If you need to read another file to answer, reply ONLY with: READ: <relative_path>\n"
                "3. Otherwise, provide the summary/review."
            )

            print(f"   🚀 Sending to Vertex AI ({MODEL_NAME})...")
            
            # 2. Active Reading Loop
            final_response_text = ""
            
            for turn in range(MAX_READ_TURNS):
                response = self.generate_with_retry(current_prompt)
                text = response.text.strip()
                
                # Check for Read Request (Robust)
                import re
                match = re.search(r"READ:\s*(.+)", text)
                
                if match:
                    target_file = match.group(1).strip()
                    print(f"      👀 Agent requested to read: {target_file}")
                    
                    # Security/Path Check
                    if os.path.exists(target_file) and os.path.isfile(target_file):
                        try:
                            with open(target_file, "r") as tf:
                                supp_content = tf.read()
                            # Append to prompt
                            heading = f"\n\n[SUPPLEMENTARY FILE: {target_file}]\n"
                            current_prompt += f"{heading}{supp_content}\n"
                            # Continue loop to send back the new context
                            continue 
                        except Exception as e:
                            current_prompt += f"\n\n[SYSTEM ERROR reading {target_file}: {e}]\n"
                    else:
                        current_prompt += f"\n\n[SYSTEM ERROR: File {target_file} not found]\n"
                else:
                    # Normal response
                    final_response_text = text
                    break

            # 3. Save Output
            # Save to outbox instead of inbox
            filename = os.path.basename(file_path)
            outbox_dir = os.path.join(os.path.dirname(os.path.dirname(file_path)), "outbox")
            os.makedirs(outbox_dir, exist_ok=True)
            output_path = os.path.join(outbox_dir, f"{filename}.summary.txt")
            with open(output_path, "w", encoding="utf-8") as f:
                f.write(final_response_text)

            print(f"   ✅ Saved response to: {os.path.basename(output_path)} (in outbox)")

            # >>> PHASE 18: RECORD SUCCESS >>>
            if ledger and idempotency_key:
                ledger.record_success(idempotency_key, file_path, output_path)
            # <<< PHASE 18: RECORD SUCCESS <<<

        except Exception as e:
            print(f"   ❌ Error: {e}")
            # >>> PHASE 18: RECORD FAILURE >>>
            if ledger and idempotency_key:
                ledger.record_failed(idempotency_key, file_path, str(e))
            # <<< PHASE 18: RECORD FAILURE <<<

def main():
    print("🔮 Initializing Gemini Bridge (Context Aware + Retry)...")
    
    try:
        vertexai.init(project=PROJECT_ID, location=LOCATION)
        model = GenerativeModel(MODEL_NAME)
        print(f"   Connecting to project '{PROJECT_ID}'...")
    except Exception as e:
        print(f"❌ Failed to initialize Vertex AI: {e}")
        sys.exit(1)

    if "--self-check" in sys.argv:
        print("🔍 Running Self-Check...")
        checks = {
            "Vertex AI Init": True, # Reached here means init worked
            "Watch Dir Presence": os.path.exists(WATCH_DIR),
            "Watch Dir Permissions": os.access(WATCH_DIR, os.W_OK) if os.path.exists(WATCH_DIR) else False,
            "Environment (PROJECT_ID)": bool(PROJECT_ID),
        }
        for name, ok in checks.items():
            print(f"   - {name}: {'✅' if ok else '❌'}")
        
        if not all(checks.values()):
            print("❌ Self-check FAILED.")
            sys.exit(1)
            
        print("✅ Self-check PASSED.")
        sys.exit(0)

    acquire_lock()

    if not os.path.exists(WATCH_DIR):
        os.makedirs(WATCH_DIR)

    event_handler = GeminiHandler(model)
    observer = Observer()
    observer.schedule(event_handler, path=WATCH_DIR, recursive=False)
    observer.start()

    print(f"👀 Watching '{WATCH_DIR}' for changes...")
    try:
        while True: time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
        print("\n🛑 Stopping...")
    finally:
        release_lock()
    observer.join()

if __name__ == "__main__":
    main()
