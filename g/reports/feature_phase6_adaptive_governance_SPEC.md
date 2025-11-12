# Feature SPEC: Phase 6 - Adaptive Governance & Predictive Analytics

**Feature ID:** `phase6_adaptive_governance`  
**Version:** 1.0.0  
**Date:** 2025-11-12  
**Status:** Ready for Development

---

## Objective

Build an adaptive governance layer that learns from system behavior, predicts trends, and automatically improves itself through a closed-loop feedback system. This phase integrates Claude Code metrics, R&D proposal outcomes, and Mary execution patterns to create predictive insights and an operational dashboard.

---

## Problem Statement

**Current State:**
- Phase 5 provides governance and reporting, but it's reactive
- Metrics are collected but not analyzed for trends
- No predictive capabilities to anticipate issues
- No unified dashboard for real-time system health
- R&D proposals and Claude Code improvements happen in isolation

**Desired State:**
- Proactive governance with trend prediction
- Adaptive insights that learn from patterns
- Unified dashboard showing real-time system health
- Auto-improvement loop connecting metrics → insights → actions
- Predictive analytics to prevent issues before they occur

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│              Phase 6: Adaptive Governance                │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────┐ │
│  │   Metrics    │    │   Adaptive   │    │Predictive│ │
│  │  Collector   │───▶│   Insights   │───▶│ Analytics │ │
│  │              │    │   Engine     │    │  Engine   │ │
│  └──────────────┘    └──────────────┘    └──────────┘ │
│         │                    │                   │       │
│         │                    │                   │       │
│         ▼                    ▼                   ▼       │
│  ┌──────────────────────────────────────────────────┐  │
│  │         Redis Pub/Sub: governance:insight          │  │
│  └──────────────────────────────────────────────────┘  │
│         │                    │                   │       │
│         ▼                    ▼                   ▼       │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────┐ │
│  │   Daily      │    │   HTML       │    │   Auto   │ │
│  │   Digest     │    │  Dashboard   │    │Improvement│ │
│  │  (Enhanced)  │    │  (Real-time) │    │   Loop   │ │
│  └──────────────┘    └──────────────┘    └──────────┘ │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## Core Components

### 1. Adaptive Insight Collector (`tools/adaptive_collector.zsh`)

**Purpose:** Collect and analyze metrics from multiple sources to generate adaptive insights.

**Inputs:**
- Claude Code metrics (from `memory:agents:claude`)
- R&D proposal outcomes (from `memory:agents:rnd`)
- Mary execution patterns (from `memory:agents:mary`)
- Historical trends (from monthly metrics JSON files)

**Processing:**
- Calculate trend slopes (improving/declining/stable)
- Detect anomalies (spikes, drops, patterns)
- Identify correlations between metrics
- Generate confidence scores for predictions

**Outputs:**
- JSON insights file: `mls/adaptive/insights_YYYYMMDD.json`
- Redis pub/sub: `governance:insight` channel
- Markdown summary: `g/reports/adaptive_insights_YYYYMMDD.md`

**Key Features:**
- Trend detection (7-day, 30-day windows)
- Anomaly detection (statistical outliers)
- Correlation analysis (which metrics move together)
- Prediction confidence scoring (0-100%)

---

### 2. Predictive Analytics Engine (`tools/predictive_analytics.zsh`)

**Purpose:** Predict future system behavior based on historical patterns.

**Capabilities:**
- **Trend Prediction:** Forecast metric values 7/30 days ahead
- **Risk Assessment:** Identify metrics approaching thresholds
- **Pattern Recognition:** Detect recurring patterns (daily/weekly cycles)
- **Recommendation Generation:** Suggest actions based on predictions

**Outputs:**
- Predictions JSON: `mls/adaptive/predictions_YYYYMMDD.json`
- Risk alerts: Published to `governance:risk` channel
- Recommendations: Included in daily digest

**Algorithms:**
- Simple linear regression for trend prediction
- Moving averages for smoothing
- Z-score for anomaly detection
- Correlation coefficients for relationship analysis

---

### 3. HTML Dashboard (`tools/dashboard_generator.zsh`)

**Purpose:** Generate real-time HTML dashboard for system monitoring.

