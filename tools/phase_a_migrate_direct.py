#!/usr/bin/env python3
"""Phase A: Direct migration using file operations"""
import os
import shutil
from pathlib import Path

REPO = Path("/Users/icmini/02luka")
WS = Path("/Users/icmini/02luka_ws")

def migrate_followup_json():
    """Migrate followup.json"""
    repo_file = REPO / "g/apps/dashboard/data/followup.json"
    ws_file = WS / "g/apps/dashboard/data/followup.json"
    
    print("=== Migrating followup.json ===")
    
    # Ensure workspace directory exists
    ws_file.parent.mkdir(parents=True, exist_ok=True)
    
    # If repo file exists and is real file (not symlink)
    if repo_file.exists() and not repo_file.is_symlink():
        print(f"  📦 Copying to workspace...")
        shutil.copy2(repo_file, ws_file)
        print(f"     ✓ Copied")
        # Remove real file
        print(f"  🗑️  Removing from repo...")
        repo_file.unlink()
    
    # Create symlink
    if not repo_file.exists() or not repo_file.is_symlink():
        if repo_file.exists():
            repo_file.unlink()
        print(f"  🔗 Creating symlink...")
        repo_file.parent.mkdir(parents=True, exist_ok=True)
        repo_file.symlink_to(ws_file)
        print(f"     ✓ Symlink created")
    
    # Verify
    if repo_file.is_symlink():
        target = repo_file.readlink()
        print(f"  ✅ {repo_file.relative_to(REPO)} -> {target}")
        return True
    return False

def create_symlink_if_missing(repo_path, ws_path, is_dir=True):
    """Create symlink if path doesn't exist or is not a symlink"""
    repo_full = REPO / repo_path
    ws_full = WS / ws_path
    
    print(f"\n=== Checking {repo_path} ===")
    
    if repo_full.exists():
        if repo_full.is_symlink():
            target = repo_full.readlink()
            print(f"  ✅ Already symlink -> {target}")
            return True
        else:
            print(f"  ❌ Real {'directory' if is_dir else 'file'} exists (should migrate)")
            # Migrate if has content
            if is_dir and any(repo_full.iterdir()):
                print(f"  📦 Migrating directory contents...")
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
                print(f"     ✓ Migrated")
            # Remove real path
            if is_dir:
                shutil.rmtree(repo_full)
            else:
                repo_full.unlink()
            print(f"  🗑️  Removed from repo")
    
    # Ensure workspace target exists
    if is_dir:
        ws_full.mkdir(parents=True, exist_ok=True)
    else:
        ws_full.parent.mkdir(parents=True, exist_ok=True)
        if not ws_full.exists():
            ws_full.touch()  # Create empty file
    
    # Create symlink
    if not repo_full.exists():
        print(f"  🔗 Creating symlink...")
        repo_full.parent.mkdir(parents=True, exist_ok=True)
        repo_full.symlink_to(ws_full)
        print(f"     ✓ Symlink created")
    
    # Verify
    if repo_full.is_symlink():
        target = repo_full.readlink()
        print(f"  ✅ {repo_path} -> {target}")
        return True
    return False

def main():
    print("=" * 60)
    print("Phase A: Direct Migration")
    print("=" * 60)
    print()
    
    all_ok = True
    
    # Migrate followup.json
    if not migrate_followup_json():
        all_ok = False
    
    # Create symlinks for directories
    paths = [
        ("g/followup", "g/followup", True),
        ("mls/ledger", "mls/ledger", True),
        ("bridge/processed", "bridge/processed", True),
    ]
    
    for repo_path, ws_path, is_dir in paths:
        if not create_symlink_if_missing(repo_path, ws_path, is_dir):
            all_ok = False
    
    print("\n" + "=" * 60)
    if all_ok:
        print("✅ Phase A Migration Complete!")
    else:
        print("⚠️  Some issues occurred (see above)")
    print("=" * 60)
    
    return 0 if all_ok else 1

if __name__ == "__main__":
    import sys
    sys.exit(main())
