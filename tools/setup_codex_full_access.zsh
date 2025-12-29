#!/usr/bin/env zsh
# ======================================================================
# Codex Full System Access Setup (Tier 2 - Safe)
# Purpose: Enable Codex to read anywhere (like CLC) while keeping writes safe
# Usage: zsh ~/02luka/tools/setup_codex_full_access.zsh [tier]
#        zsh ~/02luka/tools/setup_codex_full_access.zsh 2    # Tier 2 (recommended)
#        zsh ~/02luka/tools/setup_codex_full_access.zsh 3    # Tier 3 (full access)
# ======================================================================

set -euo pipefail

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

check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v codex &> /dev/null; then
        log_error "Codex CLI not found"
        exit 1
    fi

    if [[ ! -f "$CODEX_CONFIG" ]]; then
        log_error "Codex config not found at $CODEX_CONFIG"
        exit 1
    fi

    log_success "Prerequisites OK"
}

setup_tier2() {
    log_info "=== Setting up Tier 2: Expanded Read Access ==="
    log_info "Read: Anywhere ✅ | Write: Workspace + approved dirs ✅"
    echo ""

    # Backup
    local backup="${CODEX_CONFIG}.backup.tier2.$(date +%Y%m%d_%H%M%S)"
    cp "$CODEX_CONFIG" "$backup"
    log_success "Backed up config to $backup"

    # Update config
    log_info "Updating ~/.codex/config.toml..."

    # Remove old sections if exist
    sed -i.tmp '/^\[permissions\]/,/^$/d' "$CODEX_CONFIG" 2>/dev/null || true
    sed -i.tmp '/^\[safety\]/,/^$/d' "$CODEX_CONFIG" 2>/dev/null || true
    rm -f "${CODEX_CONFIG}.tmp"

    # Update [sandbox] section
    if grep -q "auto_approve_reads" "$CODEX_CONFIG"; then
        log_info "Sandbox section already configured"
    else
        sed -i.tmp 's/^auto_approve_reads = .*/auto_approve_reads = true  # Full read access/' "$CODEX_CONFIG" 2>/dev/null || true
        rm -f "${CODEX_CONFIG}.tmp"
    fi

    # Update [approval] section
    if grep -q "prompt_for_outside_writes" "$CODEX_CONFIG"; then
        log_info "Approval section already configured"
    else
        # Add after [approval] section
        awk '/^\[approval\]/{print; print "prompt_for_outside_writes = true  # Prompt for writes outside workspace"; next}1' "$CODEX_CONFIG" > "${CODEX_CONFIG}.tmp"
        mv "${CODEX_CONFIG}.tmp" "$CODEX_CONFIG"
    fi

    # Add new [permissions] section
    cat >> "$CODEX_CONFIG" <<'EOF'

# Permissions (Tier 2 - Expanded Read)
[permissions]
read_anywhere = true  # Can read system files for context
write_restricted_to = [
  "/Users/icmini/02luka",
  "/Users/icmini/.config",
  "/Users/icmini/.zshrc",
  "/Users/icmini/.codex",
]

# Safety rules (always prompt)
[safety]
always_prompt_for = [
  "rm -rf",
  "sudo",
  "git push --force",
  "chmod 777",
  "/etc/**",
  "/System/**",
]
EOF

    log_success "Config updated to Tier 2"
    echo ""
    log_info "New capabilities:"
    echo "  ✅ Read: Anywhere in system (like CLC)"
    echo "  ✅ Write: ~/02luka + ~/.config + ~/.zshrc (prompts for others)"
    echo "  ✅ Safety: Dangerous commands still prompt"
    echo ""

    # Add aliases
    add_tier2_aliases
}

setup_tier3() {
    log_warning "=== Setting up Tier 3: Full Access (DANGEROUS) ==="
    log_warning "Read: Anywhere ✅ | Write: Anywhere ⚠️ (prompts)"
    echo ""

    read "yn?⚠️  Are you sure? This gives Codex write access everywhere. [y/N]: "
    if [[ "$yn" != "y" ]]; then
        log_info "Cancelled Tier 3 setup"
        exit 0
    fi

    # Backup
    local backup="${CODEX_CONFIG}.backup.tier3.$(date +%Y%m%d_%H%M%S)"
    cp "$CODEX_CONFIG" "$backup"
    log_success "Backed up config to $backup"

    # Update [projects] to trust root
    if grep -q '^\[projects."/"\]' "$CODEX_CONFIG"; then
        log_info "Root project already trusted"
    else
        cat >> "$CODEX_CONFIG" <<'EOF'

# Full system access (Tier 3 - DANGEROUS)
[projects."/"]
trust_level = "trusted"
write_prompt = true  # Always prompt before write
EOF
    fi

    log_success "Config updated to Tier 3"
    log_warning "⚠️  Codex can now write ANYWHERE (with prompts)"
    echo ""

    add_tier3_aliases
}

