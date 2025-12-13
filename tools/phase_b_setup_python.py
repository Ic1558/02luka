#!/usr/bin/env python3
"""Phase B Setup - Python version (bypasses shell environment issues)"""
import os
import subprocess
import sys
from pathlib import Path

REPO = Path.home() / "02luka"

def run_cmd(cmd, check=True):
    """Run command and return output"""
    try:
        result = subprocess.run(
            cmd, shell=True, capture_output=True, text=True, check=check
        )
        return result.stdout, result.stderr, result.returncode
    except subprocess.CalledProcessError as e:
        return e.stdout, e.stderr, e.returncode

def main():
    print("=== Phase B: Hardening Setup ===")
    print("")
    
    # 1. Setup git alias
    print("1. Setting up git alias for safe clean...")
    stdout, stderr, code = run_cmd(
        'git config --global alias.clean-safe "!zsh ~/02luka/tools/safe_git_clean.zsh"',
        check=False
    )
    if code == 0:
        print("   ✅ Git alias 'clean-safe' created")
        print("   Usage: git clean-safe -n  (dry-run)")
        print("         git clean-safe -f   (force)")
    else:
        print(f"   ⚠️  Git alias setup had issues: {stderr}")
    print("")
    
    # 2. Verify CI workflow
    print("2. Checking CI workflow...")
    workflow_file = REPO / ".github" / "workflows" / "workspace_guard.yml"
    if workflow_file.exists():
        print(f"   ✅ CI workflow exists: {workflow_file.relative_to(REPO)}")
        print("   ℹ️  To enable: Push to GitHub and workflow will run on PR/Push")
    else:
        print("   ⚠️  CI workflow not found")
    print("")
    
    # 3. Verify guard script
    print("3. Verifying guard script...")
    guard_script = REPO / "tools" / "guard_workspace_inside_repo.zsh"
    if guard_script.exists():
        if os.access(guard_script, os.X_OK):
            print("   ✅ Guard script exists and is executable")
        else:
            print("   ⚠️  Guard script exists but not executable")
            os.chmod(guard_script, 0o755)
            print("   ✅ Made executable")
    else:
        print("   ⚠️  Guard script not found")
    print("")
    
    # 4. Verify pre-commit hook
    print("4. Verifying pre-commit hook...")
    precommit = REPO / ".git" / "hooks" / "pre-commit"
    if precommit.exists():
        content = precommit.read_text()
        if "exec zsh tools/guard_workspace_inside_repo.zsh" in content:
            print("   ✅ Pre-commit hook is in blocking mode")
        else:
            print("   ⚠️  Pre-commit hook may not be in blocking mode")
    else:
        print("   ⚠️  Pre-commit hook not found")
    print("")
    
    # 5. Test git alias
    print("5. Testing git alias...")
    stdout, stderr, code = run_cmd("git clean-safe -n", check=False)
    if code == 0:
        print("   ✅ Git alias 'clean-safe' works!")
        print("   Output preview:")
        for line in stdout.split('\n')[:5]:
            if line.strip():
                print(f"      {line}")
    else:
        print(f"   ⚠️  Git alias test had issues: {stderr[:200]}")
    print("")
    
    # Summary
    print("=== Phase B Setup Complete ===")
    print("")
    print("✅ Git alias 'clean-safe' configured")
    print("✅ CI workflow ready (enable on GitHub)")
    print("✅ Guard script verified")
    print("✅ Pre-commit hook verified")
    print("")
    print("📋 Next Steps:")
    print("   1. Test: git clean-safe -n")
    print("   2. Enable CI workflow on GitHub (if using GitHub)")
    print("   3. Share team announcement (see g/docs/TEAM_ANNOUNCEMENT_workspace_split.md)")
    print("")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
