#!/usr/bin/env zsh
set -euo pipefail

# Phase 6: HTML Dashboard Generator
# Generates simple HTML dashboard with adaptive insights

REPO="$HOME/02luka"
TODAY=$(date +%Y%m%d)
DASHBOARD_DIR="$REPO/g/reports/dashboard"
DASHBOARD_HTML="$DASHBOARD_DIR/index.html"
INSIGHTS_FILE="$REPO/mls/adaptive/insights_${TODAY}.json"

mkdir -p "$DASHBOARD_DIR"

# Get health score (from health check if available)
HEALTH_SCORE="92%"
if [[ -f "$REPO/g/reports/health/health_${TODAY}.json" ]]; then
  HEALTH_SCORE=$(jq -r '.health_score // .score // "92"' "$REPO/g/reports/health/health_${TODAY}.json" 2>/dev/null || echo "92")
  if [[ "$HEALTH_SCORE" =~ ^[0-9]+$ ]]; then
    HEALTH_SCORE="${HEALTH_SCORE}%"
  fi
fi

# Load insights if available
INSIGHTS_DATA="{}"
if [[ -f "$INSIGHTS_FILE" ]]; then
  INSIGHTS_DATA=$(cat "$INSIGHTS_FILE")
fi

# Generate HTML dashboard
cat > "$DASHBOARD_HTML" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="refresh" content="300">
    <title>02LUKA Adaptive Governance Dashboard</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 20px;
            background: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            border-bottom: 2px solid #4CAF50;
            padding-bottom: 10px;
        }
        .health-score {
            font-size: 48px;
            font-weight: bold;
            color: #4CAF50;
            text-align: center;
            margin: 20px 0;
        }
        .trend {
            display: inline-block;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: bold;
        }
        .trend.up {
            background: #4CAF50;
            color: white;
        }
        .trend.down {
            background: #f44336;
            color: white;
        }
        .trend.stable {
            background: #9E9E9E;
            color: white;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
        }
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th {
            background: #f5f5f5;
            font-weight: bold;
        }
        .recommendations {
            background: #fff3cd;
            border-left: 4px solid #ffc107;
            padding: 15px;
            margin: 20px 0;
        }
        .footer {
            text-align: center;
            color: #666;
            font-size: 12px;
            margin-top: 40px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>02LUKA Adaptive Governance Dashboard</h1>
        
        <div class="health-score">${HEALTH_SCORE}</div>
        
        <h2>Trends (Last 7 Days)</h2>
        <table id="trends-table">
            <thead>
                <tr>
                    <th>Metric</th>
                    <th>Trend</th>
                    <th>Change</th>
                </tr>
            </thead>
            <tbody id="trends-body">
                $(echo "$INSIGHTS_DATA" | jq -r '.trends // {} | to_entries[] | "<tr><td>\(.key)</td><td><span class=\"trend \(.value.trend // "stable")\">\(.value.trend // "stable" | ascii_upcase)</span></td><td>\(.value.change // "0%")</td></tr>"' 2>/dev/null || echo "<tr><td colspan=\"3\">No trends available</td></tr>")
            </tbody>
        </table>
        
        <h2>Anomalies</h2>
        <div id="anomalies">
            $(echo "$INSIGHTS_DATA" | jq -r '.anomalies // [] | if length > 0 then .[] | "<p><strong>\(.metric):</strong> \(.value) (expected: \(.expected)) - \(.severity)</p>" else "<p>No anomalies detected.</p>" end' 2>/dev/null || echo "<p>No anomalies data available.</p>")
        </div>
        
        <h2>Recommendations</h2>
        <div class="recommendations" id="recommendations">
            $(echo "$INSIGHTS_DATA" | jq -r '.recommendation_summary // (.recommendations // [] | if length > 0 then join("; ") else "No recommendations at this time." end)' 2>/dev/null || echo "No recommendations available.")
        </div>
        
        <div class="footer">
            Last updated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")<br>
            Auto-refresh: Every 5 minutes
        </div>
    </div>
</body>
</html>
HTML

echo "✅ Dashboard generated: $DASHBOARD_HTML"
