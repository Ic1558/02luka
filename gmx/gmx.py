#!/usr/bin/env python3
# gmx/gmx.py
"""
Main entry point for the GMX CLI v2.
"""
import argparse
import sys
from pathlib import Path

# Add project root to path to allow for module imports
try:
    PROJECT_ROOT = Path(__file__).parent.resolve().parent
    sys.path.insert(0, str(PROJECT_ROOT))
    from gmx.commands import plan, build_patch, run
except ImportError as e:
    print(f"FATAL: Could not set up paths. Run from project root. Error: {e}", file=sys.stderr)
    sys.exit(1)

def main():
    """Parses CLI arguments and calls the appropriate subcommand."""
    parser = argparse.ArgumentParser(description="GMX CLI v2 - 02luka Planner")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # 'plan' command
    plan_parser = subparsers.add_parser("plan", help="Generate a GMX plan from a natural language prompt.")
    plan_parser.add_argument("prompt", type=str, help="The planning prompt.")

    # 'build-patch' command
    patch_parser = subparsers.add_parser("build-patch", help="Build a unified patch from the latest GMX plan.")

    # 'run' command
    run_parser = subparsers.add_parser("run", help="Dispatch the latest GMX plan as a Work Order to the Bridge.")

    args = parser.parse_args()

    if args.command == "plan":
        plan.plan(args.prompt)
    elif args.command == "build-patch":
        build_patch.build_patch()
    elif args.command == "run":
        run.run()

if __name__ == "__main__":
    main()
