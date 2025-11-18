#!/usr/bin/env python3
"""
Gemini API Health Check
Phase 1.5 - Testing & Verification

Purpose: Quick health check for Gemini API availability
Usage: python3 gemini_health_check.py
Protocol: v3.2 compliant
Created: 2025-11-18
"""

import os
import sys
import logging
from pathlib import Path

# Add connector path
sys.path.insert(0, str(Path(__file__).parent))

try:
    from gemini_connector import GeminiConnector
except ImportError:
    print("❌ Cannot import gemini_connector")
    sys.exit(1)

logging.basicConfig(level=logging.WARNING)  # Suppress INFO logs


def health_check() -> dict:
    """
    Run comprehensive health check.

    Returns:
        dict with check results
    """
    results = {
        "overall": False,
        "checks": {}
    }

    # Check 1: API key present
    api_key = os.getenv("GEMINI_API_KEY")
    results["checks"]["api_key"] = {
        "status": bool(api_key),
        "message": "✅ API key configured" if api_key else "❌ API key missing"
    }

    if not api_key:
        return results

    # Check 2: Connector initialization
    try:
        connector = GeminiConnector()
        available = connector.is_available()
        results["checks"]["initialization"] = {
            "status": available,
            "message": f"✅ Connector initialized ({connector.model_name})" if available else "❌ Initialization failed"
        }

        if not available:
            return results

    except Exception as e:
        results["checks"]["initialization"] = {
            "status": False,
            "message": f"❌ Initialization error: {e}"
        }
        return results

    # Check 3: Simple API call
    try:
        test_result = connector.generate_text(
            prompt="Hello! Please respond with a brief confirmation that you are working correctly.",
            temperature=0.0,
            max_output_tokens=50
        )

        if test_result and test_result.get('text'):
            results["checks"]["api_call"] = {
                "status": True,
                "message": f"✅ API call successful",
                "response": test_result['text'][:50]
            }
        else:
            results["checks"]["api_call"] = {
                "status": False,
                "message": "❌ API call returned no result"
            }
            return results

    except Exception as e:
        results["checks"]["api_call"] = {
            "status": False,
            "message": f"❌ API call failed: {e}"
        }
        return results

    # Check 4: Model availability
    results["checks"]["model"] = {
        "status": True,
        "message": f"✅ Model available: {connector.model_name}"
    }

    # Overall status
    results["overall"] = all(
        check["status"] for check in results["checks"].values()
    )

    return results


def main():
    """Main entry point."""
    print("╔═══════════════════════════════════════════════╗")
    print("║  Gemini API Health Check                     ║")
    print("╚═══════════════════════════════════════════════╝\n")

    results = health_check()

    # Print results
    for check_name, check_data in results["checks"].items():
        print(f"{check_data['message']}")
        if "response" in check_data:
            print(f"   Response: {check_data['response']}")

    print()

    if results["overall"]:
        print("═══════════════════════════════════════════════")
        print("✅ ALL CHECKS PASSED - Gemini API ready")
        print("═══════════════════════════════════════════════")
        return 0
    else:
        print("═══════════════════════════════════════════════")
        print("❌ HEALTH CHECK FAILED")
        print("═══════════════════════════════════════════════")
        return 1


if __name__ == "__main__":
    sys.exit(main())