**Features:**
- **Real-time Metrics:** Live data from Redis
- **Trend Charts:** Visual representation of metrics over time
- **Health Score:** Overall system health indicator
- **Agent Status:** Status of all agents (Mary, R&D, Claude, etc.)
- **Predictive Insights:** Upcoming predictions and risks
- **Action Items:** Recommended actions from adaptive insights

**Output:**
- HTML file: `g/reports/dashboard/index.html`
- Auto-refresh: Every 60 seconds
- Accessible via: `ops.theedges.work` or `dashboard.theedges.work`

**Technologies:**
- HTML5 + CSS3
- Chart.js for visualizations
- JavaScript for real-time updates
- Redis WebSocket or polling for live data

---

### 4. Auto-Improvement Loop (`tools/auto_improvement_loop.zsh`)

**Purpose:** Automatically create R&D proposals based on adaptive insights.

**Workflow:**
1. Receive adaptive insights from collector
2. Identify improvement opportunities (low scores, declining trends)
3. Generate R&D proposal automatically
4. Submit to R&D inbox (`bridge/inbox/RND/`)
5. Track proposal outcome
6. Learn from results (update confidence scores)

**Integration Points:**
- R&D Consumer: Processes auto-generated proposals
- Mary Dispatcher: Executes approved improvements
- MLS: Records outcomes for learning

**Safety:**
- Only auto-generate for low-risk changes
- Require human approval for high-risk proposals
- Track success rate of auto-proposals

---

### 5. Enhanced Daily Digest

**Purpose:** Add "Adaptive Insights" section to existing daily digest.

**New Section:**
```markdown
## Adaptive Insights

### Trend Analysis
- Claude Code hook success rate: Improving (+5% over 7 days)
- R&D proposal acceptance: Stable (85% average)
- Mary task completion: Declining (-2% over 7 days) ⚠️

### Predictions
- Health score expected to drop to 88% in 3 days (current: 92%)
- R&D proposal volume expected to increase 15% next week

### Recommendations
- Investigate Mary task completion decline
- Review Claude Code hook failures (3 in last 24h)
```

**Integration:**
- Modify `tools/memory_daily_digest.zsh`
- Read from `mls/adaptive/insights_YYYYMMDD.json`
- Append adaptive insights section

---

## Data Flow

### Collection Flow
```
Claude Metrics → Redis (memory:agents:claude)
R&D Outcomes → Redis (memory:agents:rnd)
Mary Patterns → Redis (memory:agents:mary)
     ↓
Adaptive Collector (tools/adaptive_collector.zsh)
     ↓
Insights JSON (mls/adaptive/insights_YYYYMMDD.json)
     ↓
Redis Pub/Sub (governance:insight)
```

### Prediction Flow
```
Historical Metrics (monthly JSON files)
     ↓
Predictive Analytics Engine
     ↓
Predictions JSON (mls/adaptive/predictions_YYYYMMDD.json)
     ↓
Risk Alerts (governance:risk channel)
     ↓
Daily Digest (Adaptive Insights section)
```

### Dashboard Flow
```
Redis (memory:agents:*)
     ↓
Dashboard Generator (tools/dashboard_generator.zsh)
     ↓
HTML Dashboard (g/reports/dashboard/index.html)
     ↓
Web Server (ops.theedges.work)
```

---

## Integration Points

### Phase 5 Integration
- **Governance Reports:** Include adaptive insights in weekly report
- **Health Checks:** Use predictions to warn of upcoming issues
- **Alert System:** Trigger alerts based on predicted risks

### R&D Integration
- **Auto-Proposals:** Generate R&D proposals from insights
- **Outcome Tracking:** Learn from proposal results
- **Feedback Loop:** Update confidence scores based on outcomes

### Claude Code Integration
- **Metrics Collection:** Use existing Claude Code metrics
- **Trend Analysis:** Analyze hook success rates, conflicts, reviews
- **Improvement Suggestions:** Recommend Claude Code improvements

---

## Success Criteria

### Functional Requirements
- ✅ Adaptive insights generated daily
- ✅ Predictions with >70% confidence for 7-day forecasts
- ✅ HTML dashboard accessible and auto-refreshing
- ✅ Daily digest includes adaptive insights section
- ✅ Auto-improvement loop generates proposals for low-risk improvements

### Performance Requirements
- Insight generation: < 30 seconds
- Dashboard load time: < 2 seconds
- Prediction accuracy: > 70% for 7-day forecasts
- Real-time updates: < 5 second latency

