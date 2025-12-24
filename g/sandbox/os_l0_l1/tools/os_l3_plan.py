#!/usr/bin/env python3
"""
Sandbox-only CLI for 02LUKA OS Layer 3 Plan P0.

Commands:
- init-db [--db PATH] [--force]
- list-plans [--db PATH]
- show-plan --plan-id ID [--db PATH]
- list-items --plan-id ID [--db PATH]
- apply-scenario PATH [--db PATH]
- verify-chain [--db PATH]
"""

import argparse
import hashlib
import json
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Tuple


def find_repo_root(start: Path) -> Path:
    cur = start
    for parent in [cur] + list(cur.parents):
        if parent.joinpath(".git").exists():
            return parent
    return start


REPO_ROOT = find_repo_root(Path(__file__).resolve())
DEFAULT_DB = REPO_ROOT / "g/sandbox/os_l0_l1/data/os_sandbox.db"
SCHEMA_PATH = REPO_ROOT / "g/sandbox/os_l0_l1/schema/plan_schema.sql"
SCENARIO_ROOT = REPO_ROOT / "g/sandbox/os_l0_l1/scenarios"


def iso_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def compute_hash(prev_hash: str, created_ts: str, event_type: str, payload_json: str) -> str:
    body = "|".join([prev_hash or "", created_ts, event_type, payload_json])
    return hashlib.sha256(body.encode("utf-8")).hexdigest()


def connect_db(path: Path) -> sqlite3.Connection:
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON;")
    return conn


def ensure_schema(conn: sqlite3.Connection) -> None:
    if not SCHEMA_PATH.exists():
        raise SystemExit(f"Schema file missing: {SCHEMA_PATH}")
    with open(SCHEMA_PATH, "r", encoding="utf-8") as fh:
        conn.executescript(fh.read())


