#!/usr/bin/env python3
import sys
import os

# Ensure we can import from core
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from core.auth import AuthManager

def main():
    manager = AuthManager()

    if len(sys.argv) < 2:
        print("Usage: python3 auth_cli.py [register|login] <username> <password>")
        return

    command = sys.argv[1]

    if command == "register":
        if len(sys.argv) != 4:
            print("Usage: register <username> <password>")
            return
        manager.register(sys.argv[2], sys.argv[3])

    elif command == "login":
        if len(sys.argv) != 4:
            print("Usage: login <username> <password>")
            return
        success = manager.login(sys.argv[2], sys.argv[3])
        if success:
            print(f"✅ Login SUCCESS for user '{sys.argv[2]}'")
            sys.exit(0)
        else:
            print(f"❌ Login FAILED for user '{sys.argv[2]}'")
            sys.exit(1)
            
    else:
        print(f"Unknown command: {command}")

if __name__ == "__main__":
    main()
