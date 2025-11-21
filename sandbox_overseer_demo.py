#!/usr/bin/env python3
"""Demo script for GMX Policy Loader and Overseer integration"""
from __future__ import annotations

from governance.policy_loader import PolicyLoader
from governance.overseerd import decide_for_patch, decide_for_shell


def main() -> None:
    pl = PolicyLoader()
    print("Policy version:", pl.version)
    print("Policy loaded:", pl.policy is not None)

    print("\n=== PATCH TEST ===")
    patch_decision = decide_for_patch(
        {"task_spec": {}},
        {
            "changed_files": ["02luka/core/gg_orchestrator.py"],
            "diff_text": "update redis dispatcher logic and overseer routing",
        },
    )
    print("approval:", patch_decision["approval"])
    print("reason:", patch_decision["reason"])
    if "trigger_details" in patch_decision:
        print("trigger_details:", patch_decision["trigger_details"])

    print("\n=== SHELL TEST ===")
    shell_decision = decide_for_shell(
        {"command": "docker volume rm my_volume", "task_spec": {}}
    )
    print("approval:", shell_decision["approval"])
    print("reason:", shell_decision["reason"])
    if "trigger_details" in shell_decision:
        print("trigger_details:", shell_decision["trigger_details"])


if __name__ == "__main__":
    main()
