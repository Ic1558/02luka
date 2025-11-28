import sys
import os
sys.path.append(os.getcwd())

from shared.routing import determine_lane
from agents.ai_manager.requirement_parser import parse_requirement_md

def test_routing():
    print("--- Testing Routing ---")
    
    # Simple
    res = determine_lane("simple", file_count=1)
    print(f"Simple: {res['lane']} (Expected: dev_oss)")
    assert res['lane'] == "dev_oss"
    
    # Moderate
    res = determine_lane("moderate", file_count=5)
    print(f"Moderate: {res['lane']} (Expected: dev_gmxcli)")
    assert res['lane'] == "dev_gmxcli"
    
    # Complex (Paid Disabled by default)
    res = determine_lane("complex", file_count=20)
    print(f"Complex (Default): {res['lane']} (Expected: dev_gmxcli - fallback)")
    assert res['lane'] == "dev_gmxcli"
    
    # Hint OSS
    res = determine_lane("complex", hint="dev_oss")
    print(f"Hint OSS: {res['lane']} (Expected: dev_oss)")
    assert res['lane'] == "dev_oss"

def test_parser():
    print("\n--- Testing Parser ---")
    
    md_content = """
# Requirement: Test Feature
**ID:** REQ-123
**Priority:** P1
**Complexity:** Simple

## Objective
Test parsing logic.

```json
{
  "wo_id": "WO-TEST-001",
  "routing_hint": "dev_oss"
}
```
    """
    
    parsed = parse_requirement_md(md_content)
    print(f"Parsed WO ID: {parsed.get('wo_id')} (Expected: WO-TEST-001)")
    print(f"Parsed Hint: {parsed.get('routing_hint')} (Expected: dev_oss)")
    
    assert parsed.get('wo_id') == "WO-TEST-001"
    assert parsed.get('routing_hint') == "dev_oss"

if __name__ == "__main__":
    try:
        test_routing()
        test_parser()
        print("\n✅ SMOKE TEST PASSED")
    except AssertionError as e:
        print(f"\n❌ SMOKE TEST FAILED: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ ERROR: {e}")
        sys.exit(1)
