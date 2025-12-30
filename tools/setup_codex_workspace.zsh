#!/usr/bin/env zsh
# ======================================================================
# Codex Workspace Setup for 02luka
# Purpose: Configure Codex to work freely in 02luka without sandbox blocking
# Usage: zsh ~/02luka/tools/setup_codex_workspace.zsh [option]
#        zsh ~/02luka/tools/setup_codex_workspace.zsh config   # Update config file (recommended)
#        zsh ~/02luka/tools/setup_codex_workspace.zsh aliases  # Add shell aliases only
#        zsh ~/02luka/tools/setup_codex_workspace.zsh both     # Do both (default)
# ======================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo "${BLUE}[INFO]${NC} $1"; }
log_success() { echo "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo "${RED}[ERROR]${NC} $1"; }

CODEX_CONFIG="${HOME}/.codex/config.toml"
ZSHRC="${HOME}/.zshrc"

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v codex &> /dev/null; then
        log_error "Codex CLI not found. Install first."
        exit 1
    fi

    if [[ ! -f "$CODEX_CONFIG" ]]; then
        log_error "Codex config not found at $CODEX_CONFIG"
        log_error "Run Codex once to initialize config."
        exit 1
    fi

    log_success "Prerequisites OK"
}

# Update Codex config.toml
update_config() {
    log_info "=== Updating Codex Config ==="

    # Backup current config
    local backup="${CODEX_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$CODEX_CONFIG" "$backup"
    log_success "Backed up config to $backup"

    # Check if already configured
    if grep -q "\[sandbox\]" "$CODEX_CONFIG"; then
        log_warning "Sandbox section already exists in config"
        read "yn?Overwrite sandbox settings? (y/n): "
        if [[ "$yn" != "y" ]]; then
            log_info "Skipping config update"
            return 0
        fi
        # Remove existing [sandbox] and [approval] sections
        sed -i.tmp '/^\[sandbox\]/,/^$/d' "$CODEX_CONFIG"
        sed -i.tmp '/^\[approval\]/,/^$/d' "$CODEX_CONFIG"
        rm -f "${CODEX_CONFIG}.tmp"
    fi

    # Append new config
    cat >> "$CODEX_CONFIG" <<'EOF'

# Sandbox settings (added by setup_codex_workspace.zsh)
[sandbox]
default_mode = "workspace-write"    # Can write to trusted workspace
auto_approve_reads = true           # Don't prompt for file reads
auto_approve_workspace_writes = true  # Don't prompt for workspace writes

# Approval settings
[approval]
mode = "on-request"                 # Auto-approve when model needs it
trust_workspace_commands = true     # Trust commands in workspace
prompt_for_dangerous = true         # Still prompt for rm, sudo, etc.

# Additional writable directories
[workspace]
additional_writable = [
  "/Users/icmini/02luka/tools",
  "/Users/icmini/02luka/g/reports",
  "/Users/icmini/02luka/apps"
]
EOF

    log_success "Config updated with sandbox bypass settings"
    log_info "Config file: $CODEX_CONFIG"
    echo ""
    log_info "New settings:"
    echo "  - Sandbox mode: workspace-write"
    echo "  - Auto-approve reads: enabled"
    echo "  - Auto-approve workspace writes: enabled"
    echo "  - Dangerous commands: still prompt ✅"
    echo ""
}

