#!/usr/bin/env zsh
# Trading Snapshot Function with Filter-Aware Filenames
# Includes filter parameters (market, account, scenario, tag) in snapshot filenames
# Prevents silent overwrites when different filter combinations are used

set -euo pipefail

# Helper function to normalize filter values for filenames
normalize_filter_value() {
    local value="$1"
    # Convert to lowercase, replace spaces with underscores, remove special chars, truncate
    echo "$value" | \
        tr '[:upper:]' '[:lower:]' | \
        sed 's/[^a-z0-9_-]//g' | \
        sed 's/  */_/g' | \
        cut -c1-20
}

# Snapshot function with filter-aware filename generation
snapshot_with_filters() {
    local range_from="$1"
    local range_to="$2"
    local market="${3:-}"
    local account="${4:-}"
    local scenario="${5:-}"
    local tag="${6:-}"
    local snapshot_json="${7:-}"
    local REPORT_DIR="${8:-g/reports/trading}"

    # Normalize JSON
    local normalized=$(printf '%s\n' "$snapshot_json" | jq -S '.')
    
    # Generate range slug (assuming this function exists)
    local slug=$(snapshot_range_slug "$range_from" "$range_to" 2>/dev/null || echo "${range_from}_${range_to}")

    # Build filter suffix
    local filter_parts=()
    [[ -n "$market" ]] && filter_parts+=("mkt_$(normalize_filter_value "$market")")
    [[ -n "$account" ]] && filter_parts+=("acc_$(normalize_filter_value "$account")")
    [[ -n "$scenario" ]] && filter_parts+=("scn_$(normalize_filter_value "$scenario")")
    [[ -n "$tag" ]] && filter_parts+=("tag_$(normalize_filter_value "$tag")")

    local filter_suffix=""
    if [[ ${#filter_parts[@]} -gt 0 ]]; then
        filter_suffix="_$(IFS='_'; echo "${filter_parts[*]}")"
    fi

    local base_name="trading_snapshot_${slug}${filter_suffix}"
    local json_path="$REPORT_DIR/${base_name}.json"

    # Handle collisions
    if [[ -f "$json_path" ]]; then
        local timestamp=$(date '+%Y%m%d_%H%M%S')
        json_path="$REPORT_DIR/${base_name}_${timestamp}.json"
        echo "Warning: File exists, appending timestamp: $(basename "$json_path")" >&2
    fi

    # Write JSON file
    echo "$normalized" > "$json_path"
    
    # Generate markdown if needed (with same collision handling)
    local md_path="$REPORT_DIR/${base_name}.md"
    if [[ -f "$md_path" ]]; then
        local timestamp=$(date '+%Y%m%d_%H%M%S')
        md_path="$REPORT_DIR/${base_name}_${timestamp}.md"
    fi
    
    # Generate markdown content (placeholder - adjust as needed)
    {
        echo "# Trading Snapshot: ${base_name}"
        echo ""
        echo "**Date Range:** ${range_from} to ${range_to}"
        [[ -n "$market" ]] && echo "**Market:** $market"
        [[ -n "$account" ]] && echo "**Account:** $account"
        [[ -n "$scenario" ]] && echo "**Scenario:** $scenario"
        [[ -n "$tag" ]] && echo "**Tag:** $tag"
        echo ""
        echo "## Data"
        echo "\`\`\`json"
        echo "$normalized"
        echo "\`\`\`"
    } > "$md_path"

    echo "✅ Snapshot created: $json_path"
    echo "✅ Markdown created: $md_path"
    
    echo "$json_path"
}
