from shared.governance_router_v41 import (
    check_writer_permission,
    evaluate_request,
    normalize_writer,
    policy_allow_lane,
    resolve_zone,
)


def test_writer_normalization():
    assert normalize_writer("cls") == "CLS"
    assert normalize_writer("ClS") == "CLS"
    assert normalize_writer("GG") == "GG"
    assert normalize_writer(None) == "UNKNOWN"


def test_check_writer_permission_locked():
    assert check_writer_permission("CLC", "locked_zone") is True
    assert check_writer_permission("Liam", "locked_zone") is False


def test_check_writer_permission_open():
    assert check_writer_permission("Liam", "open_zone") is True
    assert check_writer_permission("GMX", "open_zone") is True
    assert check_writer_permission("unknown", "open_zone") is False


def test_policy_allow_lane_locked_denies_dev():
    assert policy_allow_lane("dev_oss", "locked_zone", "CLC") is False
    assert policy_allow_lane(None, "locked_zone", "CLC") is True


def test_policy_allow_lane_open_allows_known():
    for lane in ("dev_oss", "dev_gmxcli", "dev_codex"):
        assert policy_allow_lane(lane, "open_zone", "GG") is True
    assert policy_allow_lane("dev_paid", "open_zone", "GG") is False


def test_evaluate_request_allow():
    wo = {
        "files": ["agents/liam/core.py"],
        "source": "Liam",
        "routing_hint": "dev_oss",
    }
    result = evaluate_request(wo)
    assert result["ok"] is True
    assert result["zone"] == "open_zone"
    assert result["writer"] == "LIAM"


def test_evaluate_request_deny_writer():
    wo = {
        "files": ["CLC/core.py"],
        "source": "Liam",
        "routing_hint": "dev_oss",
    }
    result = evaluate_request(wo)
    assert result["ok"] is False
    assert result["zone"] == "locked_zone"
    assert result["reason"] == "writer_not_allowed"


def test_evaluate_request_deny_lane_in_locked():
    wo = {
        "files": ["g/docs/AI_OP_001_v4.md"],
        "source": "CLC",
        "routing_hint": "dev_oss",
    }
    result = evaluate_request(wo)
    assert result["ok"] is False
    assert result["reason"] == "lane_not_allowed"


def test_resolve_zone_unknown_is_locked():
    assert resolve_zone(["unknown/path/file.txt"]) == "locked_zone"

