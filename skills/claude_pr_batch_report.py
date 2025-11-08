#!/usr/bin/env python3
"""
Claude PR Batch Report Generator

Generates batch reports for Claude PR operations including:
- Merged PRs
- Updated branches
- Time spent / credit used

Output: g/reports/CLAUDE_PR_BATCH_<timestamp>.md
"""

import os
import sys
import json
import time
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Any, Optional


class ClaudePRBatchReport:
    """Generate batch reports for Claude PR operations"""

    def __init__(self, base_dir: Optional[str] = None):
        """
        Initialize the batch report generator

        Args:
            base_dir: Base directory for the project (defaults to ~/02luka)
        """
        self.base_dir = Path(base_dir or os.path.expanduser("~/02luka"))
        self.reports_dir = self.base_dir / "g" / "reports"
        self.reports_dir.mkdir(parents=True, exist_ok=True)

        # Batch tracking data
        self.batch_data = {
            "merged_prs": [],
            "updated_branches": [],
            "time_spent_ms": 0,
            "credits_used": 0,
            "start_time": None,
            "end_time": None
        }

    def add_merged_pr(self, pr_number: int, title: str, branch: str,
                      merged_at: Optional[str] = None, url: Optional[str] = None):
        """
        Add a merged PR to the batch report

        Args:
            pr_number: PR number
            title: PR title
            branch: Branch name
            merged_at: Merge timestamp (ISO format)
            url: PR URL
        """
        self.batch_data["merged_prs"].append({
            "number": pr_number,
            "title": title,
            "branch": branch,
            "merged_at": merged_at or datetime.now().isoformat(),
            "url": url or f"https://github.com/owner/repo/pull/{pr_number}"
        })

    def add_updated_branch(self, branch_name: str, commit_sha: str,
                          commit_message: str, updated_at: Optional[str] = None):
        """
        Add an updated branch to the batch report

        Args:
            branch_name: Branch name
            commit_sha: Commit SHA
            commit_message: Commit message
            updated_at: Update timestamp (ISO format)
        """
        self.batch_data["updated_branches"].append({
            "branch": branch_name,
            "commit_sha": commit_sha[:8],  # Short SHA
            "commit_message": commit_message,
            "updated_at": updated_at or datetime.now().isoformat()
        })

    def track_time(self, duration_ms: int):
        """
        Add time spent to the batch

        Args:
            duration_ms: Duration in milliseconds
        """
        self.batch_data["time_spent_ms"] += duration_ms

    def track_credits(self, credits: float):
        """
        Add credits used to the batch

        Args:
            credits: Credits used
        """
        self.batch_data["credits_used"] += credits

    def set_batch_times(self, start_time: str, end_time: Optional[str] = None):
        """
        Set batch start and end times

        Args:
            start_time: Batch start time (ISO format)
            end_time: Batch end time (ISO format, defaults to now)
        """
        self.batch_data["start_time"] = start_time
        self.batch_data["end_time"] = end_time or datetime.now().isoformat()

    def generate_report(self) -> Dict[str, Any]:
        """
        Generate the batch report markdown file

        Returns:
            Dictionary with report metadata
        """
        start = time.time()

        # Generate timestamp for filename
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"CLAUDE_PR_BATCH_{timestamp}.md"
        filepath = self.reports_dir / filename

        # Calculate duration
        if not self.batch_data["start_time"]:
            self.batch_data["start_time"] = datetime.now().isoformat()
        if not self.batch_data["end_time"]:
            self.batch_data["end_time"] = datetime.now().isoformat()

        # Convert time spent to human readable format
        time_spent_sec = self.batch_data["time_spent_ms"] / 1000
        time_spent_min = time_spent_sec / 60
        time_spent_hours = time_spent_min / 60

        # Generate markdown content
        content = self._generate_markdown()

        # Write to file
        filepath.write_text(content, encoding="utf-8")

        duration_ms = int((time.time() - start) * 1000)

        result = {
            "ok": True,
            "filepath": str(filepath),
            "filename": filename,
            "timestamp": timestamp,
            "size_bytes": filepath.stat().st_size,
            "duration_ms": duration_ms,
            "summary": {
                "merged_prs_count": len(self.batch_data["merged_prs"]),
                "updated_branches_count": len(self.batch_data["updated_branches"]),
                "time_spent_ms": self.batch_data["time_spent_ms"],
                "credits_used": self.batch_data["credits_used"]
            }
        }

        return result

    def _generate_markdown(self) -> str:
        """Generate markdown content for the report"""

        # Header
        lines = [
            f"# Claude PR Batch Report",
            "",
            f"**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            f"**Batch Period:** {self.batch_data['start_time']} → {self.batch_data['end_time']}",
            "",
            "---",
            ""
        ]

        # Summary section
        time_spent_sec = self.batch_data["time_spent_ms"] / 1000
        time_spent_min = time_spent_sec / 60

        lines.extend([
            "## 📊 Batch Summary",
            "",
            f"- **Merged PRs:** {len(self.batch_data['merged_prs'])}",
            f"- **Updated Branches:** {len(self.batch_data['updated_branches'])}",
            f"- **Time Spent:** {time_spent_min:.2f} minutes ({time_spent_sec:.2f} seconds)",
            f"- **Credits Used:** {self.batch_data['credits_used']:.4f}",
            "",
            "---",
            ""
        ])

        # Merged PRs section
        lines.extend([
            "## ✅ Merged PRs",
            ""
        ])

        if self.batch_data["merged_prs"]:
            for pr in self.batch_data["merged_prs"]:
                lines.extend([
                    f"### PR #{pr['number']}: {pr['title']}",
                    "",
                    f"- **Branch:** `{pr['branch']}`",
                    f"- **Merged At:** {pr['merged_at']}",
                    f"- **URL:** {pr['url']}",
                    ""
                ])
        else:
            lines.extend([
                "_No PRs merged in this batch_",
                ""
            ])

        lines.extend([
            "---",
            ""
        ])

        # Updated branches section
        lines.extend([
            "## 🔄 Updated Branches",
            ""
        ])

        if self.batch_data["updated_branches"]:
            lines.append("| Branch | Commit | Message | Updated At |")
            lines.append("|--------|--------|---------|------------|")

            for branch in self.batch_data["updated_branches"]:
                msg_truncated = branch['commit_message'][:50]
                if len(branch['commit_message']) > 50:
                    msg_truncated += "..."
                lines.append(
                    f"| `{branch['branch']}` | `{branch['commit_sha']}` | "
                    f"{msg_truncated} | {branch['updated_at'][:19]} |"
                )
            lines.append("")
        else:
            lines.extend([
                "_No branches updated in this batch_",
                ""
            ])

        lines.extend([
            "---",
            ""
        ])

        # Time and Credit Details
        lines.extend([
            "## ⏱️ Time & Credit Breakdown",
            "",
            f"- **Total Duration:** {self.batch_data['time_spent_ms']} ms",
            f"- **Average Time per Operation:** "
            f"{self.batch_data['time_spent_ms'] / max(1, len(self.batch_data['merged_prs']) + len(self.batch_data['updated_branches'])):.2f} ms",
            f"- **Credits Used:** {self.batch_data['credits_used']:.4f}",
            "",
            "---",
            "",
            f"_Report generated by Claude PR Batch Reporter_"
        ])

        return "\n".join(lines)

    def load_from_json(self, json_file: str):
        """
        Load batch data from a JSON file

        Args:
            json_file: Path to JSON file with batch data
        """
        with open(json_file, 'r') as f:
            data = json.load(f)
            self.batch_data.update(data)


