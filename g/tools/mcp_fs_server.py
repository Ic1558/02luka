#!/usr/bin/env python3
"""
MCP Filesystem Server for 02LUKA
Provides read/list operations over SSE transport for Cursor integration
"""
from mcp.server.fastmcp import FastMCP
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
    return p.read_text(encoding="utf-8")

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

# Export SSE app for uvicorn
app = mcp.sse_app

if __name__ == "__main__":
    import uvicorn
    print(f"Starting MCP FS server...")
    print(f"Root: {ROOT}")
    print(f"Listening on http://127.0.0.1:8765 (SSE transport)")
    uvicorn.run(app, host="127.0.0.1", port=8765, log_level="info")
