#!/usr/bin/env python3
"""
Claude Batch Tracker

Tracks Claude PR batch operations for report generation.
Maintains a running batch state file that accumulates:
- Merged PRs
- Updated branches
- Time spent
- Credits used

Usage:
    # Start a new batch
    ./claude_batch_tracker.py start

    # Track a merged PR
    ./claude_batch_tracker.py pr-merged --number 123 --title "Fix bug" --branch "fix/bug"

    # Track a branch update
    ./claude_batch_tracker.py branch-updated --branch "main" --sha "abc123" --message "Update"

    # Track time spent (in milliseconds)
    ./claude_batch_tracker.py track-time --duration 5000

    # Track credits used
    ./claude_batch_tracker.py track-credits --amount 0.025

    # Generate final report
    ./claude_batch_tracker.py report
"""

import os
import sys
import json
import argparse
from datetime import datetime
from pathlib import Path
from typing import Dict, Any, Optional

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

try:
    from skills.claude_pr_batch_report import ClaudePRBatchReport
except ImportError:
    print("Error: Could not import ClaudePRBatchReport", file=sys.stderr)
    sys.exit(1)


class ClaudeBatchTracker:
    """Track Claude batch operations"""

    def __init__(self, base_dir: Optional[str] = None):
        """
        Initialize the batch tracker

        Args:
            base_dir: Base directory for the project (defaults to ~/02luka)
        """
        self.base_dir = Path(base_dir or os.path.expanduser("~/02luka"))
        self.state_dir = self.base_dir / "g" / "metrics" / "claude_batch"
        self.state_dir.mkdir(parents=True, exist_ok=True)
        self.state_file = self.state_dir / "current_batch.json"

    def start_batch(self) -> Dict[str, Any]:
        """
        Start a new batch tracking session

        Returns:
            Batch metadata
        """
        batch_data = {
            "batch_id": f"batch_{datetime.now().strftime('%Y%m%d_%H%M%S')}",
            "start_time": datetime.now().isoformat(),
            "end_time": None,
            "merged_prs": [],
            "updated_branches": [],
            "time_spent_ms": 0,
            "credits_used": 0.0
        }

        self._save_state(batch_data)

        return {
            "ok": True,
            "message": "Batch tracking started",
            "batch_id": batch_data["batch_id"],
            "start_time": batch_data["start_time"]
        }

    def track_merged_pr(self, pr_number: int, title: str, branch: str,
                       url: Optional[str] = None) -> Dict[str, Any]:
        """
        Track a merged PR

        Args:
            pr_number: PR number
            title: PR title
            branch: Branch name
            url: PR URL (optional)

        Returns:
            Operation result
        """
        state = self._load_state()

        pr_data = {
            "number": pr_number,
            "title": title,
            "branch": branch,
            "merged_at": datetime.now().isoformat(),
            "url": url or f"https://github.com/owner/repo/pull/{pr_number}"
        }

        state["merged_prs"].append(pr_data)
        self._save_state(state)

        return {
            "ok": True,
            "message": f"Tracked merged PR #{pr_number}",
            "pr": pr_data
        }

    def track_updated_branch(self, branch: str, commit_sha: str,
                            commit_message: str) -> Dict[str, Any]:
        """
        Track a branch update

        Args:
            branch: Branch name
            commit_sha: Commit SHA
            commit_message: Commit message

        Returns:
            Operation result
        """
        state = self._load_state()

        branch_data = {
            "branch": branch,
            "commit_sha": commit_sha,
            "commit_message": commit_message,
            "updated_at": datetime.now().isoformat()
        }

        state["updated_branches"].append(branch_data)
        self._save_state(state)

        return {
            "ok": True,
            "message": f"Tracked branch update: {branch}",
            "branch": branch_data
        }

    def track_time(self, duration_ms: int) -> Dict[str, Any]:
        """
        Add time spent to the batch

        Args:
            duration_ms: Duration in milliseconds

        Returns:
            Operation result
        """
        state = self._load_state()
        state["time_spent_ms"] += duration_ms
        self._save_state(state)

        return {
            "ok": True,
            "message": f"Tracked {duration_ms}ms",
            "total_time_ms": state["time_spent_ms"]
        }

    def track_credits(self, amount: float) -> Dict[str, Any]:
        """
        Add credits used to the batch

        Args:
            amount: Credits amount

        Returns:
            Operation result
        """
        state = self._load_state()
        state["credits_used"] += amount
        self._save_state(state)

        return {
            "ok": True,
            "message": f"Tracked {amount} credits",
            "total_credits": state["credits_used"]
        }

    def get_status(self) -> Dict[str, Any]:
        """
        Get current batch status

        Returns:
            Current batch state
        """
        if not self.state_file.exists():
            return {
                "ok": False,
                "message": "No active batch",
                "active": False
            }

        state = self._load_state()

        return {
            "ok": True,
            "active": True,
            "batch_id": state.get("batch_id"),
            "start_time": state.get("start_time"),
            "merged_prs_count": len(state.get("merged_prs", [])),
            "updated_branches_count": len(state.get("updated_branches", [])),
            "time_spent_ms": state.get("time_spent_ms", 0),
            "credits_used": state.get("credits_used", 0.0)
        }

    def generate_report(self) -> Dict[str, Any]:
        """
        Generate batch report and end tracking

        Returns:
            Report generation result
        """
        if not self.state_file.exists():
            return {
                "ok": False,
                "error": "No active batch to report"
            }

        state = self._load_state()
        state["end_time"] = datetime.now().isoformat()

        # Create reporter and load data
        reporter = ClaudePRBatchReport(base_dir=str(self.base_dir))
        reporter.batch_data = state

        # Generate report
        result = reporter.generate_report()

        # Archive the state file
        archive_file = self.state_dir / f"{state['batch_id']}.json"
        self.state_file.rename(archive_file)

        result["archived_state"] = str(archive_file)

        return result

    def _load_state(self) -> Dict[str, Any]:
        """Load current batch state"""
        if not self.state_file.exists():
            return {
                "batch_id": None,
                "start_time": None,
                "end_time": None,
                "merged_prs": [],
                "updated_branches": [],
                "time_spent_ms": 0,
                "credits_used": 0.0
            }

        with open(self.state_file, 'r') as f:
            return json.load(f)

    def _save_state(self, state: Dict[str, Any]):
        """Save batch state"""
        with open(self.state_file, 'w') as f:
            json.dump(state, f, indent=2)


