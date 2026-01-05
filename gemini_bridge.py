import os
import time
import sys
import warnings

# Suppress Vertex AI deprecation warnings immediately
warnings.filterwarnings("ignore", category=UserWarning, module=r"vertexai(\..*)?")

import vertexai
from vertexai.generative_models import GenerativeModel
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type

from datetime import datetime
import json
import hashlib

# --- Configuration & State ---
PROJECT_ID = "luka-cloud-471113" 
LOCATION = "us-central1"
MODEL_NAME = "gemini-2.0-flash-001"
PROCESS_ID = os.getpid()
MIN_PROCESS_INTERVAL_SECONDS = 2

# Use absolute paths to prevent any relative path ambiguity
REPO_ROOT = os.path.dirname(os.path.abspath(__file__))
BRIDGE_DIR = os.path.join(REPO_ROOT, "magic_bridge")
INBOX_DIR = os.path.join(BRIDGE_DIR, "inbox")
OUTBOX_DIR = os.path.join(BRIDGE_DIR, "outbox")
WATCH_DIR = INBOX_DIR  # Absolute path

# Ignore dirs are still useful for system junk
IGNORE_DIRS = {".git", ".DS_Store", "__pycache__", "gemini_env", "infra", ".gemini", "node_modules"}
# IGNORE_FILES = {".summary.txt", "atg_snapshot.md", "atg_snapshot.json"} # No longer needed with inbox/outbox
MAX_READ_TURNS = 3
TELEMETRY_FILE = os.path.join(REPO_ROOT, "g/telemetry/atg_runner.jsonl")
FS_INDEX_FILE = os.path.join(REPO_ROOT, "g/telemetry/fs_index.jsonl")
AG_BRAIN_ROOT = os.path.expanduser("~/.gemini/antigravity/brain")

# --- Safety Helpers ---
def safe_read_lines(path, limit=15, chunk_size=4096):
    """Safely reads the last N lines of a file, handling Seatbelt restrictions."""
    if not os.path.exists(path): return []
    try:
        with open(path, 'rb') as f:
            f.seek(0, 2)
            fsize = f.tell()
            f.seek(max(fsize - chunk_size, 0), 0)
            chunk = f.read().decode('utf-8', errors='ignore')
            return [l for l in chunk.splitlines() if l.strip()][-limit:]
    except (PermissionError, OSError):
        return []

def log_telemetry(event_name, **kwargs):
    """Appends a structured JSON record to the telemetry file, safe under Seatbelt."""
    try:
        # Check if dir exists first to avoid unnecessary makedirs calls
        telemetry_dir = os.path.dirname(TELEMETRY_FILE)
        if not os.path.exists(telemetry_dir):
            os.makedirs(telemetry_dir, exist_ok=True)
            
        record = {
            "ts": datetime.now().astimezone().isoformat(),
            "event": event_name,
            "lane": "ATG_RUNNER",
            "actor": "gemini_bridge",
            "pid": PROCESS_ID,
            **kwargs
        }
        with open(TELEMETRY_FILE, "a", encoding="utf-8") as f:
            f.write(json.dumps(record) + "\n")
    except (PermissionError, OSError):
        # Silent failure for telemetry to avoid log noise in bridge
        pass
    except Exception as e:
        print(f"⚠️ Telemetry Error: {e}")

def get_recent_fs_activity(limit=15):
    """Reads the tail of the FS Index to provide passive context, safe under Seatbelt."""
    lines = safe_read_lines(FS_INDEX_FILE, limit=limit)
    if not lines: return "(No recent filesystem activity recorded or accessible)"
    
    records = []
    for line in lines:
        try:
            rec = json.loads(line)
            ts = rec.get('ts', '')[11:16]
            event = rec.get('event', '').upper()
            file = rec.get('file', '')
            records.append(f"[{ts}] {event} {file}")
        except: pass
            
    return "\n".join(records) if records else "(No recent changes)"

# Placeholder for telemetry module if it's meant to be imported
class Telemetry:
    def log_event(self, event_name, **kwargs):
        log_telemetry(event_name, **kwargs)
    def log_error(self, event_name, **kwargs):
        log_telemetry(event_name, **kwargs)
telemetry = Telemetry()