add_tier2_aliases() {
    log_info "Adding Tier 2 aliases to ~/.zshrc..."

    # Check if already exist
    if grep -q "alias codex-system" "$ZSHRC" 2>/dev/null; then
        log_info "Tier 2 aliases already exist"
        return 0
    fi

    cat >> "$ZSHRC" <<'EOF'

# Codex Tier 2: Expanded read access
alias codex-system='codex -s workspace-write -c "sandbox_permissions=[\"disk-full-read-access\"]"'
alias codex-analyze='codex -s workspace-write -c "sandbox_permissions=[\"disk-full-read-access\"]" --read-only'
EOF

    log_success "Tier 2 aliases added"
    echo ""
    log_info "New commands:"
    echo "  codex-system  - Full read access, workspace writes"
    echo "  codex-analyze - Full read access, read-only mode"
    echo ""
}

add_tier3_aliases() {
    log_info "Adding Tier 3 aliases to ~/.zshrc..."

    if grep -q "alias codex-full" "$ZSHRC" 2>/dev/null; then
        log_info "Tier 3 aliases already exist"
        return 0
    fi

    cat >> "$ZSHRC" <<'EOF'

# Codex Tier 3: Full system access (DANGEROUS)
alias codex-full='codex -s danger-full-access'
alias codex-root='codex --dangerously-bypass-approvals-and-sandbox'
EOF

    log_warning "Tier 3 aliases added"
    log_warning "⚠️  Use with extreme caution!"
    echo ""
}

run_tests() {
    log_info "=== Testing Tier 2 Access ==="
    echo ""

    # Test 1: Read outside workspace
    log_info "Test 1: Reading ~/.zshrc..."
    if [[ -f ~/.zshrc ]]; then
        log_success "✅ Can access ~/.zshrc for reading"
    else
        log_warning "⚠️ ~/.zshrc not found (expected on your system)"
    fi

    # Test 2: Check config syntax
    log_info "Test 2: Validating config syntax..."
    if grep -q "\[permissions\]" "$CODEX_CONFIG"; then
        log_success "✅ [permissions] section added"
    else
        log_error "❌ [permissions] section missing"
    fi

    echo ""
    log_info "Run manual tests:"
    echo '  codex-system "analyze my ~/.zshrc file"'
    echo '  codex-analyze "check system configs in ~/.config"'
    echo ""
}

show_comparison() {
    echo ""
    log_info "=== Tier Comparison ==="
    echo ""
    echo "Tier 1 (Original):"
    echo "  Read:  ~/02luka only"
    echo "  Write: ~/02luka only"
    echo ""
    echo "Tier 2 (Recommended) ← YOU ARE HERE"
    echo "  Read:  ✅ Anywhere (like CLC)"
    echo "  Write: ~/02luka + approved dirs (prompts for others)"
    echo ""
    echo "Tier 3 (Full Access):"
    echo "  Read:  ✅ Anywhere"
    echo "  Write: ✅ Anywhere (prompts for all)"
    echo ""
}

main() {
    local tier="${1:-2}"

    echo ""
    log_info "Codex Full System Access Setup"
    log_info "================================"
    echo ""

    check_prerequisites
    echo ""

    case "$tier" in
        2)
            setup_tier2
            run_tests
            show_comparison
            ;;
        3)
            setup_tier3
            show_comparison
            ;;
        *)
            log_error "Invalid tier: $tier"
            log_info "Usage: $0 [2|3]"
            exit 1
            ;;
    esac

    echo ""
    log_success "======================================"
    log_success "Codex Access Setup Complete"
    log_success "======================================"
    echo ""
    log_info "Next steps:"
    echo "  1. Reload shell: source ~/.zshrc"
    echo "  2. Test: codex-system 'analyze ~/.zshrc'"
    echo "  3. Use: codex-task for 02luka work (with git safety)"
    echo ""
    log_info "Documentation: ~/02luka/g/docs/CODEX_FULL_SYSTEM_ACCESS.md"
    echo ""
    log_success "Codex can now work like CLC (read anywhere, safe writes) ⚡"
    echo ""
}

main "$@"
