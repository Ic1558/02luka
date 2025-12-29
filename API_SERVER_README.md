# FastAPI Authentication Server

## Quick Start

### 1. Install Dependencies

```bash
pip install fastapi uvicorn pydantic
```

Or using requirements.txt:
```bash
pip install -r requirements.txt
```

### 2. Run the Server

**Method 1: Using the script directly**
```bash
python3 api_server.py
```

**Method 2: Using uvicorn command**
```bash
uvicorn api_server:app --reload --host 0.0.0.0 --port 8000
```

### 3. Access the API

- **Interactive Docs**: http://localhost:8000/docs
- **Alternative Docs**: http://localhost:8000/redoc
- **Health Check**: http://localhost:8000/

## API Endpoints

### POST /register
Register a new user.

**Request:**
```json
{
  "username": "boss_user",
  "password": "SecurePassword123!"
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "message": "User registered successfully",
  "username": "boss_user"
}
```

**Error (400 Bad Request):**
```json
{
  "success": false,
  "error": "User 'boss_user' already exists"
}
```

### POST /login
Authenticate a user.

**Request:**
```json
{
  "username": "boss_user",
  "password": "SecurePassword123!"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Login successful",
  "username": "boss_user"
}
```

**Error (401 Unauthorized):**
```json
{
  "success": false,
  "error": "Invalid username or password"
}
```

## Testing with curl

**Register a user:**
```bash
curl -X POST http://localhost:8000/register \
  -H "Content-Type: application/json" \
  -d '{"username": "test_user", "password": "MyPassword123!"}'
```

**Login:**
```bash
curl -X POST http://localhost:8000/login \
  -H "Content-Type: application/json" \
  -d '{"username": "test_user", "password": "MyPassword123!"}'
```

## Validation Rules

### Username
- Length: 3-50 characters
- Allowed: Letters, numbers, underscore (_)
- Case-sensitive

### Password
- Minimum length: 8 characters
- No maximum length
- Recommended: Use mix of letters, numbers, special characters

## Security Features

- ✅ PBKDF2-HMAC-SHA256 password hashing
- ✅ Unique salt per user (32 bytes)
- ✅ 100,000 hash iterations
- ✅ Constant-time password comparison
- ✅ Input validation via Pydantic
- ✅ HTTP status codes (201, 400, 401)
- ✅ Atomic database writes

## Architecture

```
api_server.py (FastAPI)
    ↓
core/auth/manager.py (AuthManager)
    ↓
data/users.json (JSON Database)
```
