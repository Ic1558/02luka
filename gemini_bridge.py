import os
import time
import sys
import vertexai
from vertexai.generative_models import GenerativeModel
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
import google.auth

# --- Configuration ---
# Attempts to auto-detect project/location from gcloud
PROJECT_ID = "luka-cloud-471113" # Detected from your session
LOCATION = "us-central1"
MODEL_NAME = "gemini-1.5-flash"
WATCH_DIR = "./magic_bridge"

class GeminiHandler(FileSystemEventHandler):
    def __init__(self, model):
        self.model = model

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

            if not content.strip(): return

            print(f"   🚀 Sending to Vertex AI ({MODEL_NAME})...")
            
            prompt = f"Summarize text or review code for bugs. Be concise:\n\n{content}"
            response = self.model.generate_content(prompt)
            
            output_path = f"{file_path}.summary.txt"
            with open(output_path, "w", encoding="utf-8") as f:
                f.write(response.text)
                
            print(f"   ✅ Saved response to: {os.path.basename(output_path)}")

        except Exception as e:
            print(f"   ❌ Error: {e}")
            if "404" in str(e) and "Publisher Model" in str(e):
                print("      👉 Action Required: Enable 'Vertex AI API' in Google Cloud Console.")

def main():
    print("🔮 Initializing Gemini Bridge (Vertex AI via ADC)...")
    
    # 1. Init Vertex AI
    try:
        vertexai.init(project=PROJECT_ID, location=LOCATION)
        model = GenerativeModel(MODEL_NAME)
        # Smoke test
        print(f"   Connecting to project '{PROJECT_ID}'...")
    except Exception as e:
        print(f"❌ Failed to initialize Vertex AI: {e}")
        print("   Run: gcloud auth application-default login")
        sys.exit(1)

    # 2. Setup Watchdog
    if not os.path.exists(WATCH_DIR):
        os.makedirs(WATCH_DIR)
        print(f"   Created watch directory: {WATCH_DIR}")

    event_handler = GeminiHandler(model)
    observer = Observer()
    observer.schedule(event_handler, path=WATCH_DIR, recursive=False)
    observer.start()

    print(f"👀 Watching '{WATCH_DIR}' for changes...")
    print("   (Press Ctrl+C to stop)")

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
        print("\n🛑 Stopping...")
    
    observer.join()

if __name__ == "__main__":
    main()
