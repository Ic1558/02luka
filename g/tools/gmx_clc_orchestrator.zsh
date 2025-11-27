#!/usr/bin/env zsh
#
# gmx_clc_orchestrator.zsh
#
# Role: The "brain" of the CLC system. This script is run periodically by launchd.
# It gathers system state, uses GMX (Gemini CLI) to reason about the state,
# and self-initiates Work Orders for the CLC Worker to execute.
#
# Version: 0.1.0 (Skeleton)

# --- Configuration ---
# Ensure the script runs from the project root
cd "$(dirname "$0")/../.." || exit 1
PROJECT_ROOT=$(pwd)
LOG_FILE="$PROJECT_ROOT/logs/gmx_clc_orchestrator.log"
HEALTH_CHECK_FILE="$PROJECT_ROOT/g/telemetry/health_check_latest.json"
ACK_DIR="$PROJECT_ROOT/bridge/outbox/LIAM"
SESSION_DIR="$PROJECT_ROOT/state/clc_sessions"
WO_INBOX_DIR="$PROJECT_ROOT/bridge/inbox/CLC"
GMX_PROFILE="clc-orchestrator" # Assumes a gmx profile is configured

# --- Security Configuration (AI:OP-001 Compliance) ---
# Paths where the orchestrator is allowed to create/modify files.
# All paths are relative to $PROJECT_ROOT.
SAFE_ZONES=(
    "g/tools/"
    "g/knowledge/clc/"
    "g/docs/"
    "g/telemetry/"
    "bridge/inbox/CLC/"
    "bridge/outbox/LIAM/"
    "logs/"
    "state/clc_sessions/" # Added for session management
)

# Paths where the orchestrator is strictly forbidden from creating/modifying files.
# All paths are relative to $PROJECT_ROOT.
FORBIDDEN_ZONES=(
    "CLC/"
    "CLS/"
    "core/"
    "ai-op/"
    # Note: "system launchd outside project root" is handled by LaunchAgent config and not directly here
)

# --- Logging ---
log() {
    echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") | $1" >> "$LOG_FILE"
}

# --- Main Logic Functions (Placeholders) ---

