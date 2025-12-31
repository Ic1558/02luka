# Authentication System Plan (Implemented)

This document describes the JSON-based User Authentication system running in `core/auth/`.

## 1. Overview
A lightweight, zero-dependency authentication module designed for single-node Python applications. It avoids the complexity of SQL databases by using a secured JSON store.

- **Module**: `core.auth`
- **Storage**: `data/users.json`
- **Hashing**: PBKDF2-HMAC-SHA256 (Standard Library)

## 2. Data Structure (`data/users.json`)
The database is a simple dictionary keyed by username.

```json
{
  "users": {
    "username": {
      "salt": "hex_encoded_32_byte_salt",
      "password_hash": "hex_encoded_hash_output",
      "created_at": "2025-12-30T02:00:00.000000"
    }
  }
}
```

## 3. Class Design

### `AuthManager`
Located in: [`core/auth/manager.py`](file:///Users/icmini/02luka/core/auth/manager.py)

| Method | Signature | Description |
| :--- | :--- | :--- |
| `register` | `(username, password) -> bool` | Generates a specific salt, hashes password, saves to JSON. Returns `False` if user exists. |
| `login` | `(username, password) -> bool` | Loads salt, re-hashes input, creates constant-time comparison. |
| `_hash_password` | `(password, salt) -> str` | Internal. Uses `hashlib.pbkdf2_hmac` (100k iterations). |

## 4. Usage Example

```python
from core.auth import AuthManager

auth = AuthManager()

# Register
if auth.register("boss", "secret"):
    print("User created")

# Login
if auth.login("boss", "secret"):
    print("Access Granted")
else:
    print("Access Denied")
```

## 5. Security Notes
- **Salt Uniqueness**: Every user gets a unique 32-byte random salt.
- **Algorithm**: standard `sha256` prevents collision attacks better than md5/sha1.
- **Iterations**: 100,000 rounds make brute-force usage expensive.
