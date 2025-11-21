#!/usr/bin/env python3
# g/tools/check_quota.py
"""
Performs a live health check on the Gemini API to verify connectivity,
authentication, and quota availability.
"""
from __future__ import annotations
import sys
import os
from pathlib import Path

# --- Robust Path Setup ---
try:
    PROJECT_ROOT = Path(__file__).resolve().parents[2]
    sys.path.insert(0, str(PROJECT_ROOT))
    from g.connectors.gemini_connector import GeminiConnector
    from dotenv import load_dotenv
except (ImportError, IndexError) as e:
    print(f"FATAL: Could not set up paths. Run this script from the project root. Error: {e}", file=sys.stderr)
    sys.exit(1)

def check_api_health():
    """
    Performs a small, lightweight API call to check the health and quota status.
    """
    print("--- Antigravity Quota & Health Check ---")

    # 1. Load environment from .env.local
    env_local_path = PROJECT_ROOT / ".env.local"
    if env_local_path.exists():
        load_dotenv(dotenv_path=env_local_path)
        print(f"✅ Loaded environment from: {env_local_path.name}")
    else:
        print(f"⚠️  Warning: .env.local not found. Relying on shell environment for GEMINI_API_KEY.")

    # 2. Initialize the connector
    # Using a fast, lightweight model for this check
    model_to_test = os.environ.get("GMX_MODEL", "gemini-flash-latest") 
    print(f"Initializing connector with model: {model_to_test}...")
    connector = GeminiConnector(model_name=model_to_test)

    if not connector.is_available():
        print("\n❌ API HEALTH CHECK FAILED")
        print("   Reason: Connector is not available.")
        print("   Troubleshooting:")
        print("   - Ensure 'google-generativeai' and 'python-dotenv' are installed in your venv.")
        print("   - Ensure GEMINI_API_KEY is set in your .env.local file or shell environment.")
        return False

    print("✅ Connector initialized.")

    # 3. Perform a small, inexpensive API call
    print("Performing a lightweight test API call...")
    test_prompt = "Respond with only the word 'ok'."
    response = connector.generate_text(prompt=test_prompt, temperature=0.0, max_output_tokens=5)

    # 4. Analyze the response
    if response and "text" in response and "ok" in response["text"].lower():
        print("\n✅ API HEALTH CHECK SUCCESSFUL")
        print("   - Successfully connected to the Gemini API.")
        print("   - Authentication is working.")
        print("   - You are currently under the API request quota.")
        return True
    
    if response and "error" in response:
        error_message = response["error"].lower()
        if "quota" in error_message or "429" in error_message:
            print("\n❌ API HEALTH CHECK FAILED: QUOTA EXCEEDED")
            print(f"   Reason: The API returned a quota-related error.")
            print(f"   Details: {response['error']}")
        else:
            print("\n❌ API HEALTH CHECK FAILED: GENERIC API ERROR")
            print(f"   Reason: The API returned an error that was not quota-related.")
            print(f"   Details: {response['error']}")
        return False

    print("\n❌ API HEALTH CHECK FAILED: UNKNOWN REASON")
    print("   Reason: The API did not return a valid response or an error.")
    print(f"   Raw Response: {response}")
    return False

if __name__ == "__main__":
    success = check_api_health()
    exit(0 if success else 1)