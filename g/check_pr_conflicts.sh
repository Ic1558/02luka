#!/bin/bash

# Script to check all PR branches for conflicts with main

echo "Checking conflicts for all PR branches..."
echo "=========================================="
echo ""

# Get the main branch commit
MAIN_BRANCH="origin/main"

# Get all remote branches except main and HEAD
BRANCHES=$(git branch -r | grep -v 'HEAD' | grep -v 'main$' | sed 's/^[[:space:]]*//')

TOTAL=0
CONFLICTS=0
NO_CONFLICTS=0

# Create output file
OUTPUT_FILE="pr_conflicts_report.txt"
> "$OUTPUT_FILE"

echo "PR Conflict Analysis Report" >> "$OUTPUT_FILE"
echo "Generated: $(date)" >> "$OUTPUT_FILE"
echo "=========================================" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

for BRANCH in $BRANCHES; do
    TOTAL=$((TOTAL + 1))
    BRANCH_NAME=$(echo "$BRANCH" | sed 's/origin\///')

    # Use git merge-tree to check for conflicts without actually merging
    MERGE_RESULT=$(git merge-tree $(git merge-base $MAIN_BRANCH $BRANCH) $MAIN_BRANCH $BRANCH 2>&1)

    # Check if there are conflict markers in the result
    if echo "$MERGE_RESULT" | grep -q "<<<<<<< "; then
        CONFLICTS=$((CONFLICTS + 1))
        echo "✗ CONFLICT: $BRANCH_NAME" | tee -a "$OUTPUT_FILE"

        # Get list of conflicting files
        CONFLICT_FILES=$(echo "$MERGE_RESULT" | grep -A 5 "<<<<<<< " | grep "^+++" | sed 's/^+++[[:space:]]b\///' | sort -u)

        if [ -n "$CONFLICT_FILES" ]; then
            echo "  Conflicting files:" >> "$OUTPUT_FILE"
            echo "$CONFLICT_FILES" | sed 's/^/    - /' >> "$OUTPUT_FILE"
        fi
        echo "" >> "$OUTPUT_FILE"
    else
        NO_CONFLICTS=$((NO_CONFLICTS + 1))
        echo "✓ OK: $BRANCH_NAME"
    fi
done

echo "" | tee -a "$OUTPUT_FILE"
echo "=========================================" | tee -a "$OUTPUT_FILE"
echo "Summary:" | tee -a "$OUTPUT_FILE"
echo "  Total branches checked: $TOTAL" | tee -a "$OUTPUT_FILE"
echo "  Branches with conflicts: $CONFLICTS" | tee -a "$OUTPUT_FILE"
echo "  Branches without conflicts: $NO_CONFLICTS" | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"
echo "Full report saved to: $OUTPUT_FILE"
