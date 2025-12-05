#!/usr/bin/env python3
"""
Test suite for Opal Gateway API endpoints
Tests all endpoints including new wo_status and notify
"""

import requests
import json
from datetime import datetime, timezone
from pathlib import Path

# Configuration
BASE_URL = "http://localhost:5001"
RELAY_KEY = None  # Set if you have RELAY_KEY configured

# Test work order ID
TEST_WO_ID = "WO-TEST-STATUS-001"

def test_endpoint(name, method, endpoint, **kwargs):
    """Test a single endpoint"""
    print(f"\n{'='*60}")
    print(f"Testing: {name}")
    print(f"{'='*60}")
    
    url = f"{BASE_URL}{endpoint}"
    print(f"🔗 URL: {url}")
    print(f"📋 Method: {method}")
    
    try:
        if method == "GET":
            response = requests.get(url, **kwargs)
        elif method == "POST":
            response = requests.post(url, **kwargs)
        else:
            print(f"❌ Unsupported method: {method}")
            return False
        
        print(f"📊 Status: {response.status_code}")
        
        # Try to parse JSON
        try:
            data = response.json()
            print(f"📄 Response:")
            print(json.dumps(data, indent=2, ensure_ascii=False))
        except:
            print(f"📄 Response (text): {response.text[:200]}")
        
        # Check if successful
        if 200 <= response.status_code < 300:
            print(f"✅ Test PASSED")
            return True
        else:
            print(f"⚠️  Test returned non-2xx status")
            return False
            
    except requests.exceptions.ConnectionError:
        print(f"❌ Connection Error - Is the gateway running?")
        return False
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return False

def create_test_state_file():
    """Create a test state file for wo_status testing"""
    state_dir = Path.home() / "02luka" / "followup" / "state"
    state_dir.mkdir(parents=True, exist_ok=True)
    
    state_file = state_dir / f"{TEST_WO_ID}.json"
    state_data = {
        "status": "DEV_COMPLETED",
        "lane": "dev_oss",
        "app_mode": "expense",
        "priority": "high",
        "objective": "Test status check endpoint",
        "last_update": datetime.now(timezone.utc).isoformat(),
        "notify": {
            "enable": True,
            "telegram": {
                "enable": True,
                "channel": "boss_private"
            },
            "line": {
                "enable": False,
                "room": None
            }
        }
    }
    
    state_file.write_text(json.dumps(state_data, indent=2, ensure_ascii=False))
    print(f"\n✅ Created test state file: {state_file}")
    return state_file

def main():
    print("\n" + "="*60)
    print("🧪 02luka Opal Gateway - Full API Test Suite")
    print("="*60)
    
    results = []
    headers = {"Content-Type": "application/json"}
    if RELAY_KEY:
        headers["X-Relay-Key"] = RELAY_KEY
    
    # Test 1: Health check
    results.append(test_endpoint(
        "Root Health Check",
        "GET",
        "/"
    ))
    
    # Test 2: Ping
    results.append(test_endpoint(
        "Ping",
        "GET",
        "/ping"
    ))
    
    # Test 3: Stats
    results.append(test_endpoint(
        "Gateway Statistics",
        "GET",
        "/stats"
    ))
    
    # Test 4: Submit work order
    wo_payload = {
        "wo_id": "WO-TEST-API-001",
        "app_mode": "Expense",
        "objective": "Test complete API workflow",
        "priority": "medium",
        "lane": "dev_oss",
        "notify": {
            "telegram": True
        }
    }
    
    results.append(test_endpoint(
        "Submit Work Order",
        "POST",
        "/api/wo",
        headers=headers,
        json=wo_payload
    ))
    
    # Test 5: WO Status (create test state first)
    print(f"\n{'='*60}")
    print("Preparing WO Status Test")
    print(f"{'='*60}")
    create_test_state_file()
    
    results.append(test_endpoint(
        "Check Work Order Status",
        "POST",
        "/api/wo_status",
        headers=headers,
        json={"wo_id": TEST_WO_ID}
    ))
    
    # Test 6: Queue notification
    notify_payload = {
        "wo_id": "WO-TEST-NOTIFY-001",
        "telegram": {
            "chat": "boss_private",
            "text": "🧪 Test notification from gateway\n\nWO: WO-TEST-NOTIFY-001\nStatus: COMPLETED\nMode: expense",
            "meta": {
                "wo_id": "WO-TEST-NOTIFY-001",
                "lane": "dev_oss",
                "status": "COMPLETED"
            }
        },
        "line": None
    }
    
    results.append(test_endpoint(
        "Queue Notification",
        "POST",
        "/api/notify",
        headers=headers,
        json=notify_payload
    ))
    
    # Summary
    print("\n" + "="*60)
    print("📊 TEST SUMMARY")
    print("="*60)
    passed = sum(results)
    total = len(results)
    print(f"Passed: {passed}/{total}")
    
    if passed == total:
        print("✅ All tests passed!")
        print("\n🎯 Verification Steps:")
        print("1. Check bridge inbox: ls -la ~/02luka/bridge/inbox/LIAM/")
        print("2. Check notify queue: ls -la ~/02luka/bridge/inbox/NOTIFY/")
        print("3. Check state files: ls -la ~/02luka/followup/state/")
    else:
        print(f"⚠️  {total - passed} test(s) failed. Check output above.")
    
    print("="*60 + "\n")

if __name__ == "__main__":
    main()
