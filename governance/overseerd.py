# 02luka V4 - Overseer Core
# ใช้ได้ทั้งกับ patch / shell / ui action
# ยังไม่ผูกกับระบบจริง แต่ interface ชัดพอให้ Cursor/Agent เอาไปต่อยอด

from __future__ import annotations

import os
import re
from typing import Any, Dict

from .policy_loader import PolicyLoader, load_safe_zones

_POLICY = PolicyLoader()  # lazy enoughสำหรับ v1


def _normalize_path(path: str) -> str:
    return os.path.abspath(os.path.expanduser(path))


def _is_path_allowed(path: str) -> bool:
    """Check if path is in allowed write zones."""
    zones = load_safe_zones()
    ap = _normalize_path(path)

    # Check allowed first (more specific paths should win)
    for allow in zones.write_allowed:
        if ap == allow or ap.startswith(allow + os.sep):
            # Now check if it's also in denied (denied takes precedence if more specific)
            for d in zones.write_denied:
                # Only deny if path is exactly denied path or direct child
                # This prevents /Users from blocking /Users/icmini/02luka
                if ap == d:
                    return False
                # Deny if path starts with denied + separator (but allow if it's under an allowed path that's more specific)
                if ap.startswith(d + os.sep):
                    # Check if there's an allowed path that's more specific than the denied one
                    denied_len = len(d)
                    has_more_specific_allowed = False
                    for a in zones.write_allowed:
                        if len(a) > denied_len and ap.startswith(a + os.sep):
                            has_more_specific_allowed = True
                            break
                    if not has_more_specific_allowed:
                        return False
            return True

    return False


def decide_for_patch(task_meta: dict, patch_meta: dict) -> dict:
    """
    task_meta: {"task_spec": {...}, ...}
    patch_meta: {"changed_files": [...], "diff_text": "...", ...}
    """
    files = patch_meta.get("changed_files", [])
    diff_text = patch_meta.get("diff_text", "")

    # Zone check first
    for f in files:
        fullpath = os.path.join(load_safe_zones().root_project, f)
        if not _is_path_allowed(fullpath):
            return {
                "approval": "No",
                "confidence_score": 0.95,
                "reason": f"File {f} is outside allowed write zones.",
                "used_advisor": "Rule-Based",
            }

    # Check if GM should be triggered
    trigger_gm = _POLICY.should_trigger_for_patch(files, diff_text)

    # Build trigger details
    trigger_details = []
    if trigger_gm:
        policy = _POLICY.policy
        if policy:
            if len(files) >= policy.files_changed_threshold:
                trigger_details.append(f"multi-file ({len(files)} >= {policy.files_changed_threshold})")
            for f in files:
                for sp in policy.sensitive_paths:
                    if sp in f:
                        trigger_details.append(f"sensitive-path ({sp} in {f})")
                        break
            for f in files:
                for ext in policy.file_extensions:
                    if f.endswith(ext):
                        trigger_details.append(f"extension ({ext})")
                        break
            diff_lower = diff_text.lower()
            for kw in policy.critical_keywords:
                if kw.lower() in diff_lower:
                    trigger_details.append(f"keyword ({kw})")
                    break

    return {
        "approval": "Yes" if not trigger_gm else "Review",
        "confidence_score": 1.0 if not trigger_gm else 0.6,
        "reason": "No GM trigger conditions met."
        if not trigger_gm
        else "GM trigger policy matched; require advisor / manual review.",
        "used_advisor": "Rule-Based",
        "trigger_details": trigger_details if trigger_gm else [],
    }


def decide_for_shell(task_meta: dict) -> dict:
    """
    task_meta: {"command": "...", "task_spec": {...}, ...}
    """
    cmd = task_meta.get("command") or ""

    # Hard-block dangerous patterns
    if "rm -rf /" in cmd or re.search(r"rm\s+-rf\s+/\b", cmd):
        return {
            "approval": "No",
            "confidence_score": 1.0,
            "reason": "Dangerous command detected: rm -rf /",
            "used_advisor": "Rule-Based",
        }

    # Check if GM should be triggered
    trigger_gm = _POLICY.should_trigger_for_shell(cmd)

    # Build trigger details
    trigger_details = []
    if trigger_gm:
        policy = _POLICY.policy
        if policy:
            cmd_lower = cmd.lower()
            for kw in policy.shell_keywords:
                if kw.lower() in cmd_lower:
                    trigger_details.append(f"shell-keyword ({kw})")
                    break

    return {
        "approval": "Yes" if not trigger_gm else "Review",
        "confidence_score": 1.0 if not trigger_gm else 0.6,
        "reason": "Shell command passed local policy."
        if not trigger_gm
        else "Shell command matches GM trigger policy.",
        "used_advisor": "Rule-Based",
        "trigger_details": trigger_details if trigger_gm else [],
    }


def decide_for_ui_action(task_meta: dict) -> dict:
    """
    task_meta: {"ui_action": {...}, "task_spec": {...}, ...}
    """
    action = task_meta.get("ui_action") or {}
    action_type = action.get("type")
    selector = (action.get("selector") or "").lower()

    # Very conservative keywords
    if action_type == "click" and any(
        kw in selector for kw in ("delete", "remove", "unsubscribe", "cancel")
    ):
        return {
            "approval": "Review",
            "confidence_score": 0.5,
            "reason": f"UI click on potentially destructive element: {selector}",
            "used_advisor": "Rule-Based",
        }

    return {
        "approval": "Yes",
        "confidence_score": 0.8,
        "reason": "UI action passed basic rule checks.",
        "used_advisor": "Rule-Based",
    }