def record_event(
    conn: sqlite3.Connection,
    *,
    event_type: str,
    payload: Dict[str, Any],
    actor: str = "",
    session_id: str = "",
    task_id: str = "",
) -> str:
    created_ts = iso_now()
    payload_json = json.dumps(payload, sort_keys=True)
    prev_row = conn.execute("SELECT value FROM chain_state WHERE key = 'latest_hash'").fetchone()
    prev_hash = prev_row["value"] if prev_row else ""
    curr_hash = compute_hash(prev_hash, created_ts, event_type, payload_json)
    conn.execute(
        """
        INSERT INTO events(session_id, task_id, actor, event_type, payload_json, created_ts, prev_hash, curr_hash)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (session_id, task_id, actor, event_type, payload_json, created_ts, prev_hash, curr_hash),
    )
    conn.execute(
        "INSERT OR REPLACE INTO chain_state(key, value) VALUES('latest_hash', ?)",
        (curr_hash,),
    )
    return curr_hash


def init_db(db_path: Path, *, force: bool) -> Dict[str, Any]:
    if db_path.exists() and force:
        db_path.unlink()
    conn = connect_db(db_path)
    with conn:
        ensure_schema(conn)
    return {"db_path": str(db_path), "initialized": True}


def create_plan(conn: sqlite3.Connection, plan: Dict[str, Any], session_id: str, task_id: str) -> Dict[str, Any]:
    plan_id = plan["plan_id"]
    existing = conn.execute("SELECT plan_id FROM plans WHERE plan_id = ?", (plan_id,)).fetchone()
    if existing:
        raise ValueError(f"Plan already exists: {plan_id}")
    now_ts = iso_now()
    conn.execute(
        """
        INSERT INTO plans(plan_id, title, owner_agent, status, version, created_ts, updated_ts)
        VALUES (?, ?, ?, ?, 1, ?, ?)
        """,
        (plan_id, plan["title"], plan["owner_agent"], plan.get("status", "ACTIVE"), now_ts, now_ts),
    )
    record_event(
        conn,
        event_type="PLAN_CREATED",
        payload={
            "plan_id": plan_id,
            "title": plan["title"],
            "owner_agent": plan["owner_agent"],
            "status": plan.get("status", "ACTIVE"),
            "version": 1,
        },
        actor=plan.get("actor", "") or plan.get("owner_agent", ""),
        session_id=session_id,
        task_id=task_id,
    )
    return {"plan_id": plan_id, "version": 1}


def add_item(conn: sqlite3.Connection, item: Dict[str, Any], session_id: str, task_id: str) -> Dict[str, Any]:
    item_id = item["item_id"]
    plan_id = item["plan_id"]
    plan = conn.execute("SELECT plan_id FROM plans WHERE plan_id = ?", (plan_id,)).fetchone()
    if not plan:
        raise ValueError(f"Plan not found: {plan_id}")
    existing = conn.execute("SELECT item_id FROM plan_items WHERE item_id = ?", (item_id,)).fetchone()
    if existing:
        raise ValueError(f"Item already exists: {item_id}")
    now_ts = iso_now()
    conn.execute(
        """
        INSERT INTO plan_items(item_id, plan_id, kind, title, state, priority, assigned_to, due_ts, version, created_ts, updated_ts)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)
        """,
        (
            item_id,
            plan_id,
            item["kind"],
            item["title"],
            item["state"],
            int(item.get("priority", 0)),
            item.get("assigned_to"),
            item.get("due_ts"),
            now_ts,
            now_ts,
        ),
    )
    record_event(
        conn,
        event_type="PLAN_ITEM_ADDED",
        payload={
            "plan_id": plan_id,
            "item_id": item_id,
            "kind": item["kind"],
            "title": item["title"],
            "state": item["state"],
            "priority": int(item.get("priority", 0)),
            "assigned_to": item.get("assigned_to"),
            "due_ts": item.get("due_ts"),
            "version": 1,
        },
        actor=item.get("actor", "") or item.get("assigned_to", "") or "",
        session_id=session_id,
        task_id=task_id,
    )
    return {"item_id": item_id, "version": 1}


def update_item_fields(
    conn: sqlite3.Connection,
    *,
    item_id: str,
    patch: Dict[str, Any],
    expected_version: int,
    actor: str,
    session_id: str,
    task_id: str,
) -> Dict[str, Any]:
    row = conn.execute(
        """
        SELECT item_id, plan_id, kind, title, state, priority, assigned_to, due_ts, version
        FROM plan_items WHERE item_id = ?
        """,
        (item_id,),
    ).fetchone()
    if not row:
        raise ValueError(f"Item not found: {item_id}")
    if row["version"] != expected_version:
        record_event(
            conn,
            event_type="PLAN_CONFLICT_DETECTED",
            payload={
                "plan_id": row["plan_id"],
                "item_id": item_id,
                "expected_version": expected_version,
                "current_version": row["version"],
                "attempted_patch": patch,
            },
            actor=actor,
            session_id=session_id,
            task_id=task_id,
        )
        return {
            "item_id": item_id,
            "status": "conflict",
            "expected_version": expected_version,
            "current_version": row["version"],
        }

    allowed_keys = {"title", "priority", "assigned_to", "due_ts", "kind"}
    updates: Dict[str, Any] = {}
    changes: Dict[str, Dict[str, Any]] = {}
    for key, val in patch.items():
        if key not in allowed_keys:
            continue
        current = row[key]
        new_val = int(val) if key == "priority" and val is not None else val
        if new_val != current:
            updates[key] = new_val
            changes[key] = {"from": current, "to": new_val}

    if not updates:
        return {"item_id": item_id, "status": "noop"}

    new_version = row["version"] + 1
    now_ts = iso_now()
    set_clause = ", ".join([f"{k} = ?" for k in updates.keys()]) + ", version = ?, updated_ts = ?"
    params: List[Any] = list(updates.values()) + [new_version, now_ts, item_id]
    conn.execute(f"UPDATE plan_items SET {set_clause} WHERE item_id = ?", params)
    record_event(
        conn,
        event_type="PLAN_ITEM_UPDATED",
        payload={
            "plan_id": row["plan_id"],
            "item_id": item_id,
            "changes": changes,
            "expected_version": expected_version,
            "new_version": new_version,
        },
        actor=actor,
        session_id=session_id,
        task_id=task_id,
    )
    return {"item_id": item_id, "status": "updated", "version": new_version, "changes": changes}


def update_item_state(
    conn: sqlite3.Connection,
    *,
    item_id: str,
    to_state: str,
    expected_version: int,
    actor: str,
    session_id: str,
    task_id: str,
) -> Dict[str, Any]:
    row = conn.execute(
        "SELECT item_id, plan_id, state, version FROM plan_items WHERE item_id = ?",
        (item_id,),
    ).fetchone()
    if not row:
        raise ValueError(f"Item not found: {item_id}")
    if row["version"] != expected_version:
        record_event(
            conn,
            event_type="PLAN_CONFLICT_DETECTED",
            payload={
                "plan_id": row["plan_id"],
                "item_id": item_id,
                "expected_version": expected_version,
                "current_version": row["version"],
                "attempted_state": to_state,
            },
            actor=actor,
            session_id=session_id,
            task_id=task_id,
        )
        return {
            "item_id": item_id,
            "status": "conflict",
            "expected_version": expected_version,
            "current_version": row["version"],
        }
    new_version = row["version"] + 1
    now_ts = iso_now()
    conn.execute(
        """
        UPDATE plan_items
        SET state = ?, version = ?, updated_ts = ?
        WHERE item_id = ?
        """,
        (to_state, new_version, now_ts, item_id),
    )
    record_event(
        conn,
        event_type="PLAN_ITEM_STATE_CHANGED",
        payload={
            "plan_id": row["plan_id"],
            "item_id": item_id,
            "from_state": row["state"],
            "to_state": to_state,
            "expected_version": expected_version,
            "new_version": new_version,
        },
        actor=actor,
        session_id=session_id,
        task_id=task_id,
    )
    return {
        "item_id": item_id,
        "status": "updated",
        "from_state": row["state"],
        "to_state": to_state,
        "version": new_version,
    }


def list_plans(conn: sqlite3.Connection) -> List[Dict[str, Any]]:
    rows = conn.execute(
        "SELECT plan_id, title, owner_agent, status, version, created_ts, updated_ts FROM plans ORDER BY created_ts ASC"
    ).fetchall()
    return [dict(row) for row in rows]


def list_items(conn: sqlite3.Connection, plan_id: str) -> List[Dict[str, Any]]:
    rows = conn.execute(
        """
        SELECT item_id, plan_id, kind, title, state, priority, assigned_to, due_ts, version, created_ts, updated_ts
        FROM plan_items
        WHERE plan_id = ?
        ORDER BY created_ts ASC
        """,
        (plan_id,),
    ).fetchall()
    return [dict(row) for row in rows]


def show_plan(conn: sqlite3.Connection, plan_id: str) -> Dict[str, Any]:
    plan = conn.execute(
        "SELECT plan_id, title, owner_agent, status, version, created_ts, updated_ts FROM plans WHERE plan_id = ?",
        (plan_id,),
    ).fetchone()
    if not plan:
        raise ValueError(f"Plan not found: {plan_id}")
    return {
        "plan": dict(plan),
        "items": list_items(conn, plan_id),
    }


def validate_scenario_path(path_str: str) -> Path:
    user_path = Path(path_str)
    if user_path.parts and user_path.parts[0] == "scenarios":
        user_path = Path(*user_path.parts[1:])
    if user_path.is_absolute():
        raise ValueError("Scenario path must be relative (no absolute paths allowed).")
    if ".." in user_path.parts:
        raise ValueError("Scenario path must not contain '..'.")
    resolved = (SCENARIO_ROOT / user_path).resolve()
    if not str(resolved).startswith(str(SCENARIO_ROOT.resolve())):
        raise ValueError("Scenario path must stay within the scenarios directory.")
    if not resolved.exists():
        raise ValueError(f"Scenario file not found: {resolved}")
    return resolved


def load_scenario(path: Path) -> Dict[str, Any]:
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def apply_scenario(conn: sqlite3.Connection, scenario: Dict[str, Any]) -> Dict[str, Any]:
    session_id = scenario.get("session_id", "L3_PLAN_P0_SESSION")
    task_id = scenario.get("task_id", "L3_PLAN_P0_TASK")
    results: Dict[str, Any] = {
        "plan_created": False,
        "items_added": 0,
        "state_changes": 0,
        "item_updates": 0,
        "conflicts": 0,
        "events_written": 0,
    }
    # Count events before
    before_events = conn.execute("SELECT COUNT(1) AS c FROM events").fetchone()["c"]

    with conn:
        ensure_schema(conn)
        plan_info = scenario["plan"]
        create_plan(conn, plan_info, session_id, task_id)
        results["plan_created"] = True

        for item in scenario.get("items", []):
            add_item(conn, item, session_id, task_id)
            results["items_added"] += 1

        for upd in scenario.get("updates", []):
            res = update_item_fields(
                conn,
                item_id=upd["item_id"],
                patch=upd.get("patch", {}),
                expected_version=int(upd["expected_version"]),
                actor=upd.get("actor", ""),
                session_id=session_id,
                task_id=task_id,
            )
            if res.get("status") == "conflict":
                results["conflicts"] += 1
            elif res.get("status") == "updated":
                results["item_updates"] += 1

        for tx in scenario.get("transitions", []):
            res = update_item_state(
                conn,
                item_id=tx["item_id"],
                to_state=tx["to_state"],
                expected_version=int(tx["expected_version"]),
                actor=tx.get("actor", ""),
                session_id=session_id,
                task_id=task_id,
            )
            if res.get("status") == "conflict":
                results["conflicts"] += 1
            else:
                results["state_changes"] += 1

        for cf in scenario.get("conflicts", []):
            res = update_item_state(
                conn,
                item_id=cf["item_id"],
                to_state=cf.get("patch", {}).get("state", "PENDING"),
                expected_version=int(cf["expected_version"]),
                actor=cf.get("actor", ""),
                session_id=session_id,
                task_id=task_id,
            )
            if res.get("status") == "conflict":
                results["conflicts"] += 1
            else:
                results["state_changes"] += 1

    after_events = conn.execute("SELECT COUNT(1) AS c FROM events").fetchone()["c"]
    results["events_written"] = after_events - before_events
    results["session_id"] = session_id
    results["task_id"] = task_id
    return results


def verify_chain(conn: sqlite3.Connection) -> Dict[str, Any]:
    rows = conn.execute(
        "SELECT id, event_type, payload_json, prev_hash, curr_hash, created_ts FROM events ORDER BY id ASC"
    ).fetchall()
    prev_hash = ""
    mismatches: List[Dict[str, Any]] = []
    for row in rows:
        payload_json = row["payload_json"]
        computed = compute_hash(prev_hash, row["created_ts"], row["event_type"], payload_json)
        if row["prev_hash"] != prev_hash or row["curr_hash"] != computed:
            mismatches.append(
                {
                    "id": row["id"],
                    "expected_prev": prev_hash,
                    "stored_prev": row["prev_hash"],
                    "expected_curr": computed,
                    "stored_curr": row["curr_hash"],
                }
            )
        prev_hash = row["curr_hash"]
    status = "OK" if not mismatches else "CORRUPTED"
    return {"chain_status": status, "events": len(rows), "mismatches": mismatches}


def json_print(data: Any) -> None:
    print(json.dumps(data, indent=2, sort_keys=True))


def main(argv: List[str]) -> int:
    parser = argparse.ArgumentParser(description="02LUKA OS L3 Plan P0 (sandbox CLI)")
    parser.add_argument("--db", default=str(DEFAULT_DB), help="Path to sandbox DB (default: %(default)s)")
    sub = parser.add_subparsers(dest="command", required=True)

    p_init = sub.add_parser("init-db", help="Initialize sandbox DB (drops existing if --force)")
    p_init.add_argument("--force", action="store_true", help="Drop existing DB before init")

    sub.add_parser("list-plans", help="List plans")

    p_show = sub.add_parser("show-plan", help="Show plan + items")
    p_show.add_argument("--plan-id", required=True)

    p_items = sub.add_parser("list-items", help="List items for a plan")
    p_items.add_argument("--plan-id", required=True)

    p_apply = sub.add_parser("apply-scenario", help="Apply scenario JSON")
    p_apply.add_argument("scenario_path", help="Relative path under scenarios/")

    sub.add_parser("verify-chain", help="Verify hash-chain integrity")

    args = parser.parse_args(argv)
    db_path = Path(args.db)

    if args.command == "init-db":
        result = init_db(db_path, force=args.force)
        json_print(result)
        return 0

    conn = connect_db(db_path)

    if args.command == "list-plans":
        ensure_schema(conn)
        json_print({"plans": list_plans(conn)})
        return 0
    if args.command == "show-plan":
        ensure_schema(conn)
        json_print(show_plan(conn, args.plan_id))
        return 0
    if args.command == "list-items":
        ensure_schema(conn)
        json_print({"items": list_items(conn, args.plan_id)})
        return 0
    if args.command == "apply-scenario":
        scenario_path = validate_scenario_path(args.scenario_path)
        scenario = load_scenario(scenario_path)
        ensure_schema(conn)
        result = apply_scenario(conn, scenario)
        json_print(result)
        return 0
    if args.command == "verify-chain":
        ensure_schema(conn)
        result = verify_chain(conn)
        json_print(result)
        return 0 if result.get("chain_status") == "OK" else 1

    parser.error("Unknown command")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