def main():
    """CLI interface"""
    parser = argparse.ArgumentParser(
        description="Track Claude PR batch operations"
    )
    parser.add_argument(
        '--base-dir',
        help='Base directory (defaults to ~/02luka)',
        type=str,
        default=None
    )

    subparsers = parser.add_subparsers(dest='command', help='Commands')

    # Start batch
    subparsers.add_parser('start', help='Start a new batch')

    # Track merged PR
    pr_parser = subparsers.add_parser('pr-merged', help='Track a merged PR')
    pr_parser.add_argument('--number', type=int, required=True, help='PR number')
    pr_parser.add_argument('--title', type=str, required=True, help='PR title')
    pr_parser.add_argument('--branch', type=str, required=True, help='Branch name')
    pr_parser.add_argument('--url', type=str, help='PR URL')

    # Track branch update
    branch_parser = subparsers.add_parser('branch-updated', help='Track a branch update')
    branch_parser.add_argument('--branch', type=str, required=True, help='Branch name')
    branch_parser.add_argument('--sha', type=str, required=True, help='Commit SHA')
    branch_parser.add_argument('--message', type=str, required=True, help='Commit message')

    # Track time
    time_parser = subparsers.add_parser('track-time', help='Track time spent')
    time_parser.add_argument('--duration', type=int, required=True, help='Duration in ms')

    # Track credits
    credits_parser = subparsers.add_parser('track-credits', help='Track credits used')
    credits_parser.add_argument('--amount', type=float, required=True, help='Credit amount')

    # Get status
    subparsers.add_parser('status', help='Get current batch status')

    # Generate report
    subparsers.add_parser('report', help='Generate batch report')

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    tracker = ClaudeBatchTracker(base_dir=args.base_dir)

    # Execute command
    if args.command == 'start':
        result = tracker.start_batch()
    elif args.command == 'pr-merged':
        result = tracker.track_merged_pr(
            args.number, args.title, args.branch, args.url
        )
    elif args.command == 'branch-updated':
        result = tracker.track_updated_branch(
            args.branch, args.sha, args.message
        )
    elif args.command == 'track-time':
        result = tracker.track_time(args.duration)
    elif args.command == 'track-credits':
        result = tracker.track_credits(args.amount)
    elif args.command == 'status':
        result = tracker.get_status()
    elif args.command == 'report':
        result = tracker.generate_report()
    else:
        print(f"Unknown command: {args.command}", file=sys.stderr)
        sys.exit(1)

    # Output result
    print(json.dumps(result, indent=2))

    # Exit with appropriate code
    sys.exit(0 if result.get("ok", False) else 1)


if __name__ == "__main__":
    main()
