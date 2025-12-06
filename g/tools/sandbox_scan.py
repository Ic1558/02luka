#!/usr/bin/env python3
"""
Sandbox Violation Scanner
Reads schemas/codex_disallowed_commands.yaml and scans repo for violations
"""

import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent.parent
SCHEMA_FILE = REPO_ROOT / "schemas" / "codex_disallowed_commands.yaml"

def load_patterns():
    """Load disallowed patterns from schema"""
    with open(SCHEMA_FILE, 'r') as f:
        data = json.load(f)
    return [(p['id'], p['description'], re.compile(p['regex'], re.IGNORECASE)) 
            for p in data.get('patterns', [])]

def should_scan_file(path: Path):
    """Check if file should be scanned"""
    # Exclude patterns
    exclude_dirs = {'.git', 'node_modules', 'logs', 'bridge', 'g/telemetry', 
                    'mls/ledger', '__pycache__', '.backup', '_memory', '__artifacts__'}
    
    parts = path.parts
    if any(excl in parts for excl in exclude_dirs):
        return False
    
    # Include file types
    if path.suffix in {'.sh', '.zsh', '.bash', '.py', '.js', '.ts', '.yaml', '.yml'}:
        return True
    
    if path.name.lower().startswith('dockerfile'):
        return True
    
    if path.name == 'Makefile':
        return True
    
    return False

def scan_file(path: Path, patterns):
    """Scan a file for pattern violations"""
    try:
        text = path.read_text(errors='ignore')
        violations = []
        
        for pattern_id, desc, regex in patterns:
            for match in regex.finditer(text):
                line_num = text[:match.start()].count('\n') + 1
                line_text = text.split('\n')[line_num - 1] if line_num <= len(text.split('\n')) else ''
                violations.append({
                    'pattern_id': pattern_id,
                    'description': desc,
                    'line': line_num,
                    'match': match.group(),
                    'line_text': line_text.strip()[:100]
                })
        
        return violations
    except Exception as e:
        return []

def classify_file(path: Path):
    """Classify file as (A) code, (B) docs, (C) test"""
    rel_path = str(path.relative_to(REPO_ROOT))
    
    # Category C: Test fixtures
    if 'test' in rel_path.lower() or 'fixture' in rel_path.lower():
        return 'C'
    
    # Category B: Documentation
    if rel_path.startswith('g/docs/') or rel_path.startswith('docs/') or \
       rel_path.startswith('g/reports/') or rel_path.endswith('.md'):
        return 'B'
    
    # Category A: Executable code
    if rel_path.startswith('tools/') or rel_path.startswith('g/tools/') or \
       rel_path.startswith('agents/') or rel_path.startswith('misc/') or \
       rel_path.startswith('scripts/') or rel_path.startswith('governance/'):
        return 'A'
    
    # Default to A if it's a script file
    if path.suffix in {'.sh', '.zsh', '.bash', '.py', '.js', '.ts'}:
        return 'A'
    
    return 'B'  # Default to docs for unknown

def main():
    patterns = load_patterns()
    violations_by_file = {}
    
    # Scan all files
    for file_path in REPO_ROOT.rglob('*'):
        if not file_path.is_file():
            continue
        
        if not should_scan_file(file_path):
            continue
        
        rel_path = str(file_path.relative_to(REPO_ROOT))
        violations = scan_file(file_path, patterns)
        
        if violations:
            violations_by_file[rel_path] = {
                'category': classify_file(file_path),
                'violations': violations
            }
    
    # Print summary
    print(f"Found {sum(len(v['violations']) for v in violations_by_file.values())} violations in {len(violations_by_file)} files")
    print("\n=== Violations by Category ===")
    
    for category in ['A', 'B', 'C']:
        cat_files = {k: v for k, v in violations_by_file.items() if v['category'] == category}
        if cat_files:
            print(f"\nCategory {category} ({len(cat_files)} files):")
            for file_path, data in sorted(cat_files.items()):
                print(f"  {file_path}: {len(data['violations'])} violations")
                for v in data['violations'][:3]:  # Show first 3
                    print(f"    - [{v['pattern_id']}] line {v['line']}: {v['match']}")
    
    return violations_by_file

if __name__ == '__main__':
    main()
