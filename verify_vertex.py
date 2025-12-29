import vertexai
from vertexai.generative_models import GenerativeModel
import google.auth
import os

print("🚀 Testing Vertex AI (ADC)...")

# 1. Get Credentials & Project
try:
    creds, project = google.auth.default()
    print(f"✅ Credentials found. Project: {project}")
except Exception as e:
    print(f"❌ Failed to get credentials: {e}")
    exit(1)

# 3. Test Generation in Regions
regions = ["us-central1", "us-east1", "us-east4", "us-west1"]

for loc in regions:
    print(f"\n🌍 Testing Memory: {loc} ...")
    try:
        vertexai.init(project=project, location=loc)
        model = GenerativeModel("gemini-1.5-flash")
        response = model.generate_content("Say 'ADC Works in " + loc + "!'")
        print(f"✅ SUCCESS in {loc}: {response.text.strip()}")
        # Stop on first success
        exit(0)
    except Exception as e:
        print(f"❌ Failed in {loc}: {e}")

print("\n❌ All regions failed.")
exit(1)
