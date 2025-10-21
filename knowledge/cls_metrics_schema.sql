-- CLS Performance Metrics Schema
-- Extends knowledge/02luka.db with CLS evaluation data

CREATE TABLE IF NOT EXISTS cls_metrics (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp TEXT NOT NULL,
  reasoning_speed REAL DEFAULT 0.0,
  memory_utilization REAL DEFAULT 0.0,
  learning_rate REAL DEFAULT 0.0,
  decision_quality REAL DEFAULT 0.0,
  error_rate REAL DEFAULT 0.0,
  audit_compliance REAL DEFAULT 0.0,
  design_adherence REAL DEFAULT 0.0,
  risk_detection REAL DEFAULT 0.0,
  cursor_sync REAL DEFAULT 0.0,
  gg_coordination REAL DEFAULT 0.0,
  mary_scheduling REAL DEFAULT 0.0,
  kb_update REAL DEFAULT 0.0,
  telemetry_analysis REAL DEFAULT 0.0,
  pattern_recognition REAL DEFAULT 0.0,
  adaptation_speed REAL DEFAULT 0.0,
  meta_cognition REAL DEFAULT 0.0,
  overall_score REAL DEFAULT 0.0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Index for performance queries
CREATE INDEX IF NOT EXISTS idx_cls_metrics_timestamp ON cls_metrics(timestamp);
CREATE INDEX IF NOT EXISTS idx_cls_metrics_score ON cls_metrics(overall_score);

-- View for recent performance trends
CREATE VIEW IF NOT EXISTS cls_performance_trends AS
SELECT 
  DATE(timestamp) as date,
  AVG(overall_score) as avg_score,
  AVG(reasoning_speed) as avg_reasoning,
  AVG(memory_utilization) as avg_memory,
  AVG(decision_quality) as avg_decision,
  COUNT(*) as evaluation_count
FROM cls_metrics 
WHERE timestamp >= date('now', '-30 days')
GROUP BY DATE(timestamp)
ORDER BY date DESC;
