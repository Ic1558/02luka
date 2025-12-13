#!/usr/bin/env python3
"""
Phase A: Migrate workspace paths to symlinks
Direct file operations to avoid shell environment issues
"""
import os
import shutil
import sys
from pathlib import Path

REPO = Path.home() / "02luka"
WS = Path.home() / "02luka_ws"

paths_to_migrate = [
    ("g/followup", "g/followup", True),  # (repo_path, ws_path, is_dir)
    ("mls/ledger", "mls/ledger", True),
    ("bridge/processed", "bridge/processed", True),
    ("g/apps/dashboard/data/followup.json", "g/apps/dashboard/data/followup.json", False),
]

def is_symlink(path):
    """Check if path is a symlink"""
    return path.is_symlink()

def migrate_path(repo_path, ws_path, is_dir):
    """Migrate a path from repo to workspace and create symlink"""
    repo_full = REPO / repo_path
    ws_full = WS / ws_path
    
    print(f"\n=== Migrating {repo_path} ===")
    
    # Check current status
    if not repo_full.exists():
        print(f"  ℹ️  {repo_path} does not exist (will create symlink)")
    elif is_symlink(repo_full):
        target = repo_full.readlink()
        print(f"  ✅ {repo_path} is already a symlink -> {target}")
        if str(target).startswith(str(WS)):
            print(f"     ✓ Points to workspace (correct)")
            return True
        else:
            print(f"     ⚠️  Points to wrong location, will fix...")
    else:
        print(f"  ❌ {repo_path} is a real {'directory' if is_dir else 'file'} (needs migration)")
    
    # Create workspace target directory
    if is_dir:
        ws_full.parent.mkdir(parents=True, exist_ok=True)
    else:
        ws_full.parent.mkdir(parents=True, exist_ok=True)
    
    # Migrate data if exists
    if repo_full.exists() and not is_symlink(repo_full):
        if is_dir:
            if any(repo_full.iterdir()):
                print(f"  📦 Copying directory contents to {ws_full}...")
                ws_full.mkdir(parents=True, exist_ok=True)
                for item in repo_full.iterdir():
                    dest = ws_full / item.name
                    if item.is_dir():
                        if dest.exists():
                            shutil.copytree(item, dest, dirs_exist_ok=True)
                        else:
                            shutil.copytree(item, dest)
                    else:
                        shutil.copy2(item, dest)
                print(f"     ✓ Copied to workspace")
            else:
                print(f"  ℹ️  Directory is empty, creating empty workspace directory")
                ws_full.mkdir(parents=True, exist_ok=True)
            # Remove real directory
            print(f"  🗑️  Removing real directory from repo...")
            shutil.rmtree(repo_full)
        else:
            # File
            print(f"  📦 Copying file to {ws_full}...")
            shutil.copy2(repo_full, ws_full)
            print(f"     ✓ Copied to workspace")
            # Remove real file
            print(f"  🗑️  Removing real file from repo...")
            repo_full.unlink()
    
    # Create symlink
    print(f"  🔗 Creating symlink...")
    if repo_full.exists():
        repo_full.unlink()  # Remove if exists (shouldn't happen, but safety)
    
    repo_full.parent.mkdir(parents=True, exist_ok=True)
    repo_full.symlink_to(ws_full)
    
    # Verify
    if is_symlink(repo_full):
        target = repo_full.readlink()
        print(f"  ✅ Symlink created: {repo_path} -> {target}")
        if str(target) == str(ws_full):
            print(f"     ✓ Points to correct workspace location")
            return True
        else:
            print(f"     ⚠️  Points to unexpected location")
            return False
    else:
        print(f"  ❌ Failed to create symlink")
        return False

def main():
    print("=" * 60)
    print("Phase A: Migrate Workspace Paths to Symlinks")
    print("=" * 60)
    
    if not REPO.exists():
        print(f"❌ Repository not found: {REPO}")
        sys.exit(1)
    
    os.chdir(REPO)
    
    # Ensure workspace exists
    WS.mkdir(parents=True, exist_ok=True)
    print(f"\n📁 Workspace: {WS}")
    print(f"📁 Repository: {REPO}\n")
    
    all_ok = True
    for repo_path, ws_path, is_dir in paths_to_migrate:
        if not migrate_path(repo_path, ws_path, is_dir):
            all_ok = False
    
    print("\n" + "=" * 60)
    if all_ok:
        print("✅ All paths migrated successfully!")
    else:
        print("⚠️  Some paths had issues (see above)")
    print("=" * 60)
    
    return 0 if all_ok else 1

if __name__ == "__main__":
    sys.exit(main())
