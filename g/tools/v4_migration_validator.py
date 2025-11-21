#!/usr/bin/env python3
"""
V4 Migration Validator
Scans all agent persona files to verify V4 Universal Memory Contract compliance.
"""

import sys
from pathlib import Path
from typing import List, Dict, Any

REPO_ROOT = Path(__file__).resolve().parents[2]  # g/tools/ -> repo root
AGENTS_DIR = REPO_ROOT / "agents"

# Required V4 contract markers
V4_MARKERS = [
    "V4 Universal Contract",
    "memory_hub.memory_hub",
    "load_memory",
    "save_memory"
]

def check_persona_compliance(persona_path: Path) -> Dict[str, Any]:
    """Check if a persona file has V4 contract."""
    if not persona_path.exists():
        return {
            "compliant": False,
            "reason": "File does not exist",
            "missing_markers": V4_MARKERS
        }
    
    content = persona_path.read_text()
    missing = []
    
    for marker in V4_MARKERS:
        if marker not in content:
            missing.append(marker)
    
    return {
        "compliant": len(missing) == 0,
        "reason": "All markers present" if len(missing) == 0 else f"Missing {len(missing)} markers",
        "missing_markers": missing
    }

def scan_all_personas() -> List[Dict[str, Any]]:
    """Scan all agent directories for persona files."""
    results = []
    
    if not AGENTS_DIR.exists():
        return results
    
    for agent_dir in AGENTS_DIR.iterdir():
        if not agent_dir.is_dir():
            continue
        
        persona_file = agent_dir / "PERSONA_PROMPT.md"
        if persona_file.exists():
            compliance = check_persona_compliance(persona_file)
            results.append({
                "agent": agent_dir.name,
                "persona_path": str(persona_file.relative_to(REPO_ROOT)),
                **compliance
            })
    
    return results

def main():
    """Run migration validator."""
    print("=" * 60)
    print("V4 Migration Validator")
    print("=" * 60)
    print()
    
    results = scan_all_personas()
    
    if not results:
        print("⚠️  No persona files found")
        return 1
    
    compliant_count = sum(1 for r in results if r["compliant"])
    total_count = len(results)
    
    print(f"Scanned {total_count} persona file(s)")
    print()
    
    for result in results:
        status = "✅" if result["compliant"] else "❌"
        print(f"{status} {result['agent']}: {result['reason']}")
        
        if not result["compliant"] and result["missing_markers"]:
            for marker in result["missing_markers"]:
                print(f"   - Missing: {marker}")
        print()
    
    print("=" * 60)
    print(f"Result: {compliant_count}/{total_count} compliant")
    print("=" * 60)
    
    if compliant_count == total_count:
        print("\n🎉 All personas are V4 compliant!")
        return 0
    else:
        print(f"\n⚠️  {total_count - compliant_count} persona(s) need migration")
        return 1

if __name__ == "__main__":
    sys.exit(main())
