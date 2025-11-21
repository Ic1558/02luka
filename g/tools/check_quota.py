#!/usr/bin/env python3
# g/tools/check_quota.py
"""
Performs a live health check on the Gemini API to verify connectivity,
authentication, and quota availability.
"""
from __future__ import annotations
import sys
import os
import json
import argparse
from datetime import datetime
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

def check_api_health(json_out=None):
    """
    Performs a small, lightweight API call to check the health and quota status.
    
    Args:
        json_out: Optional path to write JSON status output
    
    Returns:
        tuple: (success: bool, status_data: dict)
    """
    print("--- Antigravity Quota & Health Check ---")

    status_data = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "status": "unknown",
        "error_code": None,
        "message": "",
        "model": "",
        "test_call_ok": False
    }

    # 1. Load environment from .env.local
    env_local_path = PROJECT_ROOT / ".env.local"
    if env_local_path.exists():
        load_dotenv(dotenv_path=env_local_path)
        print(f"✅ Loaded environment from: {env_local_path.name}")
    else:
        print(f"⚠️  Warning: .env.local not found. Relying on shell environment for GEMINI_API_KEY.")

    # 2. Initialize the connector
    # Use gemini-2.5-flash (known working model)
    model_to_test = os.environ.get("GMX_MODEL", "gemini-2.5-flash")
    status_data["model"] = model_to_test
    print(f"Initializing connector with model: {model_to_test}...")
    connector = GeminiConnector(model_name=model_to_test)

    if not connector.is_available():
        print("\n❌ API HEALTH CHECK FAILED")
        print("   Reason: Connector is not available.")
        print("   Troubleshooting:")
        print("   - Ensure 'google-generativeai' and 'python-dotenv' are installed in your venv.")
        print("   - Ensure GEMINI_API_KEY is set in your .env.local file or shell environment.")
        status_data["status"] = "error"
        status_data["message"] = "Connector not available"
        if json_out:
            Path(json_out).parent.mkdir(parents=True, exist_ok=True)
            Path(json_out).write_text(json.dumps(status_data, indent=2))
        return False, status_data

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
        status_data["status"] = "ok"
        status_data["message"] = "Connector healthy"
        status_data["test_call_ok"] = True
        if json_out:
            Path(json_out).parent.mkdir(parents=True, exist_ok=True)
            Path(json_out).write_text(json.dumps(status_data, indent=2))
        return True, status_data
    
    if response and "error" in response:
        error_message = response["error"].lower()
        if "quota" in error_message or "429" in error_message:
            print("\n❌ API HEALTH CHECK FAILED: QUOTA EXCEEDED")
            print(f"   Reason: The API returned a quota-related error.")
            print(f"   Details: {response['error']}")
            status_data["status"] = "error"
            status_data["error_code"] = "429"
            status_data["message"] = "Quota exceeded"
        elif "403" in error_message or "leaked" in error_message or "expired" in error_message:
            print("\n❌ API HEALTH CHECK FAILED: AUTH ERROR")
            print(f"   Reason: The API returned an authentication error.")
            print(f"   Details: {response['error']}")
            status_data["status"] = "error"
            status_data["error_code"] = "403"
            status_data["message"] = "Authentication failed (key leaked/expired)"
        else:
            print("\n❌ API HEALTH CHECK FAILED: GENERIC API ERROR")
            print(f"   Reason: The API returned an error that was not quota-related.")
            print(f"   Details: {response['error']}")
            status_data["status"] = "error"
            status_data["message"] = response.get("error", "Unknown error")
        if json_out:
            Path(json_out).parent.mkdir(parents=True, exist_ok=True)
            Path(json_out).write_text(json.dumps(status_data, indent=2))
        return False, status_data

    print("\n❌ API HEALTH CHECK FAILED: UNKNOWN REASON")
    print("   Reason: The API did not return a valid response or an error.")
    print(f"   Raw Response: {response}")
    status_data["status"] = "error"
    status_data["message"] = "Unknown error - no valid response"
    if json_out:
        Path(json_out).parent.mkdir(parents=True, exist_ok=True)
        Path(json_out).write_text(json.dumps(status_data, indent=2))
    return False, status_data

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Check Gemini API quota and health")
    parser.add_argument('--json-out', help='Write JSON status to file')
    args = parser.parse_args()
    
    success, _ = check_api_health(json_out=args.json_out)
    exit(0 if success else 1)