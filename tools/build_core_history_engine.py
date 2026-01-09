#!/usr/bin/env python3
"""
Core History Engine - Phase 12/13 Signal Promotion & Auto-Hook Planner
Purpose: Generate latest.md from latest.json with clustering and promotion logic
Input: Reads g/core_history/latest.json
Output: Prints markdown content to stdout
"""
import json
import pathlib
import datetime
import os
import sys


def parse_ts(ts_val):
    """Parse timestamp (int/float/ISO string) to datetime object."""
    if isinstance(ts_val, (int, float)):
        return datetime.datetime.fromtimestamp(ts_val, datetime.timezone.utc)
    try:
        return datetime.datetime.fromisoformat(str(ts_val).replace('Z', '+00:00'))
    except:
        return datetime.datetime.now(datetime.timezone.utc)


def main():
    DEBUG = os.environ.get("BUILD_CORE_HISTORY_DEBUG") == "1"
    
    # Load data
    p = pathlib.Path("g/core_history/latest.json")
    data = json.loads(p.read_text(encoding="utf-8"))
    m = data["metadata"]
    d = data["decisions"]
    r = data["rules"]
    
    lines = []
    lines.append(f"# Core History - {m['ts']}")
    lines.append("")
    lines.append(f"- git: {m['git']['branch']} @ {m['git']['head']} ({m['git']['status']})")
    lines.append(f"- decision_log: {d['status']} (count={d['count']})")
    lines.append(f"- rules: {r['status']} (count={r['count']}, sha256={r.get('hash')})")
    lines.append("")
    lines.append("## Recent Decisions (last 5)")
    
    recent = d.get("recent", [])
    
    # 1. Cluster by time (gap > 60m starts new cluster)
    clusters = []
    current_cluster = []
    last_ts = None
    
    for item in recent:
        ts = item.get("ts", 0)
        dt = parse_ts(ts)
        if last_ts and (dt - last_ts).total_seconds() > 3600:
            clusters.append(current_cluster)
            current_cluster = []
        current_cluster.append(item)
        last_ts = dt
    if current_cluster:
        clusters.append(current_cluster)
    
    rendered = []
    
    for i, cluster in enumerate(clusters):
        if not cluster:
            continue
        
        # Analyze cluster
        rules_set = set()
        for item in cluster:
            rules_set.update(item.get("matched_rules", []))
        
        start_ts = parse_ts(cluster[0].get("ts", 0))
        end_ts = parse_ts(cluster[-1].get("ts", 0))
        duration_m = int((end_ts - start_ts).total_seconds() / 60)
        count = len(cluster)
        r5_only = (rules_set == {"R5_DEFAULT"})
        
        # Promotion Logic (Phase 12)
        promoted = False
        
        # R3 -> R2 (Actionable)
        action_rules = {r for r in rules_set if any(x in r.lower() for x in ['save', 'seal', 'sync'])}
        
        if action_rules:
            rendered.append(f"- [ ACTIONABLE ] System State Shift")
            rendered.append(f"  - triggered by: {', '.join(list(action_rules)[:3])}")
            promoted = True
        elif len(rules_set) >= 2 and "R5_DEFAULT" in rules_set:
            rendered.append(f"- [ SIGNAL ] Sustained System Activity Detected")
            rendered.append(f"  - sources: {', '.join(list(rules_set)[:3])}")
            rendered.append(f"  - duration: {duration_m}m")
            promoted = True
        elif r5_only and count >= 5:
            rendered.append(f"- [ PATTERN ] Repeated Routine Snapshot (x{count} in {duration_m}m)")
            promoted = True
        
        if promoted:
            if DEBUG:
                print(f"DEBUG: Promoted cluster size={count} dur={duration_m} rules={rules_set}", file=sys.stderr)
            continue
        
        # Fallback: Standard Grouping
        sub_group_count = 0
        sub_last_ts = 0
        for item in cluster:
            risk = item.get("risk", "?")
            r_list = item.get("matched_rules", [])
            is_routine = (risk == "low" and r_list == ["R5_DEFAULT"])
            
            if is_routine:
                sub_group_count += 1
                sub_last_ts = item.get("ts", 0)
            else:
                if sub_group_count > 0:
                    t_str = parse_ts(sub_last_ts).strftime('%H:%M')
                    rendered.append(f"- [ x{sub_group_count} ] Routine Snapshots (R5_DEFAULT) · last active {t_str}")
                    sub_group_count = 0
                
                preview = item.get("text_preview", "")[:120]
                r_str = ",".join(r_list[:5])
                rendered.append(f"- risk={risk} rules=[{r_str}] preview={preview}")
        
        if sub_group_count > 0:
            t_str = parse_ts(sub_last_ts).strftime('%H:%M')
            rendered.append(f"- [ x{sub_group_count} ] Routine Snapshots (R5_DEFAULT) · last active {t_str}")
    
    # Phase 13: Auto-Hook Planner (Dry-Run) - Corrected Selection Logic
    # Find the newest completed signal cluster (reverse iteration)
    hook_planned = False
    for cluster in reversed(clusters):
        if hook_planned:
            break
        
        rules_set = set()
        for item in cluster:
            rules_set.update(item.get("matched_rules", []))
        
        # Check if SIGNAL
        is_signal = (len(rules_set) >= 2 and "R5_DEFAULT" in rules_set)
        if not is_signal:
            continue
        
        # Check if already actioned
        action_rules = {r for r in rules_set if any(x in r.lower() for x in ['save', 'seal', 'sync'])}
        if action_rules:
            continue
        
        last_event_ts = parse_ts(cluster[-1].get("ts", 0))
        now = datetime.datetime.now(datetime.timezone.utc)
        silence_min = (now - last_event_ts).total_seconds() / 60
        
        if DEBUG:
            duration_m = int((parse_ts(cluster[-1].get("ts", 0)) - parse_ts(cluster[0].get("ts", 0))).total_seconds() / 60)
            print(f"DEBUG[R2]: cluster duration={duration_m}m silence={int(silence_min)}m rules={rules_set}", file=sys.stderr)
        
        if 10 <= silence_min <= 120:
            if os.environ.get("R2_HOOKS", "1") != "0":
                rendered.append(f"- [ ACTIONABLE ] Hook Planned: save (dry-run)")
                rendered.append(f"  - trigger: signal cluster ended ({int(silence_min)}m ago)")
                hook_planned = True
    
    lines.extend(rendered[-5:])
    print("\n".join(lines))


if __name__ == "__main__":
    main()
