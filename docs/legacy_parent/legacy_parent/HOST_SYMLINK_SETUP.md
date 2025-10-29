# Host Symlink Setup for macOS

This guide explains how to create a symlink on your macOS host to maintain compatibility with legacy scripts and documentation that reference `~/dev/02luka-repo`.

## Overview

- **Canonical location**: `/workspaces/02luka-repo` (inside devcontainer)
- **Optional symlink**: `~/dev/02luka-repo` (on macOS host)
- **Purpose**: Legacy compatibility for scripts/docs that expect the old path

## Quick Setup

### Option 1: If you have the actual checkout on macOS

```bash
# Find your actual 02luka-repo directory
find ~ -name "02luka-repo" -type d 2>/dev/null | head -1

# Create symlink (replace /path/to/actual with the result above)
ln -snf /path/to/actual/02luka-repo ~/dev/02luka-repo
```

### Option 2: If using devcontainer only

```bash
# Create the symlink pointing to your devcontainer workspace
# (Adjust the path based on your devcontainer setup)
ln -snf /Users/icmini/dev/02luka-repo ~/dev/02luka-repo
```

### Option 3: One-liner for current Cursor workspace

```bash
# Run this in your macOS terminal while Cursor has the project open
ln -snf "$(pwd)" ~/dev/02luka-repo
```

## Verification

```bash
# Check the symlink was created correctly
ls -la ~/dev/02luka-repo

# Should show something like:
# lrwxr-xr-x  1 user  staff  45 Oct 11 10:00 /Users/user/dev/02luka-repo -> /path/to/actual/02luka-repo
```

## When to Use

- **Required**: If you have LaunchAgents or scripts that reference `~/dev/02luka-repo`
- **Optional**: For general development (all new scripts use dynamic path resolution)
- **Not needed**: If you only work inside the devcontainer

## Troubleshooting

### Symlink points to wrong location
```bash
# Remove and recreate
rm ~/dev/02luka-repo
ln -snf /correct/path/to/02luka-repo ~/dev/02luka-repo
```

### Permission denied
```bash
# Ensure the target directory exists and is accessible
ls -la /path/to/target/02luka-repo
```

### Scripts still can't find files
- Check that the symlink target contains the expected files (`.codex/`, `g/`, etc.)
- Verify the target is the same repository as your current workspace

## Notes

- This symlink is **optional** - the repository works fine without it
- All new scripts use `scripts/repo_root_resolver.sh` for dynamic path resolution
- The symlink is only needed for legacy compatibility
- You can safely remove it if no scripts require it
