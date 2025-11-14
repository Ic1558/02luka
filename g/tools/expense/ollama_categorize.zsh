#!/usr/bin/env zsh
# Ollama-powered expense categorization
# Uses qwen2.5:0.5b local AI to categorize expenses
# Zero cost, runs locally

set -euo pipefail

# Check if Ollama is available
if ! command -v ollama >/dev/null 2>&1; then
  echo "❌ Ollama not found. Install with: brew install ollama"
  exit 1
fi

# Check if model is available
if ! ollama list | grep -q "qwen2.5:0.5b"; then
  echo "⚠️  qwen2.5:0.5b not found. Pulling model..."
  ollama pull qwen2.5:0.5b
fi

# Function to categorize expense
categorize_expense() {
  local payee="$1"
  local note="$2"

  # Build prompt for categorization (v1.0 - simple prompt works better for small models)
  local prompt="Categorize this expense into ONE of these categories:
Categories: Materials, Labor, Consumables, Equipment, Transport, Professional Services, Utilities, Office Supplies, Other

Expense:
- Payee: ${payee}
- Note: ${note}

Reply with ONLY the category name, nothing else."

  # Call Ollama with larger model for better accuracy (timeout after 10 seconds)
  local category
  category=$(timeout 10s ollama run qwen2.5:1.5b "$prompt" 2>/dev/null | head -1 | tr -d '\n\r' | xargs)

  # Validate category
  local valid_categories=("Materials" "Labor" "Consumables" "Equipment" "Transport" "Professional Services" "Utilities" "Office Supplies" "Other")

  if [[ " ${valid_categories[@]} " =~ " ${category} " ]]; then
    echo "$category"
  else
    # Fallback to "Other" if invalid
    echo "Other"
  fi
}

# Main: categorize from stdin or arguments
if [[ $# -eq 2 ]]; then
  # Direct call: categorize_expense.zsh "PayeeName" "Note text"
  categorize_expense "$1" "$2"
elif [[ $# -eq 0 ]]; then
  # Pipe mode: expects JSON with payee and note fields
  while IFS= read -r line; do
    payee=$(echo "$line" | jq -r '.payee // empty')
    note=$(echo "$line" | jq -r '.note // empty')

    if [[ -n "$payee" ]]; then
      category=$(categorize_expense "$payee" "$note")
      echo "$line" | jq --arg cat "$category" '. + {category: $cat, ai_categorized: true}'
    else
      echo "$line"
    fi
  done
else
  echo "Usage:"
  echo "  $0 'PayeeName' 'Note text'  # Direct call"
  echo "  cat ledger.jsonl | $0        # Pipe mode"
  exit 1
fi
