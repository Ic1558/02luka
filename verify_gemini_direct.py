import os
import sys
from pathlib import Path

# Try to load env
env_local = Path(".env.local")
if env_local.exists():
    with open(env_local) as f:
        for line in f:
            if line.startswith("GEMINI_API_KEY="):
                val = line.strip().split("=", 1)[1]
                # Strip quotes if present
                os.environ["GEMINI_API_KEY"] = val.strip('"\'')
                break

if not os.getenv("GEMINI_API_KEY"):
    print("❌ API Key NOT FOUND")
    sys.exit(1)

try:
    import google.generativeai as genai
    print("✅ Library imported successfully.")
except ImportError as e:
    print(f"❌ Failed to import library: {e}")
    sys.exit(1)

key = os.getenv("GEMINI_API_KEY")
masked = f"{key[:4]}...{key[-4:]}" if key and len(key) > 8 else "INVALID"
print(f"🔑 Debug Key: {masked} (Len: {len(key) if key else 0})")

print("🚀 Testing Gemini API connection...")

try:
    genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
    model = genai.GenerativeModel("gemini-1.5-flash")
    print("   Sending request...")
    response = model.generate_content("Say 'OK' if you can hear me.")
    print(f"✅ Response received: {response.text.strip()}")
except Exception as e:
    print(f"❌ API Call Failed: {e}")
    sys.exit(1)
