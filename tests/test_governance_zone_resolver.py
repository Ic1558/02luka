from shared.governance_router_v41 import resolve_zone


def test_resolve_zone_locked_patterns():
    assert resolve_zone(["CLC/core.py"]) == "locked_zone"
    assert resolve_zone(["CLS/notes.txt", "agents/liam/core.py"]) == "locked_zone"


def test_resolve_zone_open_patterns():
    assert resolve_zone(["agents/liam/core.py"]) == "open_zone"
    assert resolve_zone(["shared/routing.py"]) == "open_zone"


def test_resolve_zone_unknown_treated_locked():
    assert resolve_zone(["unknown_folder/file.py"]) == "locked_zone"
    assert resolve_zone(["README.md"]) == "locked_zone"


def test_resolve_zone_empty_defaults_open():
    assert resolve_zone([]) == "open_zone"

