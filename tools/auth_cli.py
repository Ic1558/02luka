#!/usr/bin/env python3
"""
auth_cli.py - Command-line interface for AuthManager

Usage:
    python tools/auth_cli.py register <username> <password>
    python tools/auth_cli.py login <username> <password>
    python tools/auth_cli.py list
    python tools/auth_cli.py delete <username>
"""

import sys
import os
import argparse

# Add project root to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from core.auth import AuthManager


def main():
    parser = argparse.ArgumentParser(description="User authentication CLI")
    subparsers = parser.add_subparsers(dest="command", help="Available commands")

    # Register command
    register_parser = subparsers.add_parser("register", help="Register a new user")
    register_parser.add_argument("username", help="Username")
    register_parser.add_argument("password", help="Password")

    # Login command
    login_parser = subparsers.add_parser("login", help="Test user login")
    login_parser.add_argument("username", help="Username")
    login_parser.add_argument("password", help="Password")

    # List command
    subparsers.add_parser("list", help="List all users")

    # Delete command
    delete_parser = subparsers.add_parser("delete", help="Delete a user")
    delete_parser.add_argument("username", help="Username to delete")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    auth = AuthManager()

    if args.command == "register":
        if auth.register(args.username, args.password):
            print(f"✅ User '{args.username}' registered successfully")
        else:
            print(f"❌ User '{args.username}' already exists", file=sys.stderr)
            sys.exit(1)

    elif args.command == "login":
        if auth.login(args.username, args.password):
            print(f"✅ Access Granted for '{args.username}'")
        else:
            print(f"❌ Access Denied for '{args.username}'", file=sys.stderr)
            sys.exit(1)

    elif args.command == "list":
        users = auth.list_users()
        if users:
            print(f"📋 Registered users ({len(users)}):")
            for user in users:
                print(f"  - {user}")
        else:
            print("📋 No users registered")

    elif args.command == "delete":
        if auth.delete_user(args.username):
            print(f"✅ User '{args.username}' deleted successfully")
        else:
            print(f"❌ User '{args.username}' not found", file=sys.stderr)
            sys.exit(1)


if __name__ == "__main__":
    main()