### Quality Requirements
- All insights include confidence scores
- All predictions include uncertainty ranges
- Dashboard shows data freshness timestamp
- Auto-proposals include risk assessment

---

## LaunchAgents

### 1. Adaptive Collector (Daily 06:30)
```xml
com.02luka.adaptive.collector.daily
- Runs: Daily 06:30 (after metrics collection)
- Script: tools/adaptive_collector.zsh
- Output: mls/adaptive/insights_YYYYMMDD.json
```

### 2. Predictive Analytics (Daily 07:00)
```xml
com.02luka.predictive.analytics.daily
- Runs: Daily 07:00 (after adaptive collector)
- Script: tools/predictive_analytics.zsh
- Output: mls/adaptive/predictions_YYYYMMDD.json
```

### 3. Dashboard Generator (Every 5 minutes)
```xml
com.02luka.dashboard.generator
- Runs: Every 5 minutes
- Script: tools/dashboard_generator.zsh
- Output: g/reports/dashboard/index.html
```

### 4. Auto-Improvement Loop (Every 30 minutes)
```xml
com.02luka.auto.improvement.loop
- Runs: Every 30 minutes
- Script: tools/auto_improvement_loop.zsh
- Output: R&D proposals in bridge/inbox/RND/
```

---

## Data Structures

### Adaptive Insights JSON
```json
{
  "date": "2025-11-12",
  "generated_at": "2025-11-12T07:00:00Z",
  "trends": {
    "claude_hook_success": {
      "direction": "improving",
      "slope": 0.05,
      "confidence": 0.85,
      "period": "7d"
    },
    "rnd_acceptance": {
      "direction": "stable",
      "slope": 0.0,
      "confidence": 0.92,
      "period": "7d"
    }
  },
  "anomalies": [
    {
      "metric": "mary_completion_rate",
      "value": 0.88,
      "expected": 0.95,
      "severity": "medium",
      "timestamp": "2025-11-12T06:00:00Z"
    }
  ],
  "correlations": [
    {
      "metric1": "claude_hook_success",
      "metric2": "rnd_acceptance",
      "coefficient": 0.72,
      "significance": "high"
    }
  ]
}
```

### Predictions JSON
```json
{
  "date": "2025-11-12",
  "generated_at": "2025-11-12T07:00:00Z",
  "predictions": [
    {
      "metric": "health_score",
      "current": 0.92,
      "forecast_7d": 0.88,
      "forecast_30d": 0.85,
      "confidence": 0.75,
      "uncertainty_range": [0.85, 0.91],
      "risk_level": "medium"
    }
  ],
  "risks": [
    {
      "metric": "mary_completion_rate",
      "threshold": 0.90,
      "predicted_value": 0.87,
      "days_until_threshold": 3,
      "severity": "high",
      "recommendation": "Investigate Mary task completion decline"
    }
  ]
}
```

---

## Security & Privacy

- **Data Access:** All insights stored in `mls/adaptive/` (internal)
- **Dashboard:** Accessible only via authenticated web server
- **Redis Channels:** Internal pub/sub, not exposed externally
- **Auto-Proposals:** Only low-risk changes auto-generated

---

## Dependencies

### External
- Redis (for pub/sub and metrics storage)
- Chart.js (for dashboard visualizations)
- jq (for JSON processing)
- bc (for calculations)

### Internal
- Phase 5 governance system
- R&D proposal system
- Mary dispatcher
- Claude Code metrics collector
- Daily digest generator

---

## Rollout Strategy

### Phase 6.1: Foundation (Week 1)
- Adaptive collector
- Basic trend detection
- Enhanced daily digest

### Phase 6.2: Predictions (Week 2)
- Predictive analytics engine
- Risk assessment
- Prediction accuracy tracking

### Phase 6.3: Dashboard (Week 3)
- HTML dashboard generator
- Real-time updates
- Web server integration

### Phase 6.4: Auto-Improvement (Week 4)
- Auto-improvement loop
- R&D proposal generation
- Outcome learning

---

## References

- **Phase 5 SPEC:** `g/reports/feature_phase5_governance_reporting_SPEC.md`
- **R&D System:** `g/reports/feature_rnd_autopilot_SPEC.md`
- **Claude Code Integration:** `g/reports/feature_claude_code_governance_integration_SPEC.md`
- **System Status:** `g/reports/SYSTEM_STATUS_phase5_20251112.md`

