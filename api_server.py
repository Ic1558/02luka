#!/usr/bin/env python3
"""
FastAPI Authentication Server
Provides REST API endpoints for user registration and login.
"""

from fastapi import FastAPI, HTTPException, status
from pydantic import BaseModel, Field, validator
from typing import Dict
import uvicorn

# Import our existing auth system
from core.auth import AuthManager

# Initialize FastAPI app
app = FastAPI(
    title="Authentication API",
    description="JSON-based user authentication system",
    version="1.0.0"
)

# Initialize AuthManager
auth_manager = AuthManager(db_path="data/users.json")


# ============================================================================
# Pydantic Models (Request/Response Validation)
# ============================================================================

class UserCredentials(BaseModel):
    """Request model for authentication operations."""
    username: str = Field(..., min_length=3, max_length=50, description="Username (3-50 characters)")
    password: str = Field(..., min_length=8, description="Password (minimum 8 characters)")

    @validator('username')
    def validate_username(cls, v):
        """Ensure username contains only alphanumeric and underscore."""
        if not v.replace('_', '').isalnum():
            raise ValueError('Username must contain only letters, numbers, and underscores')
        return v

    class Config:
        schema_extra = {
            "example": {
                "username": "boss_user",
                "password": "SecurePassword123!"
            }
        }


class SuccessResponse(BaseModel):
    """Standard success response."""
    success: bool
    message: str
    username: str = None

    class Config:
        schema_extra = {
            "example": {
                "success": True,
                "message": "Operation successful",
                "username": "boss_user"
            }
        }


class ErrorResponse(BaseModel):
    """Standard error response."""
    success: bool = False
    error: str

    class Config:
        schema_extra = {
            "example": {
                "success": False,
                "error": "Invalid credentials"
            }
        }


# ============================================================================
# API Endpoints
# ============================================================================

@app.get("/", tags=["Root"])
async def root() -> Dict[str, str]:
    """API health check endpoint."""
    return {
        "status": "online",
        "service": "Authentication API",
        "version": "1.0.0",
        "endpoints": {
            "register": "POST /register",
            "login": "POST /login",
            "docs": "GET /docs"
        }
    }


@app.post(
    "/register",
    response_model=SuccessResponse,
    status_code=status.HTTP_201_CREATED,
    tags=["Authentication"],
    summary="Register a new user",
    responses={
        201: {"description": "User registered successfully"},
        400: {"model": ErrorResponse, "description": "User already exists"},
        422: {"description": "Validation error"}
    }
)
async def register(credentials: UserCredentials) -> SuccessResponse:
    """
    Register a new user account.

    - **username**: Unique username (3-50 chars, alphanumeric + underscore)
    - **password**: Secure password (minimum 8 characters)

    Returns success message if registration is successful.
    Raises 400 error if username already exists.
    """
    success = auth_manager.register(
        username=credentials.username,
        password=credentials.password
    )

    if not success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"User '{credentials.username}' already exists"
        )

    return SuccessResponse(
        success=True,
        message="User registered successfully",
        username=credentials.username
    )


@app.post(
    "/login",
    response_model=SuccessResponse,
    status_code=status.HTTP_200_OK,
    tags=["Authentication"],
    summary="Authenticate user login",
    responses={
        200: {"description": "Login successful"},
        401: {"model": ErrorResponse, "description": "Invalid credentials"},
        422: {"description": "Validation error"}
    }
)
async def login(credentials: UserCredentials) -> SuccessResponse:
    """
    Authenticate a user with username and password.

    - **username**: Registered username
    - **password**: User's password

    Returns success message if credentials are valid.
    Raises 401 error if credentials are invalid.
    """
    success = auth_manager.login(
        username=credentials.username,
        password=credentials.password
    )

    if not success:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password"
        )

    return SuccessResponse(
        success=True,
        message="Login successful",
        username=credentials.username
    )


# ============================================================================
# Server Entry Point
# ============================================================================

if __name__ == "__main__":
    print("=" * 70)
    print("🚀 Authentication API Server")
    print("=" * 70)
    print()
    print("📚 API Documentation: http://localhost:8000/docs")
    print("🔍 Alternative Docs:  http://localhost:8000/redoc")
    print("💡 Health Check:      http://localhost:8000/")
    print()
    print("=" * 70)
    print()

    uvicorn.run(
        "api_server:app",
        host="0.0.0.0",
        port=8000,
        reload=True,  # Auto-reload on code changes
        log_level="info"
    )