def main():
    """CLI interface for batch report generation"""
    import argparse

    parser = argparse.ArgumentParser(
        description="Generate Claude PR batch reports"
    )
    parser.add_argument(
        '--json', '-j',
        help='Load batch data from JSON file',
        type=str
    )
    parser.add_argument(
        '--base-dir', '-d',
        help='Base directory (defaults to ~/02luka)',
        type=str,
        default=None
    )
    parser.add_argument(
        '--output', '-o',
        help='Output to stdout instead of file',
        action='store_true'
    )

    args = parser.parse_args()

    # Create reporter
    reporter = ClaudePRBatchReport(base_dir=args.base_dir)

    # Load data from JSON if provided
    if args.json:
        reporter.load_from_json(args.json)
    else:
        # Example data for testing
        reporter.set_batch_times(
            start_time=datetime.now().isoformat()
        )
        reporter.add_merged_pr(
            pr_number=123,
            title="Add batch report generation",
            branch="feature/batch-reports",
            url="https://github.com/owner/repo/pull/123"
        )
        reporter.add_updated_branch(
            branch_name="claude/batch-report-output-011CUrNgXP3ChtSNhyaJDwEV",
            commit_sha="abc1234567890",
            commit_message="feat: implement batch report generation"
        )
        reporter.track_time(5430)  # 5.43 seconds
        reporter.track_credits(0.0245)

    # Generate report
    result = reporter.generate_report()

    # Output result
    if args.output:
        with open(result['filepath'], 'r') as f:
            print(f.read())
    else:
        print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
