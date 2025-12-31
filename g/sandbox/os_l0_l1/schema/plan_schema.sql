PRAGMA foreign_keys = ON;

-- Plan catalog
CREATE TABLE IF NOT EXISTS plans (
  plan_id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  owner_agent TEXT NOT NULL,
  status TEXT NOT NULL,
  version INTEGER NOT NULL DEFAULT 1,
  created_ts TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_ts TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

-- Plan items
CREATE TABLE IF NOT EXISTS plan_items (
  item_id TEXT PRIMARY KEY,
  plan_id TEXT NOT NULL,
  kind TEXT NOT NULL,
  title TEXT NOT NULL,
  state TEXT NOT NULL,
  priority INTEGER NOT NULL,
  assigned_to TEXT,
  due_ts TEXT,
  exec_ready_ts TEXT,
  exec_status TEXT NOT NULL DEFAULT 'NONE',
  exec_request_ts TEXT,
  exec_result_ts TEXT,
  exec_result_json TEXT,
  exec_error TEXT,
  version INTEGER NOT NULL DEFAULT 1,
  created_ts TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_ts TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  FOREIGN KEY (plan_id) REFERENCES plans (plan_id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_plan_items_plan_id ON plan_items(plan_id);
CREATE INDEX IF NOT EXISTS idx_plan_items_state ON plan_items(state);

-- Optional links between items (dependencies/related)
CREATE TABLE IF NOT EXISTS plan_links (
  link_id TEXT PRIMARY KEY,
  from_item_id TEXT NOT NULL,
  to_item_id TEXT NOT NULL,
  link_type TEXT NOT NULL,
  FOREIGN KEY (from_item_id) REFERENCES plan_items (item_id) ON DELETE CASCADE,
  FOREIGN KEY (to_item_id) REFERENCES plan_items (item_id) ON DELETE CASCADE
);

-- Optional plan-level metadata key-values
CREATE TABLE IF NOT EXISTS plan_meta (
  plan_id TEXT NOT NULL,
  key TEXT NOT NULL,
  value_json TEXT NOT NULL,
  updated_ts TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  PRIMARY KEY (plan_id, key),
  FOREIGN KEY (plan_id) REFERENCES plans (plan_id) ON DELETE CASCADE
);

-- L1-style append-only events with hash-chain
CREATE TABLE IF NOT EXISTS events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id TEXT,
  task_id TEXT,
  actor TEXT,
  event_type TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  created_ts TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  prev_hash TEXT,
  curr_hash TEXT
);
CREATE INDEX IF NOT EXISTS idx_events_event_type ON events(event_type);
CREATE INDEX IF NOT EXISTS idx_events_session ON events(session_id);

-- Chain state for tracking the latest hash head
CREATE TABLE IF NOT EXISTS chain_state (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
INSERT OR IGNORE INTO chain_state(key, value) VALUES ('latest_hash', '');
