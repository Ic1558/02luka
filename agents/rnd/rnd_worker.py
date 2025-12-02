
import json
import os
import sys
from pathlib import Path
from typing import Dict, List, Any
from datetime import datetime, timedelta, timezone
from collections import defaultdict
import threading

# Add project root to path
sys.path.insert(0, os.getcwd())

# Import MLS logging
try:
    from g.tools.mls_log import mls_log
except ImportError:
    # Silent failure if MLS not available
    def mls_log(*args, **kwargs):
        pass

class RndWorker:
    def __init__(self):
        self.telemetry_dir = Path("g/telemetry")
        self.data_dir = Path("g/data/rnd")
        self.report_dir = Path("g/reports/rnd")
        
        self.data_dir.mkdir(parents=True, exist_ok=True)
        self.report_dir.mkdir(parents=True, exist_ok=True)
        
        self.patterns_file = self.data_dir / "lac_patterns.jsonl"
        self.insight_report = self.report_dir / "latest_insight.md"

    def run(self):
        print("[R&D] Starting analysis...")
        
        # 1. Load Telemetry
        dev_data = self._load_jsonl(self.telemetry_dir / "dev_lane_execution.jsonl")
        qa_data = self._load_jsonl(self.telemetry_dir / "qa_lane_execution.jsonl")
        
        print(f"[R&D] Loaded {len(dev_data)} dev events, {len(qa_data)} qa events.")
        
        # 2. Analyze
        patterns = []
        patterns.extend(self._analyze_fragile_files(dev_data, qa_data))
        patterns.extend(self._analyze_slow_tests(dev_data))
        
        # 3. Save Patterns
        self._save_patterns(patterns)
        
        # 4. Generate Report
        self._generate_report(patterns)
        
        print(f"[R&D] Analysis complete. Found {len(patterns)} patterns.")
        
        # 5. Log to MLS (async, after completion)
        threading.Thread(
            target=mls_log,
            args=(
                "solution" if len(patterns) > 0 else "improvement",
                f"R&D Worker: Analyzed LAC telemetry",
                f"Found {len(patterns)} patterns from {len(dev_data)} dev events and {len(qa_data)} QA events",
                "rnd_worker"
            ),
            kwargs={
                "state": {"pattern_count": len(patterns), "dev_events": len(dev_data), "qa_events": len(qa_data)},
                "tags": ["rnd", "analysis", "telemetry"],
                "confidence": 0.85
            },
            daemon=True
        ).start()

    def _load_jsonl(self, path: Path) -> List[Dict[str, Any]]:
        if not path.exists():
            return []
        data = []
        with open(path, "r") as f:
            for line in f:
                try:
                    data.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
        return data

    def _analyze_fragile_files(self, dev_data: List[Dict], qa_data: List[Dict]) -> List[Dict]:
        """Detect files involved in multiple failures."""
        failures = defaultdict(int)
        
        # Check QA failures
        for entry in qa_data:
            if entry.get("status") != "pass":
                files = entry.get("files_touched", [])
                for f in files:
                    failures[f] += 1

        # Check Dev failures
        for entry in dev_data:
            if entry.get("status") != "success":
                files = entry.get("files_touched", [])
                for f in files:
                    failures[f] += 1
        
        patterns = []
        failure_threshold = 3
        
        for file_path, count in failures.items():
            if count > failure_threshold:
                patterns.append({
                    "type": "fragile_file",
                    "file": file_path,
                    "value": count,
                    "threshold": failure_threshold,
                    "timestamp": datetime.now(timezone.utc).isoformat()
                })
        return patterns

    def _analyze_slow_tests(self, dev_data: List[Dict]) -> List[Dict]:
        """Detect slow tasks."""
        patterns = []
        slow_threshold = 5000 # 5s
        
        for entry in dev_data:
            duration = entry.get("duration_ms", 0)
            if duration > slow_threshold:
                patterns.append({
                    "type": "slow_task",
                    "task_id": entry.get("task_id"),
                    "value": duration,
                    "threshold": slow_threshold,
                    "timestamp": datetime.now(timezone.utc).isoformat()
                })
        return patterns

    def _save_patterns(self, patterns: List[Dict]):
        with open(self.patterns_file, "w") as f:
            for p in patterns:
                f.write(json.dumps(p) + "\n")

    def _generate_report(self, patterns: List[Dict]):
        with open(self.insight_report, "w") as f:
            f.write("# LAC R&D Insight Report\n\n")
            f.write(f"Generated at: {datetime.now(timezone.utc).isoformat()}\n\n")
            
            if not patterns:
                f.write("No significant patterns detected.\n")
                return
            
            f.write(f"## Detected Patterns ({len(patterns)})\n\n")
            for p in patterns:
                f.write(f"- **{p['type']}**: Task `{p.get('task_id')}` took {p.get('value')}ms (Threshold: {p.get('threshold')}ms)\n")

if __name__ == "__main__":
    worker = RndWorker()
    worker.run()
