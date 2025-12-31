import os
import json
import hashlib
import secrets
import datetime
from typing import Dict, Optional

class AuthManager:
    """
    Manages user authentication using a local JSON file.
    Security: PBKDF2-HMAC-SHA256 with unique salts.
    """
    
    def __init__(self, db_path: str = "data/users.json"):
        self.db_path = db_path
        self._ensure_db()

    def _ensure_db(self):
        """Ensures the JSON database file exists."""
        if not os.path.exists(self.db_path):
            self._save_db({"users": {}})

    def _load_db(self) -> Dict:
        """Loads users from JSON."""
        try:
            with open(self.db_path, "r", encoding="utf-8") as f:
                return json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            return {"users": {}}

    def _save_db(self, data: Dict):
        """Saves users to JSON atomically (write-temp, move)."""
        temp_path = f"{self.db_path}.tmp"
        with open(temp_path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
        os.replace(temp_path, self.db_path)

    def _hash_password(self, password: str, salt: bytes) -> str:
        """Hashes password using PBKDF2."""
        # PBKDF2-HMAC-SHA256, 100,000 iterations
        # Good balance of security and performance for Python
        key = hashlib.pbkdf2_hmac(
            'sha256', 
            password.encode('utf-8'), 
            salt, 
            100000
        )
        return key.hex()

    def register(self, username: str, password: str, role: str = "user") -> bool:
        """
        Registers a new user. 
        Args:
            username: Unique username.
            password: Password to hash.
            role: 'user' (default) or 'admin'.
        Returns:
            True if successful.
        """
        data = self._load_db()
        users = data.get("users", {})

        if username in users:
            print(f"❌ Registration failed: User '{username}' already exists.")
            return False

        # Generate unique salt (32 bytes)
        salt = secrets.token_bytes(32)
        password_hash = self._hash_password(password, salt)

        users[username] = {
            "salt": salt.hex(),
            "password_hash": password_hash,
            "role": role,
            "created_at": datetime.datetime.now().isoformat()
        }

        data["users"] = users
        self._save_db(data)
        print(f"✅ User '{username}' registered with role '{role}'.")
        return True

    def get_role(self, username: str) -> Optional[str]:
        """Returns the role of the user, or None if not found."""
        data = self._load_db()
        user = data.get("users", {}).get(username)
        return user.get("role", "user") if user else None

    def promote_user(self, username: str, new_role: str) -> bool:
        """Promotes (or demotes) a user to a new role."""
        data = self._load_db()
        users = data.get("users", {})
        
        if username not in users:
            print(f"❌ User '{username}' not found.")
            return False
            
        users[username]["role"] = new_role
        data["users"] = users
        self._save_db(data)
        print(f"✅ User '{username}' promoted to '{new_role}'.")
        return True

    def login(self, username: str, password: str) -> bool:
        """Authenticates a user. Returns True if credentials match."""
        data = self._load_db()
        users = data.get("users", {})
        user_record = users.get(username)

        if not user_record:
            return False

        try:
            stored_salt = bytes.fromhex(user_record["salt"])
            stored_hash = user_record["password_hash"]
            
            # Hash input password with stored salt
            attempt_hash = self._hash_password(password, stored_salt)
            
            # Constant-time comparison to prevent timing attacks
            if secrets.compare_digest(attempt_hash, stored_hash):
                return True
        except Exception:
            # Handle malformed records gracefully
            return False

        return False
