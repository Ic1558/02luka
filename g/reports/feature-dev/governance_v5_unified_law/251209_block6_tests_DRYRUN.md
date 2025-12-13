# 🔹 BLOCK 6: Test Suites v5 (Dry-Run)

**Date:** 2025-12-10  
**Phase:** 3.3 — Full Implementation Blueprint  
**Status:** ✅ DRY-RUN (No File Write)  
**Scope:** Router v5, SandboxGuard v5, SIP (single-file), CLC Executor v5, WO Processor v5, Health Check  

---

## 📋 Test Tree (to be created)
```
tests/
  fixtures/
    sample_wo_strict.yaml
    sample_wo_fast.yaml
    sample_forbidden.sh
  v5_router/
    test_router_lanes.py
    test_router_mission_scope.py
  v5_sandbox/
    test_paths.py
    test_content.py
    test_sip_cli.py
  v5_sip/
    test_single_file_sip.py
    test_multifile_placeholder.py  # xfail (Block 4 pending)
  v5_clc/
    test_wo_validation.py
    test_exec_strict.py
  v5_wo_processor/
    test_lane_routing.py
    test_local_exec.py
    test_clc_wo_schema.py
  v5_health/
    test_health_json.py
    test_health_thresholds.py
```

---

## 🧪 Sample Test Snippets (Pytest)

### Router v5 — Lane Semantics
```python
import pytest
from bridge.core.router_v5 import route

@pytest.mark.parametrize("trigger,actor,path,op,expected_lane", [
    ("cursor", "CLS", "apps/app/main.py", "write", "FAST"),
    ("cursor", "CLS", "core/router.py", "write", "WARN"),
    ("cron", "CLC", "tools/task.py", "write", "STRICT"),
    ("cursor", "CLS", "/etc/hosts", "write", "BLOCKED"),
])
def test_router_lanes(trigger, actor, path, op, expected_lane):
    decision = route(trigger=trigger, actor=actor, path=path, op=op)
    assert decision.lane == expected_lane
```

### SandboxGuard v5 — Forbidden Content
```python
import pytest
from bridge.core.sandbox_guard_v5 import check_write_allowed

def test_forbidden_rm_rf():
    res = check_write_allowed(
        path="tools/script.sh",
        actor="CLS",
        operation="write",
        content="rm -rf /tmp"
    )
    assert not res.allowed
    assert res.violation.name == "FORBIDDEN_CONTENT_PATTERN"
```

### WO Processor v5 — Lane Routing
```python
import pytest
from bridge.core.wo_processor_v5 import process_wo_with_lane_routing
import yaml

def test_wo_processor_strict_creates_clc(tmp_path, monkeypatch):
    wo = {
        "wo_id": "WO-TEST-STRICT",
        "origin": {"trigger": "background", "actor": "CLC"},
        "operations": [
            {"path": "core/config.yaml", "operation": "write", "content": "x:1"}
        ]
    }
    wo_file = tmp_path/"WO-TEST-STRICT.yaml"
    wo_file.write_text(yaml.dump(wo))
    # monkeypatch create_clc_wo to avoid real fs writes
    from bridge.core import wo_processor_v5
    wo_paths = []
    monkeypatch.setattr(wo_processor_v5, "create_clc_wo", lambda w, ops: wo_paths.append("mock.yaml") or "mock.yaml")
    result = process_wo_with_lane_routing(str(wo_file))
    assert result.status.value in ("COMPLETED", "FAILED")  # allow error paths but must attempt STRICT routing
    assert result.clc_wo_path == "mock.yaml"
    assert len(result.strict_operations) == 1
```

### Health Check — JSON Contract
```python
import json, subprocess

def test_health_json_contract(tmp_path, monkeypatch):
    script = "tools/check_mary_gateway_health.zsh"
    # monkeypatch launchctl/ps/stat/find via PATH stubs if needed
    output = subprocess.check_output(["zsh", script])
    data = json.loads(output)
    assert "status" in data
    assert "launchagent" in data
    assert "process" in data
    assert "inbox_consumption" in data
    assert isinstance(data.get("backlog_count"), int)
```

---

## 🚦 Quality Gates (Auto)
- Score target: ≥ 90/100
- Xfail allowed: only multi-file SIP placeholder
- Auto-redesign if tests fail or score < 90

---

## 📌 Notes
- No actual test files created in this dry-run; this is the blueprint.
- Multi-file SIP tests marked xfail until Block 4 is implemented.

---

**Status:** ✅ DRY-RUN Complete — Ready for IMPLEMENT (test code generation)\n

