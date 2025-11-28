from agents.ai_manager.requirement_parser import parse_requirement_md


def test_routing_hint_respects_default_complexity():
    content = """
# Requirement: Missing Complexity
**ID:** REQ-123

## Objective
Test default complexity routing.
"""
    parsed = parse_requirement_md(content)
    assert parsed["complexity"] == "moderate"
    assert parsed["routing_hint"] == "dev_gmxcli"
