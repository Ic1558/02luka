# g/tools/gmx_cli.py
"""
GMX CLI Wrapper: Orchestrates GMX planning by calling the Gemini API directly
via GeminiConnector and dispatches the resulting plan as a Work Order.

Migrated from external `gemini` CLI to direct Python API to eliminate
launchd environment compatibility issues.
"""
from __future__ import annotations

import json
import os
import argparse
from typing import Dict, Any

from pathlib import Path
import sys

# --- Robust Path Setup (must come first for dotenv) ---
try:
    SCRIPT_DIR = Path(__file__).parent.resolve()
    # Assumes /g/tools/gmx_cli.py, so project root is 1 level up from 'g'
    PROJECT_ROOT = SCRIPT_DIR.parents[1]
except (IndexError, AttributeError) as e:
    print(f"FATAL: Could not derive project root. Error: {e}")
    sys.exit(1)

# --- Load .env before any other imports ---
try:
    from dotenv import load_dotenv
    # Load from project root .env file
    env_path = PROJECT_ROOT / ".env"
    if env_path.exists():
        load_dotenv(dotenv_path=env_path, override=True)
    else:
        # Fallback to .env.local if exists
        env_local_path = PROJECT_ROOT / ".env.local"
        if env_local_path.exists():
            load_dotenv(dotenv_path=env_local_path, override=True)
except ImportError:
    # dotenv not installed, rely on system environment
    pass

# --- Import project modules ---
try:
    sys.path.insert(0, str(PROJECT_ROOT))
    from bridge.tools.dispatch_to_bridge import dispatch_work_order
    from g.connectors.gemini_connector import GeminiConnector
except (ImportError, IndexError) as e:
    print(f"FATAL: Could not set up paths. Ensure script is in 'g/tools/'. Error: {e}", file=sys.stderr)
    sys.exit(1)


# --- CONFIGURATION ---
GMX_PROMPT_PATH = PROJECT_ROOT / "config" / "GMX_PINNED_PROMPT.md"
GMX_MODEL = os.environ.get("GMX_MODEL", "gemini-2.5-flash") 

def load_gmx_system_prompt() -> str:
    """Loads the mandatory system prompt for GMX mode from a robust path."""
    try:
        return GMX_PROMPT_PATH.read_text(encoding='utf-8')
    except FileNotFoundError:
        print(f"ERROR: GMX System Prompt not found at '{GMX_PROMPT_PATH}'")
        return ""

def run_gmx_mode(user_input: str) -> Dict[str, Any]:
    """
    Executes the user prompt in GMX mode using direct Python API via GeminiConnector.
    
    Migrated from external `gemini` CLI to direct API to eliminate launchd environment issues.
    """
    system_prompt = load_gmx_system_prompt()
    if not system_prompt:
        return {"status": "ERROR", "reason": "Failed to load GMX system prompt."}
    
    full_prompt = f"{system_prompt}\n\nUSER REQUEST: {user_input}"
    
    try:
        # Use existing GeminiConnector (eliminates CLI dependency)
        connector = GeminiConnector(model_name=GMX_MODEL)
        
        if not connector.is_available():
            return {"status": "ERROR", "reason": "Gemini connector not available. Check GEMINI_API_KEY environment variable."}
        
        # Request JSON response format directly from API
        response = connector.generate_text(
            full_prompt,
            temperature=0.3,  # Lower temperature for structured JSON output
            max_output_tokens=4096
        )
        
        if not response or "text" not in response:
            return {"status": "ERROR", "reason": "No response from Gemini API or response was blocked."}
        
        # Parse JSON directly (no two-step parsing needed - connector returns text directly)
        gmx_plan = json.loads(response["text"])
        return gmx_plan

    except json.JSONDecodeError as e:
        # Handle JSON parsing errors with context
        raw_text = response.get("text", "") if "response" in locals() else ""
        return {"status": "ERROR", "reason": f"Invalid JSON from Gemini API. Error: {e!r}. Raw text: {raw_text[:500]}..."}
    except Exception as e:
        return {"status": "ERROR", "reason": f"Gemini API error: {e!r}"}


# --- CLI Entry Point ---

def main():
    """Main function to parse arguments and run the GMX workflow."""
    parser = argparse.ArgumentParser(
        description="GMX CLI Wrapper: Orchestrates GMX planning and dispatches Work Orders."
    )
    parser.add_argument(
        "prompt", 
        type=str, 
        help="The natural language task to be converted into a GMX task_spec."
    )
    args = parser.parse_args()

    print(f"--- GMX: Running Planner Mode ({GMX_MODEL}) ---")
    gmx_output = run_gmx_mode(args.prompt)
    
    if gmx_output.get("status") == "ERROR":
        print(f"FATAL ERROR: {gmx_output.get('reason', 'Unknown error')}")
        sys.exit(1)

    # The GMX plan should contain a 'task_spec'
    task_spec = gmx_output.get("task_spec")
    if not task_spec or not isinstance(task_spec, dict):
        print("FATAL ERROR: GMX plan did not generate a valid 'task_spec' dictionary.")
        print("--- GMX Output ---")
        print(json.dumps(gmx_output, indent=2))
        print("--------------------")
        sys.exit(1)

    # Dispatch the valid task_spec
    try:
        wo_path = dispatch_work_order(task_spec, source='gmx_cli')
        print(f"\n✅ SUCCESS: Work Order Dispatched.")
        print(f"   File: {wo_path.name}")
        print(f"   Inbox: {wo_path.parent.name}")
        
    except Exception as e:
        print(f"\n🛑 DISPATCH FAILURE: Failed to create Work Order file.")
        print(f"   Reason: {e}")
        sys.exit(1)
if __name__ == "__main__":
    main()
