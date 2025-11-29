from __future__ import annotations

from shared.lac_lane_router import choose_dev_lane


def test_lane_router_rules():
    assert choose_dev_lane(source="liam", complexity="simple", cost_sensitivity="normal") == "dev_gmx"
    assert choose_dev_lane(source="cls", complexity="simple", cost_sensitivity="normal") == "dev_codex"
    assert choose_dev_lane(source="manual", complexity="simple", cost_sensitivity="normal") == "dev_oss"
