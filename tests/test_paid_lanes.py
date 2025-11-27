import json
import os

import pytest

from agents.dev_common import paid_lane_guard as guard


@pytest.fixture(autouse=True)
def temp_config_and_ledger(tmp_path, monkeypatch):
    cfg = tmp_path / "paid_lanes.yaml"
    ledger = tmp_path / "paid_lane_spend.json"
    cfg.write_text(
        """paid_lanes:
  enabled: false
  require_approval: true
  emergency_budget_thb: 50
  warn_ratio: 0.8
  reset_daily: true
"""
    )
    ledger.write_text(json.dumps({"date": "2000-01-01", "total_spend": 0, "model_breakdown": {}, "last_call_ts": None}))
    monkeypatch.setenv("LAC_PAID_LANES_CONFIG", str(cfg))
    monkeypatch.setenv("LAC_PAID_LANES_LEDGER", str(ledger))
    return cfg, ledger


def test_disabled_blocks():
    wo = {"requires_paid_lane": True}
    allowed, reason = guard.check_paid_lane_allowed(wo, cost_estimate=10)
    assert not allowed
    assert reason == "PAID_LANE_DISABLED"


def test_requires_approval_blocks_when_enabled(monkeypatch, temp_config_and_ledger):
    cfg, _ = temp_config_and_ledger
    cfg.write_text(
        """paid_lanes:
  enabled: true
  require_approval: true
  emergency_budget_thb: 50
  warn_ratio: 0.8
  reset_daily: true
"""
    )
    wo = {"requires_paid_lane": False}
    allowed, reason = guard.check_paid_lane_allowed(wo, cost_estimate=10)
    assert not allowed
    assert reason == "PAID_LANE_NEEDS_APPROVAL"


def test_budget_allows_and_records(monkeypatch, temp_config_and_ledger):
    cfg, ledger_path = temp_config_and_ledger
    cfg.write_text(
        """paid_lanes:
  enabled: true
  require_approval: true
  emergency_budget_thb: 50
  warn_ratio: 0.8
  reset_daily: true
"""
    )
    wo = {"requires_paid_lane": True}

    def fake_call():
        return "ok"

    result = guard.run_paid_call(wo, model_name="paid-model", call=fake_call, cost_estimate=10)
    assert result["status"] == "success"
    ledger = json.loads(ledger_path.read_text())
    assert ledger["total_spend"] == 10
    assert ledger["model_breakdown"]["paid-model"] == 10


def test_budget_block(monkeypatch, temp_config_and_ledger):
    cfg, ledger_path = temp_config_and_ledger
    cfg.write_text(
        """paid_lanes:
  enabled: true
  require_approval: true
  emergency_budget_thb: 20
  warn_ratio: 0.8
  reset_daily: true
"""
    )
    ledger_path.write_text(
        json.dumps(
            {
                "date": guard._today(),
                "total_spend": 15,
                "model_breakdown": {},
                "last_call_ts": None,
            }
        )
    )
    wo = {"requires_paid_lane": True}
    allowed, reason = guard.check_paid_lane_allowed(wo, cost_estimate=10)
    assert not allowed
    assert reason == "PAID_LANE_BUDGET_EXCEEDED"
