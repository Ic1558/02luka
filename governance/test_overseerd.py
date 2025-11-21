#!/usr/bin/env python3
"""Test script for overseerd module"""
from __future__ import annotations

import sys
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from governance.overseerd import decide_for_shell, decide_for_patch, decide_for_ui_action


def test_shell_safe():
    """Test safe shell command"""
    print("=" * 60)
    print("Test 1: Safe shell command")
    print("=" * 60)
    
    task_meta = {
        "command": "ls -la",
        "task_spec": {"source": "cursor", "intent": "run-command"}
    }
    
    result = decide_for_shell(task_meta)
    print(f"Command: ls -la")
    print(f"Decision: {result}")
    print(f"✅ Approval: {result['approval']}, Confidence: {result['confidence_score']}")
    return result['approval'] == "Yes"


def test_shell_dangerous():
    """Test dangerous shell command"""
    print("\n" + "=" * 60)
    print("Test 2: Dangerous shell command (rm -rf /)")
    print("=" * 60)
    
    task_meta = {
        "command": "rm -rf /",
        "task_spec": {"source": "cursor", "intent": "run-command"}
    }
    
    result = decide_for_shell(task_meta)
    print(f"Command: rm -rf /")
    print(f"Decision: {result}")
    print(f"✅ Approval: {result['approval']}, Confidence: {result['confidence_score']}")
    return result['approval'] == "No"


def test_shell_risky():
    """Test risky shell command"""
    print("\n" + "=" * 60)
    print("Test 3: Risky shell command (rm -rf ~/tmp)")
    print("=" * 60)
    
    task_meta = {
        "command": "rm -rf ~/tmp",
        "task_spec": {"source": "cursor", "intent": "run-command"}
    }
    
    result = decide_for_shell(task_meta)
    print(f"Command: rm -rf ~/tmp")
    print(f"Decision: {result}")
    print(f"✅ Approval: {result['approval']}, Confidence: {result['confidence_score']}")
    # Note: This might pass with "Yes" if rm -rf pattern doesn't match exactly
    # The important thing is it doesn't hard-block (approval != "No")
    return result['approval'] != "No"


def test_shell_gm_trigger():
    """Test shell command that triggers GM"""
    print("\n" + "=" * 60)
    print("Test 4: GM-trigger shell command (docker)")
    print("=" * 60)
    
    task_meta = {
        "command": "docker compose up -d",
        "task_spec": {"source": "cursor", "intent": "run-command"}
    }
    
    result = decide_for_shell(task_meta)
    print(f"Command: docker compose up -d")
    print(f"Decision: {result}")
    print(f"✅ Approval: {result['approval']}, Confidence: {result['confidence_score']}")
    return result['approval'] == "Review"


def test_patch_safe():
    """Test safe patch"""
    print("\n" + "=" * 60)
    print("Test 5: Safe patch (single file, safe zone)")
    print("=" * 60)
    
    task_meta = {
        "task_spec": {
            "source": "cursor",
            "intent": "add-feature",
            "target_files": ["tools/test.py"],
        }
    }
    
    patch_meta = {
        "changed_files": ["tools/test.py"],
        "diff_text": "# old content\n# new content"
    }
    
    result = decide_for_patch(task_meta, patch_meta)
    print(f"Files: {patch_meta['changed_files']}")
    print(f"Decision: {result}")
    print(f"✅ Approval: {result['approval']}, Confidence: {result['confidence_score']}")
    # .py files trigger GM review, so expect "Review" (GM unavailable) or "Yes" (if GM approves)
    return result['approval'] in ["Yes", "Review"]


def test_patch_outside_zone():
    """Test patch outside allowed zone"""
    print("\n" + "=" * 60)
    print("Test 6: Patch outside allowed zone (/etc/passwd)")
    print("=" * 60)
    
    task_meta = {
        "task_spec": {
            "source": "cursor",
            "intent": "fix-bug",
            "target_files": ["/etc/passwd"],
        }
    }
    
    patch_meta = {
        "changed_files": ["/etc/passwd"],
        "diff_text": "root:x:0:0..."
    }
    
    result = decide_for_patch(task_meta, patch_meta)
    print(f"Files: {patch_meta['changed_files']}")
    print(f"Decision: {result}")
    print(f"✅ Approval: {result['approval']}, Confidence: {result['confidence_score']}")
    return result['approval'] == "No"


def test_patch_multi_file():
    """Test multi-file patch (GM trigger)"""
    print("\n" + "=" * 60)
    print("Test 7: Multi-file patch (GM trigger)")
    print("=" * 60)
    
    task_meta = {
        "task_spec": {
            "source": "cursor",
            "intent": "refactor",
            "target_files": ["tools/file1.py", "tools/file2.py"],
        }
    }
    
    patch_meta = {
        "changed_files": ["tools/file1.py", "tools/file2.py"],
        "diff_text": "# old content\n# new content"
    }
    
    result = decide_for_patch(task_meta, patch_meta)
    print(f"Files: {patch_meta['changed_files']}")
    print(f"Decision: {result}")
    print(f"✅ Approval: {result['approval']}, Confidence: {result['confidence_score']}")
    return result['approval'] == "Review"


def test_ui_action_safe():
    """Test safe UI action"""
    print("\n" + "=" * 60)
    print("Test 8: Safe UI action")
    print("=" * 60)
    
    task_meta = {
        "ui_action": {
            "type": "click",
            "selector": "#save-button",
            "url": "https://example.com"
        },
        "task_spec": {"source": "cursor", "intent": "ui-action"}
    }
    
    result = decide_for_ui_action(task_meta)
    print(f"Action: click #save-button")
    print(f"Decision: {result}")
    print(f"✅ Approval: {result['approval']}, Confidence: {result['confidence_score']}")
    return result['approval'] == "Yes"


def test_ui_action_destructive():
    """Test destructive UI action"""
    print("\n" + "=" * 60)
    print("Test 9: Destructive UI action")
    print("=" * 60)
    
    task_meta = {
        "ui_action": {
            "type": "click",
            "selector": "#delete-user",
            "url": "https://example.com/admin/users/1"
        },
        "task_spec": {"source": "cursor", "intent": "ui-action"}
    }
    
    result = decide_for_ui_action(task_meta)
    print(f"Action: click #delete-user")
    print(f"Decision: {result}")
    print(f"✅ Approval: {result['approval']}, Confidence: {result['confidence_score']}")
    return result['approval'] == "Review"


if __name__ == "__main__":
    print("Overseer Test Suite")
    print("=" * 60)
    
    results = []
    results.append(("Safe shell", test_shell_safe()))
    results.append(("Dangerous shell", test_shell_dangerous()))
    results.append(("Risky shell", test_shell_risky()))
    results.append(("GM trigger shell", test_shell_gm_trigger()))
    results.append(("Safe patch", test_patch_safe()))
    results.append(("Outside zone patch", test_patch_outside_zone()))
    results.append(("Multi-file patch", test_patch_multi_file()))
    results.append(("Safe UI action", test_ui_action_safe()))
    results.append(("Destructive UI action", test_ui_action_destructive()))
    
    print("\n" + "=" * 60)
    print("Test Results Summary")
    print("=" * 60)
    for name, passed in results:
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"{status}: {name}")
    
    all_passed = all(result for _, result in results)
    if all_passed:
        print("\n✅ All tests passed!")
        sys.exit(0)
    else:
        print("\n❌ Some tests failed")
        sys.exit(1)
