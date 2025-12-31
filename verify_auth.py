#!/usr/bin/env python3
"""
Authentication System Verification Script
Tests core.auth functionality with comprehensive smoke tests.
"""

import os
import json
import sys
from pathlib import Path

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent))

from core.auth import AuthManager

def print_section(title):
    """Print formatted section header."""
    print(f"\n{'='*60}")
    print(f"  {title}")
    print('='*60)

def verify_auth_system():
    """Run comprehensive authentication smoke tests."""

    print_section("🔐 Authentication System Verification")

    # Clean slate: Remove existing test database
    test_db = "data/users.json"
    if os.path.exists(test_db):
        os.remove(test_db)
        print(f"🧹 Cleaned up existing database: {test_db}")

    # Initialize AuthManager
    auth = AuthManager(db_path=test_db)
    print(f"✅ AuthManager initialized (db_path: {test_db})")

    # Test 1: Register new user
    print_section("Test 1: Register New User 'test_boss'")
    username = "test_boss"
    password = "SecurePassword123!"

    result = auth.register(username, password)
    if result:
        print("✅ PASS: User registration successful")
    else:
        print("❌ FAIL: User registration failed")
        return False

    # Test 2: Login with correct credentials
    print_section("Test 2: Login with Correct Credentials")
    if auth.login(username, password):
        print("✅ PASS: Login successful with correct password")
    else:
        print("❌ FAIL: Login failed with correct password")
        return False

    # Test 3: Login with wrong password (should fail)
    print_section("Test 3: Login with Wrong Password (Expected Fail)")
    wrong_password = "WrongPassword456!"
    if not auth.login(username, wrong_password):
        print("✅ PASS: Login correctly rejected wrong password")
    else:
        print("❌ FAIL: Login accepted wrong password (security issue!)")
        return False

    # Test 4: Duplicate registration (should fail)
    print_section("Test 4: Duplicate Registration (Expected Fail)")
    if not auth.register(username, password):
        print("✅ PASS: Duplicate registration correctly rejected")
    else:
        print("❌ FAIL: Duplicate registration was allowed")
        return False

    # Test 5: Verify data/users.json structure
    print_section("Test 5: Verify data/users.json Structure")

    if not os.path.exists(test_db):
        print(f"❌ FAIL: Database file not created: {test_db}")
        return False

    print(f"✅ Database file exists: {test_db}")

    # Load and validate JSON structure
    try:
        with open(test_db, 'r') as f:
            data = json.load(f)

        print(f"✅ Valid JSON format")

        # Check structure
        if "users" not in data:
            print("❌ FAIL: Missing 'users' key in JSON")
            return False

        print(f"✅ 'users' key present")

        if username not in data["users"]:
            print(f"❌ FAIL: User '{username}' not found in database")
            return False

        print(f"✅ User '{username}' found in database")

        # Validate user record structure
        user_record = data["users"][username]
        required_fields = ["salt", "password_hash", "created_at"]

        for field in required_fields:
            if field not in user_record:
                print(f"❌ FAIL: Missing field '{field}' in user record")
                return False
            print(f"✅ Field '{field}' present")

        # Validate salt length (32 bytes = 64 hex chars)
        if len(user_record["salt"]) != 64:
            print(f"❌ FAIL: Salt length incorrect (expected 64 hex chars, got {len(user_record['salt'])})")
            return False

        print(f"✅ Salt length correct (64 hex chars = 32 bytes)")

        # Validate password_hash length (SHA256 = 32 bytes = 64 hex chars)
        if len(user_record["password_hash"]) != 64:
            print(f"❌ FAIL: Hash length incorrect (expected 64 hex chars, got {len(user_record['password_hash'])})")
            return False

        print(f"✅ Password hash length correct (64 hex chars)")

        # Show database contents (safe - passwords are hashed)
        print(f"\n📄 Database Contents:")
        print(json.dumps(data, indent=2))

    except json.JSONDecodeError as e:
        print(f"❌ FAIL: Invalid JSON format: {e}")
        return False
    except Exception as e:
        print(f"❌ FAIL: Unexpected error: {e}")
        return False

    return True

def main():
    """Main entry point."""
    try:
        success = verify_auth_system()

        print_section("📊 Test Summary")

        if success:
            print("🎉 All tests PASSED!")
            print("✅ Authentication system is working correctly")
            return 0
        else:
            print("💥 Some tests FAILED!")
            print("❌ Please review errors above")
            return 1

    except Exception as e:
        print(f"\n💥 Fatal error during testing: {e}")
        import traceback
        traceback.print_exc()
        return 1

if __name__ == "__main__":
    sys.exit(main())
