#!/usr/bin/env zsh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REGISTRY="${PORTS_REGISTRY:-$REPO_ROOT/ports.registry.yml}"
TELEMETRY_DIR="$REPO_ROOT/g/telemetry/ops"
REPORT_DIR="$REPO_ROOT/g/reports/ops"

# Ensure directories exist
mkdir -p "$TELEMETRY_DIR" "$REPORT_DIR"

if [[ ! -f "$REGISTRY" ]]; then
  echo "❌ Registry not found: $REGISTRY" >&2; exit 1
fi
if ! command -v lsof >/dev/null 2>&1; then
  echo "❌ lsof not found"; exit 1
fi

# We use an embedded Python script for robust Graph analysis and Telemetry generation.
python3 -c "
import sys
import subprocess
import re
import json
import time
import socket
import getpass
from pathlib import Path
from datetime import datetime

def get_registry(path):
    reg = {}
    current_port = None
    try:
        content = Path(path).read_text(encoding='utf-8')
    except Exception as e:
        print(f'Error reading registry: {e}')
        sys.exit(1)

    for line in content.splitlines():
        line = line.split('#', 1)[0].rstrip()
        if not line: continue
        
        m = re.match(r'^\s*(\d+)\s*:', line)
        if m:
            current_port = m.group(1)
            reg[current_port] = {}
        elif current_port and ':' in line:
            k, v = line.split(':', 1)
            reg[current_port][k.strip()] = v.strip()
    return reg

def get_listeners(port):
    try:
        # Get PIDs only
        out = subprocess.check_output(
            ['lsof', '-nP', '-iTCP:' + str(port), '-sTCP:LISTEN', '-t'], 
            stderr=subprocess.DEVNULL
        ).decode().strip()
        if not out: return []
        return [int(p) for p in out.splitlines() if p.strip()]
    except subprocess.CalledProcessError:
        return []

def get_process_info(pids):
    # Returns check: {pid: {'ppid': int, 'cmd': str}}
    if not pids: return {}
    pid_list = ','.join(map(str, pids))
    try:
        # ps -p ... -o pid,ppid,command
        out = subprocess.check_output(
            ['ps', '-p', pid_list, '-o', 'pid=,ppid=,command='],
            text=True
        )
        info = {}
        for line in out.splitlines():
            parts = line.split(maxsplit=2)
            if len(parts) >= 3:
                p, pp, cmd = parts
                info[int(p)] = {'ppid': int(pp), 'cmd': cmd}
    except Exception:
        pass
    return info

def get_git_rev():
    try:
        return subprocess.check_output(['git', 'rev-parse', '--short', 'HEAD'], stderr=subprocess.DEVNULL).decode().strip()
    except:
        return 'unknown'

def analyze_port(port, meta):
    listeners = get_listeners(port)
    service = meta.get('service', 'unknown')
    policy = meta.get('policy', 'free')
    owner_str = meta.get('owner', '')
    
    status = 'safe'
    display_pid = '-'
    display_cmd = '(free)'
    note = ''
    
    # Telemetry data for this port
    t_port = {
        'status': 'safe',
        'service': service,
        'pids': listeners,
        'owner': owner_str,
        'note': 'free'
    }

    if listeners:
        pinfo = get_process_info(listeners)
        
        # 1. Family Tree Check
        roots = []
        for pid in listeners:
            if pid not in pinfo: continue
            ppid = pinfo[pid]['ppid']
            if ppid not in listeners:
                roots.append(pid)
        
        if not roots:
             status = 'conflict'
             note = 'cycle detected'
             display_cmd = '(cycle conflict)'
        elif len(roots) > 1:
             status = 'conflict'
             note = 'split brain (multiple roots)'
             display_cmd = f'{len(listeners)} PIDS, {len(roots)} Roots (Split Brain)'
        else:
             root_pid = roots[0]
             root_cmd = pinfo.get(root_pid, {}).get('cmd', '')
             
             # 2. Owner Check
             if not owner_str:
                 if policy == 'free':
                     status = 'safe'
                 else:
                     status = 'safe' 
             else:
                 if owner_str in root_cmd:
                     status = 'safe'
                     note = 'owner match'
                 else:
                     status = 'conflict'
                     note = 'owner mismatch'
                     display_cmd = f'Cmd mismatch: {root_cmd[:30]}...'

        # Display Setup
        if status == 'safe':
            if roots:
                rpid = roots[0]
                rcmd = pinfo.get(rpid, {}).get('cmd', '')
                display_pid = str(rpid)
                count = len(listeners)
                if count > 1:
                    display_cmd = f'{rcmd[:40]}... (+{count-1} workers)'
                    note += ' (+workers)'
                else:
                    display_cmd = f'{rcmd[:60]}'
            else:
                display_cmd = 'Unknown'
        else:
            display_pid = ','.join(map(str, listeners[:2]))
            if len(listeners) > 2: display_pid += '...'
    
    t_port['status'] = status
    t_port['note'] = note
    
    formatted_line = f'{str(port):<6} {service:<18} {policy:<10} {status:<9} {display_pid:<15} {display_cmd}'
    return t_port, formatted_line, status

def main():
    if len(sys.argv) < 4:
        print('Usage: python script <registry_path> <telemetry_file> <report_file>')
        sys.exit(1)
        
    reg_path = sys.argv[1]
    telemetry_path = sys.argv[2]
    report_path = sys.argv[3]
    
    reg = get_registry(reg_path)
    
    header = f'{\"PORT\":<6} {\"SERVICE\":<18} {\"POLICY\":<10} {\"STATUS\":<9} {\"PID\":<15} {\"COMMAND\"}'
    sep = '-' * 90
    
    lines = [header, sep]
    ports_data = {}
    overall_status = 'safe'
    
    for port in sorted(reg.keys(), key=int):
        t_port, line, p_status = analyze_port(port, reg[port])
        lines.append(line)
        ports_data[port] = t_port
        if p_status != 'safe':
            overall_status = 'conflict'
            
    lines.append(sep)
    output = '\\n'.join(lines)
    
    # Print to stdout
    print(output)
    
    # Save Human Report
    try:
        Path(report_path).write_text(output + '\\n', encoding='utf-8')
    except Exception as e:
        print(f'Warning: Could not write report: {e}', file=sys.stderr)

    # Save Telemetry
    telemetry_record = {
        'ts': datetime.now().astimezone().isoformat(),
        'event': 'ports_check',
        'lane': 'OPS',
        'actor': getpass.getuser(),
        'host': socket.gethostname(),
        'git_rev': get_git_rev(),
        'result': overall_status,
        'ports': ports_data,
        'errors': [],
        'source': 'tools/ports_check.zsh'
    }
    
    try:
        with open(telemetry_path, 'a', encoding='utf-8') as f:
            f.write(json.dumps(telemetry_record) + '\\n')
    except Exception as e:
        print(f'Warning: Could not write telemetry: {e}', file=sys.stderr)

if __name__ == '__main__':
    main()
" "$REGISTRY" "$TELEMETRY_DIR/ports_check.jsonl" "$REPORT_DIR/ports_check_latest.txt"