class GeminiHandler(FileSystemEventHandler):
    def __init__(self, model):
        self.model = model
        self.bridge_dir = BRIDGE_DIR 
        self.inbox_dir = INBOX_DIR
        self.outbox_dir = OUTBOX_DIR
        self.processed_hashes = {}
        self.processed_at = {}

    def on_created(self, event):
        """Treat new files like modifications (common inbox drop pattern)."""
        return self.on_modified(event)

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

    def on_modified(self, event):
        if event.is_directory: return
        filename = os.path.basename(event.src_path)
        
        if filename.startswith("."): return
        if filename.endswith(".summary.txt"): return
        
        # STRICT Inbox Check using commonpath (filesystem-safe)
        src_abs = os.path.abspath(event.src_path)
        inbox_abs = os.path.abspath(INBOX_DIR)
        
        try:
            # commonpath raises ValueError if paths are on different drives or unrelated
            common = os.path.commonpath([src_abs, inbox_abs])
            if common != inbox_abs:
                # File is NOT within inbox (e.g., it's in outbox)
                return
        except ValueError:
            # Paths are unrelated
            return

        print(f"📝 Detected change in: {filename} (inbox)")
        
        time.sleep(1) # Debounce BEFORE anything heavy
        
        # EARLY Deduplication: Read file and check hash BEFORE any logging or processing
        try:
            with open(event.src_path, "r", encoding="utf-8") as f:
                content = f.read()
            if not content.strip():
                return  # Empty file, skip
            
            content_hash = hashlib.md5(content.encode('utf-8')).hexdigest()
            if self.processed_hashes.get(filename) == content_hash:
                print(f"   ⏭️  Skipping (content unchanged): {filename}")
                return
            now = time.time()
            last_at = self.processed_at.get(filename)
            if last_at and (now - last_at) < MIN_PROCESS_INTERVAL_SECONDS:
                print(f"   ⏭️  Skipping (recently processed): {filename}")
                return
            self.processed_hashes[filename] = content_hash
            self.processed_at[filename] = now
        except Exception as e:
            print(f"   ⚠️  Error reading file for dedup: {e}")
            return
        
        # Log detection ONLY for files that will actually be processed
        telemetry.log_event("file_detected", actor="gemini_bridge", file=filename, dir="inbox")
        
        self.process_file(event.src_path, filename, content)

    def inject_into_antigravity(self, filename, summary):
        """Injects the summary into the active Antigravity brain session."""
        # Guard: Only run if AG_WIRE env var is set
        if os.environ.get("AG_WIRE", "0") != "1": return
        
        if not os.path.exists(AG_BRAIN_ROOT): return
        try:
            sessions = [os.path.join(AG_BRAIN_ROOT, d) for d in os.listdir(AG_BRAIN_ROOT) if os.path.isdir(os.path.join(AG_BRAIN_ROOT, d))]
            if not sessions: return
            latest_session = max(sessions, key=os.path.getmtime)
            
            # Write to a dedicated context file
            target_file = os.path.join(latest_session, "99_BRIDGE_FEEDBACK.md")
            timestamp = datetime.now().strftime("%H:%M:%S")
            
            with open(target_file, "a", encoding="utf-8") as f:
                f.write(f"\n### [{timestamp}] Bridge Insight: {filename}\n{summary}\n")
            print(f"   🧠 Wired to Antigravity: {os.path.basename(latest_session)}")
        except Exception as e:
            print(f"   ⚠️ Wiring failed: {e}")

    def process_file(self, file_path, filename, content):
        """Process a file that has already been validated and deduplicated."""
        start_time = time.time()
        print(f"   🚀 Sending to Vertex AI ({MODEL_NAME})...")
        
        telemetry.log_event("processing_start", actor="gemini_bridge", file=filename)
        
        try:

            prompt = f"""
            You are an AI assistant monitoring a project.
            The user has updated the file: {filename}
            
            Content:
            {content}
            
            Please provide a brief summary of the changes and any potential issues or suggestions.
            Keep it concise.
            """
            
            # --- Passive Context (Read FS Index) ---
            recent_fs_activity = get_recent_fs_activity()
            if recent_fs_activity:
                prompt += f"\n\nRECENT FILESYSTEM ACTIVITY (Passive Visibility):\n{recent_fs_activity}"

            response = self.model.generate_content(prompt)
            summary = response.text
            
            # Write to OUTBOX
            output_filename = f"{filename}.summary.txt"
            output_path = os.path.join(self.outbox_dir, output_filename)
            
            with open(output_path, "w", encoding="utf-8") as f:
                f.write(summary)
                
            print(f"   ✅ Saved response to: {output_filename} (in outbox)")
            
            # Inject into Antigravity Context (Safe call)
            self.inject_into_antigravity(filename, summary)
            
            duration = (time.time() - start_time) * 1000
            telemetry.log_event(
                "processing_complete", 
                actor="gemini_bridge", 
                file=filename, 
                duration_ms=duration, 
                output_file=output_filename,
                output_dir="outbox"
            )

        except Exception as e:
            print(f"   ❌ Error: {e}")
            telemetry.log_error("processing_failed", actor="gemini_bridge", file=filename, error=str(e))

def main():
    print("🔮 Initializing Gemini Bridge (Context Aware + Retry)...")
    
    try:
        # Ensure directories exist
        os.makedirs(INBOX_DIR, exist_ok=True)
        os.makedirs(OUTBOX_DIR, exist_ok=True)
        
        vertexai.init(project=PROJECT_ID, location=LOCATION)
        model = GenerativeModel(MODEL_NAME)
        print(f"   Connecting to project '{PROJECT_ID}'...")
    except Exception as e:
        print(f"❌ Failed to initialize Vertex AI: {e}")
        sys.exit(1)

    active_handler = GeminiHandler(model)
    observer = Observer()
    observer.schedule(active_handler, path=WATCH_DIR, recursive=False)
    observer.start()

    print(f"👀 Watching '{WATCH_DIR}' for changes...")
    log_telemetry("startup", watch_dir=WATCH_DIR, model=MODEL_NAME)
    try:
        while True: time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
        print("\n🛑 Stopping...")
        log_telemetry("shutdown", reason="keyboard_interrupt")
    observer.join()

if __name__ == "__main__":
    main()
