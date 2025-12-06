from __future__ import annotations

import os
import re

from tools.lib.workflow_chain_utils import (
    determine_caller,
    generate_run_id,
    parse_gitdrop_snapshot_id,
)


def test_generate_run_id_format() -> None:
    run_id = generate_run_id()
    assert re.match(r"run_\d{8}_\d{6}_[0-9a-f]{6}$", run_id)


def test_determine_caller_variants() -> None:
    assert determine_caller({"CI": "true"}) == "ci"
    assert determine_caller({"LOCAL_REVIEW_ENABLED": "1"}) == "hook"
    assert determine_caller({"GIT_HOOK": "1"}) == "hook"
    assert determine_caller({}) == "manual"


def test_parse_gitdrop_snapshot_id() -> None:
    output = "[GitDrop] Snapshot 20251206_193005 created"
    assert parse_gitdrop_snapshot_id(output) == "20251206_193005"
    output2 = "Created 20251206_193006"
    assert parse_gitdrop_snapshot_id(output2) == "20251206_193006"
    assert parse_gitdrop_snapshot_id("no snapshot") is None
