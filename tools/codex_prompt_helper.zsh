#!/usr/bin/env zsh
# Utility for listing and printing approved Codex prompt templates.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/codex_prompt_templates"

usage() {
  cat <<'EOF'
Usage:
  tools/codex_prompt_helper.zsh list [--format json|yaml]
  tools/codex_prompt_helper.zsh show <template-name> [--format json|yaml]

Options:
  --format <format>  Output format: json, yaml, or text (default: text)
EOF
}

list_templates() {
  local format="${1:-text}"
  
  if [[ ! -d "$TEMPLATE_DIR" ]]; then
    echo "Template directory not found: $TEMPLATE_DIR" >&2
    return 1
  fi

  local files=("$TEMPLATE_DIR"/*.md(N))
  if (( ${#files} == 0 )); then
    echo "No templates available in $TEMPLATE_DIR" >&2
    return 1
  fi

  case "$format" in
    json)
      echo "["
      local first=true
      for file in "${files[@]}"; do
        [[ "$first" == "false" ]] && echo ","
        first=false
        printf '  {"name": "%s"}' "${file:t:r}"
      done
      echo ""
      echo "]"
      ;;
    yaml)
      echo "templates:"
      for file in "${files[@]}"; do
        printf '  - name: %s\n' "${file:t:r}"
      done
      ;;
    text|*)
      for file in "${files[@]}"; do
        printf '%s\n' "${file:t:r}"
      done
      ;;
  esac
}

show_template() {
  local name="$1"
  local format="${2:-text}"
  local template="$TEMPLATE_DIR/$name.md"
  
  if [[ ! -f "$template" ]]; then
    echo "Unknown template: $name (expected $template)" >&2
    return 1
  fi
  
  case "$format" in
    json)
      local content=$(cat "$template" | jq -Rs .)
      printf '{"name": "%s", "content": %s}\n' "$name" "$content"
      ;;
    yaml)
      echo "name: $name"
      echo "content: |"
      cat "$template" | sed 's/^/  /'
      ;;
    text|*)
      cat "$template"
      ;;
  esac
}

if (( $# == 0 )); then
  usage >&2
  exit 1
fi

subcommand="$1"
shift

# Parse --format flag
FORMAT="text"
ARGS=()
while (( $# > 0 )); do
  case "$1" in
    --format)
      if (( $# < 2 )); then
        echo "Error: --format requires a value (json, yaml, or text)" >&2
        usage >&2
        exit 1
      fi
      FORMAT="$2"
      shift 2
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done

case "$subcommand" in
  list)
    list_templates "$FORMAT"
    ;;
  show)
    if (( ${#ARGS[@]} != 1 )); then
      echo "show requires exactly one template name" >&2
      usage >&2
      exit 1
    fi
    show_template "${ARGS[1]}" "$FORMAT"
    ;;
  *)
    echo "Unknown subcommand: $subcommand" >&2
    usage >&2
    exit 1
    ;;
esac
