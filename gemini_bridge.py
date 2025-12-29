import os
import time
import sys
import google.generativeai as genai
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

# --- Configuration ---
API_KEY = os.getenv("GEMINI_API_KEY")
MODEL_NAME = "gemini-1.5-flash"
WATCH_DIR = "./magic_bridge"

class GeminiHandler(FileSystemEventHandler):
    def on_modified(self, event):
        # 1. Ignore directories
        if event.is_directory:
            return

        filename = os.path.basename(event.src_path)
        
        # 2. Ignore noise (.DS_Store and .summary.txt files)
        if filename == ".DS_Store" or filename.endswith(".summary.txt"):
            return

        print(f"📝 Detected change in: {filename}")

        # 3. Debounce (wait for write to finish)
        time.sleep(1)

        # 4. Process file
        self.process_file(event.src_path)

    def process_file(self, file_path):
        try:
            # Read file content
            with open(file_path, "r", encoding="utf-8") as f:
                content = f.read()

            if not content.strip():
                print("   ⚠️  File is empty, skipping.")
                return

            print("   🚀 Sending to Gemini...")
            
            # Call Gemini API
            model = genai.GenerativeModel(MODEL_NAME)
            prompt = f"Summarize text or review code for bugs:\n\n{content}"
            response = model.generate_content(prompt)
            
            # Write response to output file
            output_path = f"{file_path}.summary.txt"
            with open(output_path, "w", encoding="utf-8") as f:
                f.write(response.text)
                
            print(f"   ✅ Saved response to: {os.path.basename(output_path)}")

        except Exception as e:
            print(f"   ❌ Error processing file: {e}")

def main():
    # 1. Check API Key
    if not API_KEY:
        print("❌ Error: GEMINI_API_KEY environment variable not set.")
        sys.exit(1)

    # 2. Configure Gemini
    genai.configure(api_key=API_KEY)

    # 3. Ensure watch directory exists
    if not os.path.exists(WATCH_DIR):
        try:
            os.makedirs(WATCH_DIR)
            print(f"✅ Created directory: {WATCH_DIR}")
        except OSError as e:
            print(f"❌ Error creating directory {WATCH_DIR}: {e}")
            sys.exit(1)

    # 4. Setup Watchdog
    event_handler = GeminiHandler()
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
