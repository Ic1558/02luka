#!/usr/bin/env zsh
# Claude PR Batch Wrapper
# Wraps PR operations with automatic batch tracking and reporting
#
# Usage:
#   source claude-batch-wrapper.zsh
#   claude_batch_start
#   claude_batch_track_pr 123 "PR Title" "branch-name"
#   claude_batch_track_branch "branch-name" "commit-sha" "commit message"
#   claude_batch_report

# Get the script directory
SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h:h}"
TRACKER_SCRIPT="${PROJECT_ROOT}/scripts/claude_batch_tracker.py"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Start a new batch
claude_batch_start() {
    echo -e "${BLUE}[BATCH]${NC} Starting new Claude PR batch..."
    local result=$(python3 "$TRACKER_SCRIPT" start 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        local batch_id=$(echo "$result" | jq -r '.batch_id // empty')
        echo -e "${GREEN}[BATCH]${NC} Batch started: $batch_id"
        return 0
    else
        echo -e "${RED}[BATCH]${NC} Failed to start batch: $result"
        return 1
    fi
}

# Track a merged PR
claude_batch_track_pr() {
    local pr_number=$1
    local pr_title=$2
    local branch_name=$3
    local pr_url=$4

    if [[ -z "$pr_number" || -z "$pr_title" || -z "$branch_name" ]]; then
        echo -e "${RED}[BATCH]${NC} Usage: claude_batch_track_pr <number> <title> <branch> [url]"
        return 1
    fi

    echo -e "${BLUE}[BATCH]${NC} Tracking merged PR #${pr_number}..."

    local cmd_args=(pr-merged --number "$pr_number" --title "$pr_title" --branch "$branch_name")
    if [[ -n "$pr_url" ]]; then
        cmd_args+=(--url "$pr_url")
    fi

    local result=$(python3 "$TRACKER_SCRIPT" "${cmd_args[@]}" 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}[BATCH]${NC} Tracked PR #${pr_number}"
        return 0
    else
        echo -e "${RED}[BATCH]${NC} Failed to track PR: $result"
        return 1
    fi
}

# Track a branch update
claude_batch_track_branch() {
    local branch_name=$1
    local commit_sha=$2
    local commit_message=$3

    if [[ -z "$branch_name" || -z "$commit_sha" || -z "$commit_message" ]]; then
        echo -e "${RED}[BATCH]${NC} Usage: claude_batch_track_branch <branch> <sha> <message>"
        return 1
    fi

    echo -e "${BLUE}[BATCH]${NC} Tracking branch update: ${branch_name}..."

    local result=$(python3 "$TRACKER_SCRIPT" branch-updated \
        --branch "$branch_name" \
        --sha "$commit_sha" \
        --message "$commit_message" 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}[BATCH]${NC} Tracked branch: ${branch_name}"
        return 0
    else
        echo -e "${RED}[BATCH]${NC} Failed to track branch: $result"
        return 1
    fi
}

# Track time spent (in milliseconds)
claude_batch_track_time() {
    local duration_ms=$1

    if [[ -z "$duration_ms" ]]; then
        echo -e "${RED}[BATCH]${NC} Usage: claude_batch_track_time <duration_ms>"
        return 1
    fi

    local result=$(python3 "$TRACKER_SCRIPT" track-time --duration "$duration_ms" 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        local total=$(echo "$result" | jq -r '.total_time_ms // empty')
        echo -e "${GREEN}[BATCH]${NC} Tracked time: ${duration_ms}ms (total: ${total}ms)"
        return 0
    else
        echo -e "${RED}[BATCH]${NC} Failed to track time: $result"
        return 1
    fi
}

# Track credits used
claude_batch_track_credits() {
    local amount=$1

    if [[ -z "$amount" ]]; then
        echo -e "${RED}[BATCH]${NC} Usage: claude_batch_track_credits <amount>"
        return 1
    fi

    local result=$(python3 "$TRACKER_SCRIPT" track-credits --amount "$amount" 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        local total=$(echo "$result" | jq -r '.total_credits // empty')
        echo -e "${GREEN}[BATCH]${NC} Tracked credits: ${amount} (total: ${total})"
        return 0
    else
        echo -e "${RED}[BATCH]${NC} Failed to track credits: $result"
        return 1
    fi
}

# Get batch status
claude_batch_status() {
    local result=$(python3 "$TRACKER_SCRIPT" status 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        local active=$(echo "$result" | jq -r '.active // false')

        if [[ "$active" == "true" ]]; then
            local batch_id=$(echo "$result" | jq -r '.batch_id // empty')
            local prs=$(echo "$result" | jq -r '.merged_prs_count // 0')
            local branches=$(echo "$result" | jq -r '.updated_branches_count // 0')
            local time=$(echo "$result" | jq -r '.time_spent_ms // 0')
            local credits=$(echo "$result" | jq -r '.credits_used // 0')

            echo -e "${BLUE}[BATCH]${NC} Active batch: $batch_id"
            echo -e "  - Merged PRs: $prs"
            echo -e "  - Updated branches: $branches"
            echo -e "  - Time spent: ${time}ms"
            echo -e "  - Credits used: $credits"
        else
            echo -e "${YELLOW}[BATCH]${NC} No active batch"
        fi
        return 0
    else
        echo -e "${RED}[BATCH]${NC} Failed to get status: $result"
        return 1
    fi
}

# Generate batch report
claude_batch_report() {
    echo -e "${BLUE}[BATCH]${NC} Generating batch report..."

    local result=$(python3 "$TRACKER_SCRIPT" report 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        local filepath=$(echo "$result" | jq -r '.filepath // empty')
        local filename=$(echo "$result" | jq -r '.filename // empty')
        local prs=$(echo "$result" | jq -r '.summary.merged_prs_count // 0')
        local branches=$(echo "$result" | jq -r '.summary.updated_branches_count // 0')

        echo -e "${GREEN}[BATCH]${NC} Report generated: $filename"
        echo -e "  - Location: $filepath"
        echo -e "  - Merged PRs: $prs"
        echo -e "  - Updated branches: $branches"

        # Show the file path for easy access
        echo -e "\n${BLUE}[BATCH]${NC} View report:"
        echo -e "  cat $filepath"

        return 0
    else
        echo -e "${RED}[BATCH]${NC} Failed to generate report: $result"
        return 1
    fi
}

# Wrapper for git operations with time tracking
claude_batch_git_with_timing() {
    local start_time=$(date +%s%3N)
    "$@"
    local exit_code=$?
    local end_time=$(date +%s%3N)
    local duration=$((end_time - start_time))

    claude_batch_track_time "$duration"

    return $exit_code
}

# Auto-track git push operations
claude_batch_git_push() {
    local branch=$1
    shift

    echo -e "${BLUE}[BATCH]${NC} Pushing to $branch with tracking..."

    local start_time=$(date +%s%3N)
    git push -u origin "$branch" "$@"
    local exit_code=$?
    local end_time=$(date +%s%3N)
    local duration=$((end_time - start_time))

    if [[ $exit_code -eq 0 ]]; then
        local sha=$(git rev-parse HEAD)
        local message=$(git log -1 --pretty=%B | head -n1)

        claude_batch_track_branch "$branch" "$sha" "$message"
        claude_batch_track_time "$duration"
    fi

    return $exit_code
}

# Export functions
export -f claude_batch_start
export -f claude_batch_track_pr
export -f claude_batch_track_branch
export -f claude_batch_track_time
export -f claude_batch_track_credits
export -f claude_batch_status
export -f claude_batch_report
export -f claude_batch_git_with_timing
export -f claude_batch_git_push

echo -e "${GREEN}[BATCH]${NC} Claude batch tracking loaded. Available commands:"
echo "  - claude_batch_start"
echo "  - claude_batch_track_pr <number> <title> <branch> [url]"
echo "  - claude_batch_track_branch <branch> <sha> <message>"
echo "  - claude_batch_track_time <duration_ms>"
echo "  - claude_batch_track_credits <amount>"
echo "  - claude_batch_status"
echo "  - claude_batch_report"
echo "  - claude_batch_git_push <branch>"