gather_context() {
    log "INFO: Gathering context..."
    local context_file
    context_file=$(mktemp)

    # V1: For now, we just note that we would gather context here.
    # In the future, this will read health checks, ACKs, and session files.
    
    echo "## CLC Orchestrator Context" > "$context_file"
    echo "Timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "$context_file"

    if [[ -f "$HEALTH_CHECK_FILE" ]]; then
        echo "\n### Latest Health Check" >> "$context_file"
        cat "$HEALTH_CHECK_FILE" >> "$context_file"
    else
        echo "\n### Latest Health Check\nFile not found." >> "$context_file"
    fi
    
    # TODO: Add logic to read active sessions from $SESSION_DIR
    # NOTE: Temporarily skipping ACK summary aggregation while parser issues are addressed.
    # local ack_summary=""
    # if [[ -d "$ACK_DIR" ]]; then
    #     local recent_acks_json="[]"
    #     # Get the 20 most recent ACK files, sorted by modification time
    #     local ack_files
    #     ack_files=$(ls -t "$ACK_DIR"/*.ack.json 2>/dev/null | head -n 20)
    #
    #     if [[ -n "$ack_files" ]]; then
    #         for ack_file in $ack_files; do
    #             local wo_id=$(jq -r '.wo_id // "N/A"' "$ack_file")
    #             local ack_status=$(jq -r '.status // "N/A"' "$ack_file")
    #             recent_acks_json=$(echo "$recent_acks_json" | jq ". + [{\"wo_id\": \"$wo_id\", \"status\": \"$ack_status\"}]")
    #         done
    #         ack_summary="\n### Recent CLC ACKs (Last 20)\n```json\n$(echo \"$recent_acks_json\" | jq .)\n```"
    #     else
    #         ack_summary="\n### Recent CLC ACKs (Last 20)\nNo recent ACK files found."
    #     fi
    # fi
    log "INFO: Skipping ACK summary (WIP)."
    # echo "$ack_summary" >> "$context_file"

    local session_summary=""
    if [[ -d "$SESSION_DIR" ]]; then
        local active_sessions_json="[]"
        # Get all session files
        local session_files
        session_files=$(ls "$SESSION_DIR"/*.yaml 2>/dev/null)

        if [[ -n "$session_files" ]]; then
            for session_file in $session_files; do
                local session_id=$(yq e '.session_id // "N/A"' "$session_file")
                local goal=$(yq e '.goal // "N/A"' "$session_file")
                local session_status=$(yq e '.status // "N/A"' "$session_file")
                active_sessions_json=$(echo "$active_sessions_json" | jq ". + [{\"session_id\": \"$session_id\", \"goal\": \"$goal\", \"status\": \"$session_status\"}]")
            done
            session_summary="\n### Active CLC Sessions\n\`\`\`json\n$(echo "$active_sessions_json" | jq .)\n\`\`\`"
        else
            session_summary="\n### Active CLC Sessions\nNo active session files found."
        fi
    fi
    echo "$session_summary" >> "$context_file"

    log "INFO: Context gathered into $context_file"
    echo "$context_file"
}

# --- Path Safety Validation ---
# Checks if a given path is within a SAFE_ZONE and not within a FORBIDDEN_ZONE.
# Arguments:
#   $1: The path to check (relative to PROJECT_ROOT)
# Returns:
#   0 if the path is safe, 1 otherwise.
is_path_safe() {
    local path=$1
    # Check if path is empty
    if [[ -z "$path" ]]; then
        log "WARN: Empty path provided for safety check. Rejecting."
        return 1
    fi

    local absolute_path
    # Try to resolve absolute path, handling potential errors for non-existent paths
    absolute_path=$(realpath -m "$PROJECT_ROOT/$path") # -m creates missing directories if they don't exist
    local project_root_abs=$(realpath "$PROJECT_ROOT")

    # Ensure the path is within the project root
    if [[ ! "$absolute_path" == "$project_root_abs"* ]]; then
        log "WARN: Path '$path' resolves to '$absolute_path' which is outside project root '$project_root_abs'. Rejecting."
        return 1
    fi

    # Check against forbidden zones first
    for f_zone in "${FORBIDDEN_ZONES[@]}"; do
        local forbidden_abs_path
        forbidden_abs_path=$(realpath -m "$PROJECT_ROOT/$f_zone")
        if [[ "$absolute_path" == "$forbidden_abs_path"* ]]; then
            log "WARN: Path '$path' resolves to '$absolute_path' which is inside forbidden zone '$f_zone'."
            return 1 # Not safe
        fi
    done

    # Check against safe zones
    for s_zone in "${SAFE_ZONES[@]}"; do
        local safe_abs_path
        safe_abs_path=$(realpath -m "$PROJECT_ROOT/$s_zone")
        if [[ "$absolute_path" == "$safe_abs_path"* ]]; then
            return 0 # Safe
        fi
    done

    log "WARN: Path '$path' resolves to '$absolute_path' which is not within any defined safe zone."
    return 1 # Not safe
}

invoke_gmx_planner() {
    local context_file=$1
    log "INFO: Invoking GMX planner with context file: $context_file"

    local gmx_output
    gmx_output=$(mktemp)

    if command -v gmx >/dev/null; then
        log "INFO: GMX CLI found. Attempting to call GMX for planning."
        
        # Actual GMX call
        if gmx run \
            --profile "$GMX_PROFILE" \
            --input-file "$context_file" \
            > "$gmx_output" 2>>"$LOG_FILE"; then # Redirect stderr to main log
            log "INFO: GMX planner call successful."
        else
            local gmx_exit_code=$?
            log "WARN: GMX planner call failed with exit code $gmx_exit_code. Falling back to mock plan."
            # Fallback to mock plan on GMX failure
            echo "work_orders: []" > "$gmx_output"
        fi
    else
        log "WARN: GMX CLI not found. Falling back to mock plan."
        # Fallback to mock plan if gmx not found
        echo "work_orders: []" > "$gmx_output"
    fi

    log "INFO: GMX planner output stored in: $gmx_output"
    echo "$gmx_output"
}

process_plan() {
    local plan_file=$1
    log "INFO: Processing plan file: $plan_file"
    
    local parsed_work_orders_json
    local parse_result

    # Call Python helper for robust YAML/JSON parsing and basic WO validation
    # v1.2: Fixed to use --input flag correctly
    local parser_output
    parser_output=$(python3 "$PROJECT_ROOT/g/tools/gmx_clc_parse_plan.py" --input "$plan_file" --quiet 2>&1)
    parse_result=$?
    
    # Extract candidates from parser output (it returns JSON with candidate_count, candidates, etc.)
    if [[ "$parse_result" -eq 0 ]]; then
        # Parser succeeded - extract candidates array
        parsed_work_orders_json=$(echo "$parser_output" | jq -c '.candidates // []')
    else
        parsed_work_orders_json="[]"

    if [[ "$parse_result" -ne 0 ]]; then
        log "ERROR: Failed to parse or validate GMX plan from $plan_file. Error: $(echo "$parsed_work_orders_json" | tr -d '\n')" # Log Python script's error output
        log "INFO: Plan processing aborted."
        return 1
    fi

    # Check if 'jq' is available
    if ! command -v jq >/dev/null; then
        log "ERROR: 'jq' command not found. Cannot process Work Orders. Please install 'jq'."
        return 1
    fi

    # Extract the number of work orders and their IDs
    local num_work_orders
    num_work_orders=$(echo "$parsed_work_orders_json" | jq '. | length')

    local dropped_wo_ids=()
    local dropped_count=0
    local dropped_wo_ids_json="[]"

    if [[ "$num_work_orders" -gt 0 ]]; then
        log "INFO: Plan contains $num_work_orders new Work Order(s). Starting validation and processing..."
        
        local valid_work_orders_json="[]" # Initialize as empty JSON array
        local wo_index=0
        local total_valid_wos=0
        
        # Iterate through each work order for safety validation
        while IFS= read -r wo_json; do
            local wo_id=$(echo "$wo_json" | jq -r '.wo_id')
            local is_wo_valid=0 # 0 for valid, 1 for invalid

            # --- Operation Path Validation (Safe Zones) ---
            # Extract all ops with a 'path' key
            local op_paths
            op_paths=$(echo "$wo_json" | jq -c '.ops[] | select(has("path"))')
            
            if [[ -n "$op_paths" ]]; then
                while IFS= read -r op_path_json; do
                    local op_type=$(echo "$op_path_json" | jq -r '.op')
                    local op_path=$(echo "$op_path_json" | jq -r '.path')
                    
                    if ! is_path_safe "$op_path"; then
                        log "ERROR: Work Order '$wo_id' contains an unsafe operation path: '$op_path' (op: $op_type). Rejecting Work Order."
                        is_wo_valid=1
                        break # Break from inner op_path loop
                    fi
                done <<< "$op_paths"
            fi

            if [[ "$is_wo_valid" -eq 0 ]]; then
                log "INFO: Work Order '$wo_id' passed safety validation. Adding to queue for dropping."
                # Append to valid_work_orders_json
                valid_work_orders_json=$(echo "$valid_work_orders_json" | jq ". + [$wo_json]")
                total_valid_wos=$((total_valid_wos + 1))
            else
                log "WARN: Work Order '$wo_id' was rejected due to safety violations. It will not be processed."
            fi
            wo_index=$((wo_index + 1))
        done <<< "$(echo "$parsed_work_orders_json" | jq -c '.[]')" # Iterate over each WO JSON object

        log "INFO: Found $total_valid_wos valid Work Order(s) after safety validation."

        # --- Atomic WO Dropping (for valid WOs) ---
        if [[ "$total_valid_wos" -gt 0 ]]; then
            log "INFO: Proceeding to drop $total_valid_wos valid Work Orders into inbox."
            dropped_wo_ids=() # reset array storing dropped IDs
            dropped_count=0

            while IFS= read -r valid_wo_json; do
                local wo_id=$(echo "$valid_wo_json" | jq -r '.wo_id')
                local wo_yaml=$(echo "$valid_wo_json" | yq e -P -) # Convert JSON back to YAML

                # 1. Create tmp file
                local tmp_wo_file
                tmp_wo_file=$(mktemp "$PROJECT_ROOT/tmp/wo_orch_${wo_id}_XXXXXX.yaml")
                
                # 2. Write content
                echo "$wo_yaml" > "$tmp_wo_file"

                # 3. Move atomically
                local final_wo_path="$WO_INBOX_DIR/WO-${wo_id}.yaml"
                if mv "$tmp_wo_file" "$final_wo_path"; then
                    log "INFO: Successfully dropped Work Order '$wo_id' to '$final_wo_path'."
                    dropped_count=$((dropped_count + 1))
                    dropped_wo_ids+=("$wo_id")
                    
                    # 4. Telemetry history copy (create dir if not exists)
                    local history_dir="$PROJECT_ROOT/g/telemetry/clc_wo_drops"
                    mkdir -p "$history_dir"
                    cp "$final_wo_path" "$history_dir/WO-${wo_id}-$(date +%Y%m%d%H%M%S).yaml"
                else
                    log "ERROR: Failed to atomically drop Work Order '$wo_id' to '$final_wo_path'."
                fi
            done <<< "$(echo "$valid_work_orders_json" | jq -c '.[]')"

            log "INFO: Successfully processed and dropped $dropped_count Work Order(s). IDs: ${dropped_wo_ids[*]}"
        else
            log "INFO: No valid Work Orders to drop after safety validation."
        fi
    else
        log "INFO: Plan is empty. No new Work Orders to create. System is idle."
    fi

    if [[ ${#dropped_wo_ids[@]} -gt 0 ]]; then
        dropped_wo_ids_json=$(printf '%s\n' "${dropped_wo_ids[@]}" | jq -R . | jq -s .)
    fi

    # Output statistics as JSON for main function
    echo "{\"dropped_count\": $dropped_count, \"dropped_wo_ids\": $dropped_wo_ids_json}"
}

cleanup() {
    # Remove temp files created during execution
    log "INFO: Cleaning up temporary files."
    rm -f "$@"
}

# --- Main Execution ---

main() {
    log "--- Orchestrator loop started ---" 
    
    local context_file
    local gmx_plan_file
    local process_plan_output="" # To capture stdout from process_plan
    local dropped_count=0
    local dropped_wo_ids_json="[]" # Store dropped WO IDs as JSON array
    local gmx_call_status="N/A" # Default status for GMX call

    # Use trap for reliable cleanup
    trap 'cleanup "$context_file" "$gmx_plan_file"' EXIT

    context_file=$(gather_context)
    
    # Check if context was created
    if [[ ! -f "$context_file" ]]; then
        log "ERROR: Failed to create context file. Aborting."
        exit 1
    fi

    local invoke_gmx_result # Capture the exit code of invoke_gmx_planner
    gmx_plan_file=$(invoke_gmx_planner "$context_file")
    invoke_gmx_result=$? # Get the exit code of the last command

    if [[ "$invoke_gmx_result" -eq 0 ]]; then
        gmx_call_status="OK"
    else
        gmx_call_status="FAILED"
    fi

    # Check if plan was created
    if [[ ! -f "$gmx_plan_file" ]]; then
        log "ERROR: Failed to get plan from GMX. Aborting."
        exit 1
    fi

    process_plan_output=$(process_plan "$gmx_plan_file")
    local process_plan_exit_code=$?

    if [[ "$process_plan_exit_code" -eq 0 ]]; then
        # Parse the JSON output from process_plan
        dropped_count=$(echo "$process_plan_output" | jq -r '.dropped_count')
        dropped_wo_ids_json=$(echo "$process_plan_output" | jq -c '.dropped_wo_ids')
    else
        log "ERROR: process_plan failed with exit code $process_plan_exit_code. No Work Orders processed."
    fi

    # Final summary log
    local current_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    log "--- Orchestrator loop finished ---"
    log "SUMMARY: Timestamp=$current_timestamp, GMX_Call_Status=$gmx_call_status, WOs_Created=$dropped_count, WO_IDs=${dropped_wo_ids_json}"

    # Append minimal JSONL entry for telemetry
    local telemetry_entry_file="$PROJECT_ROOT/g/telemetry/gmx_clc_orch.jsonl"
    echo "{\"timestamp\":\"$current_timestamp\", \"gmx_call_status\":\"$gmx_call_status\", \"wos_created\":$dropped_count, \"dropped_wo_ids\":$dropped_wo_ids_json}" >> "$telemetry_entry_file"
}

# Create log file if it doesn't exist
touch "$LOG_FILE"

# Create telemetry file if it doesn't exist
touch "$PROJECT_ROOT/g/telemetry/gmx_clc_orch.jsonl"

# Run main function
main
