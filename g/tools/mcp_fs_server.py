#!/usr/bin/env python3
"""
MCP Filesystem Server for 02LUKA
Provides read/list operations over SSE transport for Cursor integration
"""
from mcp.server.fastmcp import FastMCP
from starlette.applications import Starlette
from starlette.routing import Route, Mount
from starlette.responses import JSONResponse
from pathlib import Path
import os

ROOT = Path(os.environ.get("FS_ROOT", ".")).resolve()

mcp = FastMCP("02luka-fs")

@mcp.tool()
def read_text(relpath: str) -> str:
    """Read text file from SOT path"""
    p = (ROOT / relpath).resolve()
    if not str(p).startswith(str(ROOT)):
        raise ValueError(f"Path outside root: {relpath}")
    if not p.is_file():
        raise ValueError(f"Not a file: {relpath}")

    data = p.read_bytes()
    # Fast-path check for obvious binary content (NUL bytes) to provide
    # a helpful error instead of a generic UnicodeDecodeError.
    if b"\x00" in data:
        raise ValueError("Binary files are not supported")

    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        # Some text files may not be UTF-8 encoded; surface a clear error so
        # the caller understands why the read failed.
        raise ValueError("File is not valid UTF-8 text")

@mcp.tool()
def list_dir(relpath: str = ".") -> list:
    """List directory contents"""
    p = (ROOT / relpath).resolve()
    if not str(p).startswith(str(ROOT)):
        raise ValueError(f"Path outside root: {relpath}")
    return sorted([f.name for f in p.iterdir()])

@mcp.tool()
def file_info(relpath: str) -> dict:
    """Get file/directory information"""
    p = (ROOT / relpath).resolve()
    if not str(p).startswith(str(ROOT)):
        raise ValueError(f"Path outside root: {relpath}")
    stat = p.stat()
    return {
        "path": str(p.relative_to(ROOT)),
        "size": stat.st_size,
        "is_file": p.is_file(),
        "is_dir": p.is_dir(),
        "modified": stat.st_mtime
    }

# Health check endpoint
async def health_check(request):
    """Health check endpoint for monitoring"""
    return JSONResponse({
        "status": "ok",
        "server": "mcp-fs",
        "root": str(ROOT),
        "tools": ["read_text", "list_dir", "file_info"]
    })

# Create app with health endpoint + MCP routes
app = Starlette(routes=[
    Route("/health", health_check),
    Mount("/", mcp.sse_app)
])

if __name__ == "__main__":
    import uvicorn
    print(f"Starting MCP FS server...")
    print(f"Root: {ROOT}")
    print(f"Listening on http://127.0.0.1:8765 (SSE transport)")
    uvicorn.run(app, host="127.0.0.1", port=8765, log_level="info")