# Add shell aliases
add_aliases() {
    log_info "=== Adding Codex Aliases to ~/.zshrc ==="

    # Check if aliases already exist
    if grep -q "alias codex-safe" "$ZSHRC" 2>/dev/null; then
        log_warning "Codex aliases already exist in $ZSHRC"
        read "yn?Overwrite? (y/n): "
        if [[ "$yn" != "y" ]]; then
            log_info "Skipping aliases"
            return 0
        fi
        # Remove existing aliases
        sed -i.tmp '/# Codex aliases for 02luka/,/^$/d' "$ZSHRC"
        rm -f "${ZSHRC}.tmp"
    fi

    # Append aliases
    cat >> "$ZSHRC" <<'EOF'

# Codex aliases for 02luka workflow
alias codex-safe='codex -s workspace-write'
alias codex-auto='codex -a on-request -s workspace-write'
alias codex-danger='codex --dangerously-bypass-approvals-and-sandbox'

# Codex with git safety net
create_checkpoint() {
  local message="${1:-codex-task}"
  echo "📌 Creating safety checkpoint..."
  git add -A && git commit -m "pre-codex: $message" || echo "⚠️ No changes to commit"
}

rollback_checkpoint() {
  echo "⏪ Rolling back to last checkpoint..."
  git reset --hard HEAD
}

codex-task() {
  local instruction="${1:-codex-task}"
  if [[ ! -t 0 ]]; then
    echo "⚠️  codex-task requires an interactive TTY." >&2
    echo "   Fix: run in a normal terminal session (not CI/non-interactive)." >&2
    return 1
  fi
  create_checkpoint "$instruction"

  echo "🤖 Running Codex..."
  codex-auto "$instruction"

  echo "📊 Review changes:"
  git diff HEAD

  echo ""
  echo "✅ To keep: git add -A && git commit -m 'codex: $instruction'"
  echo "❌ To undo: rollback_checkpoint"
}
EOF

    log_success "Aliases added to $ZSHRC"
    echo ""
    log_info "Available aliases:"
    echo "  codex-safe   - Workspace-write mode (prompts for commands)"
    echo "  codex-auto   - Auto-approve mode (no prompts)"
    echo "  codex-danger - Full bypass (emergency only)"
    echo "  codex-task   - Auto mode with git safety net"
    echo ""
    log_info "Reload shell to use aliases:"
    echo "  source ~/.zshrc"
    echo ""
}

# Run tests
run_tests() {
    log_info "=== Running Sandbox Tests ==="

    # Test 1: Can write to 02luka?
    log_info "Test 1: Write to 02luka workspace..."
    mkdir -p ~/02luka/tmp
    if codex -s workspace-write "create a file at ~/02luka/tmp/sandbox_test.txt with content 'Sandbox test OK'" --non-interactive 2>&1 | grep -q "created\|wrote\|done"; then
        if [[ -f ~/02luka/tmp/sandbox_test.txt ]]; then
            log_success "✅ Test 1 passed: Codex can write to 02luka"
            rm ~/02luka/tmp/sandbox_test.txt
        else
            log_warning "⚠️ Test 1 unclear: Check manually"
        fi
    else
        log_warning "⚠️ Test 1: Run manually to verify"
    fi

    echo ""
    log_info "Manual test commands:"
    echo '  codex-safe "create a test file at ~/02luka/tmp/test.txt"'
    echo '  codex-auto "add a comment to tools/session_save.zsh"'
    echo ""
}

# Main
main() {
    local mode="${1:-both}"

    echo ""
    log_info "Codex Workspace Setup for 02luka"
    log_info "=================================="
    echo ""

    check_prerequisites
    echo ""

    case "$mode" in
        config)
            update_config
            ;;
        aliases)
            add_aliases
            ;;
        both|*)
            update_config
            echo ""
            add_aliases
            ;;
    esac

    echo ""
    log_success "======================================"
    log_success "Codex Workspace Setup Complete"
    log_success "======================================"
    echo ""
    log_info "What changed:"
    [[ "$mode" == "config" || "$mode" == "both" ]] && echo "  ✅ Updated ~/.codex/config.toml (sandbox bypass)"
    [[ "$mode" == "aliases" || "$mode" == "both" ]] && echo "  ✅ Added aliases to ~/.zshrc"
    echo ""
    log_info "Next steps:"
    echo "  1. Reload shell: source ~/.zshrc"
    echo "  2. Test: codex-safe 'analyze ~/02luka/tools/'"
    echo "  3. Use: codex-task 'refactor session_save.zsh'"
    echo ""
    log_info "Documentation: ~/02luka/g/docs/CODEX_SANDBOX_STRATEGY.md"
    echo ""
    log_success "Codex can now work in 02luka without blocking! ⚡"
    echo ""
}

main "$@"
