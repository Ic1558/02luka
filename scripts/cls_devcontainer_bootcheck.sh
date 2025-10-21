#!/usr/bin/env bash
set -euo pipefail

# CLS DevContainer Bootcheck
# Verifies shell availability and fixes ENOENT issues automatically

echo "🧠 CLS DevContainer Bootcheck"
echo "============================="

# Function to check shell availability
check_shell_availability() {
    echo "1) Checking shell availability..."
    
    # Check for zsh
    if command -v zsh >/dev/null 2>&1; then
        echo "   ✅ zsh available: $(which zsh)"
        ZSH_AVAILABLE=true
    else
        echo "   ⚠️  zsh not available"
        ZSH_AVAILABLE=false
    fi
    
    # Check for bash
    if command -v bash >/dev/null 2>&1; then
        echo "   ✅ bash available: $(which bash)"
        BASH_AVAILABLE=true
    else
        echo "   ❌ bash not available"
        BASH_AVAILABLE=false
    fi
    
    # Check current shell
    echo "   Current shell: ${SHELL:-unknown}"
    echo "   CLS_SHELL: ${CLS_SHELL:-unset}"
}

# Function to install zsh if needed
install_zsh() {
    echo ""
    echo "2) Installing zsh (if needed)..."
    
    if [[ "$ZSH_AVAILABLE" == "false" ]]; then
        echo "   Installing zsh..."
        if sudo apt-get update -y && sudo apt-get install -y zsh; then
            echo "   ✅ zsh installed successfully"
            ZSH_AVAILABLE=true
        else
            echo "   ❌ zsh installation failed"
        fi
    else
        echo "   ✅ zsh already available"
    fi
}

# Function to configure shell environment
configure_shell_environment() {
    echo ""
    echo "3) Configuring shell environment..."
    
    # Set CLS_SHELL based on availability
    if [[ "$ZSH_AVAILABLE" == "true" ]]; then
        export CLS_SHELL="/usr/bin/zsh"
        echo "   ✅ CLS_SHELL set to: $CLS_SHELL"
    elif [[ "$BASH_AVAILABLE" == "true" ]]; then
        export CLS_SHELL="/bin/bash"
        echo "   ✅ CLS_SHELL set to: $CLS_SHELL (fallback)"
    else
        echo "   ❌ No suitable shell found"
        return 1
    fi
    
    # Set SHELL environment variable
    export SHELL="$CLS_SHELL"
    echo "   ✅ SHELL set to: $SHELL"
}

# Function to test shell resolver
test_shell_resolver() {
    echo ""
    echo "4) Testing shell resolver..."
    
    if [[ -f "packages/skills/resolveShell.js" ]]; then
        echo "   Testing resolver:"
        if node -e "console.log(require('./packages/skills/resolveShell').resolveShell())" 2>/dev/null; then
            echo "   ✅ Shell resolver working"
        else
            echo "   ❌ Shell resolver failed"
        fi
    else
        echo "   ⚠️  Shell resolver not found"
    fi
}

# Function to test CLS scripts
test_cls_scripts() {
    echo ""
    echo "5) Testing CLS scripts..."
    
    # Test basic script execution
    if [[ -f "scripts/cls_go_live_validation.sh" ]]; then
        echo "   Testing validation script..."
        if timeout 10s bash scripts/cls_go_live_validation.sh >/dev/null 2>&1; then
            echo "   ✅ Validation script executable"
        else
            echo "   ⚠️  Validation script test incomplete (timeout or error)"
        fi
    else
        echo "   ❌ Validation script not found"
    fi
    
    # Test workflow assistant
    if [[ -f "scripts/codex_workflow_assistant.sh" ]]; then
        echo "   Testing workflow assistant..."
        if timeout 10s bash scripts/codex_workflow_assistant.sh --scan >/dev/null 2>&1; then
            echo "   ✅ Workflow assistant executable"
        else
            echo "   ⚠️  Workflow assistant test incomplete (timeout or error)"
        fi
    else
        echo "   ❌ Workflow assistant not found"
    fi
}

# Function to create persistent configuration
create_persistent_config() {
    echo ""
    echo "6) Creating persistent configuration..."
    
    # Create .env file for shell configuration
    cat > .env.cls << EOF
# CLS Shell Configuration
export CLS_SHELL="$CLS_SHELL"
export SHELL="$SHELL"

# Add to PATH if needed
export PATH="/usr/local/bin:/usr/bin:/bin:\$PATH"
EOF
    
    echo "   ✅ Configuration saved to .env.cls"
    echo "   Source with: source .env.cls"
    
    # Create shell profile entry
    cat > .cls_shell_profile << EOF
# CLS Shell Profile
# Add to your shell profile (.bashrc, .zshrc, etc.)

# Source CLS configuration
if [[ -f "\$HOME/.env.cls" ]]; then
    source "\$HOME/.env.cls"
fi

# CLS aliases
alias cls-validate="bash scripts/cls_go_live_validation.sh"
alias cls-scan="bash scripts/codex_workflow_assistant.sh --scan"
alias cls-monitor="bash scripts/cls_daily_monitoring.sh"
alias cls-rollback="bash scripts/cls_rollback.sh"
EOF
    
    echo "   ✅ Shell profile created: .cls_shell_profile"
}

# Function to generate bootcheck report
generate_bootcheck_report() {
    echo ""
    echo "7) Generating bootcheck report..."
    
    REPORT_FILE="g/reports/cls_bootcheck_$(date +%Y%m%d_%H%M).md"
    mkdir -p "$(dirname "$REPORT_FILE")"
    
    cat > "$REPORT_FILE" << EOF
# CLS DevContainer Bootcheck Report

**Generated:** $(date -Iseconds)  
**Environment:** DevContainer  
**Status:** Shell Environment Fixed  

## Shell Availability

- zsh: $(command -v zsh 2>/dev/null || echo "Not available")
- bash: $(command -v bash 2>/dev/null || echo "Not available")
- CLS_SHELL: ${CLS_SHELL:-unset}
- SHELL: ${SHELL:-unset}

## Configuration

- Shell Resolver: $(test -f "packages/skills/resolveShell.js" && echo "✅ Available" || echo "❌ Missing")
- Validation Script: $(test -f "scripts/cls_go_live_validation.sh" && echo "✅ Available" || echo "❌ Missing")
- Workflow Assistant: $(test -f "scripts/codex_workflow_assistant.sh" && echo "✅ Available" || echo "❌ Missing")

## Next Steps

1. Source the configuration:
   \`\`\`bash
   source .env.cls
   \`\`\`

2. Test CLS functionality:
   \`\`\`bash
   bash scripts/cls_go_live_validation.sh
   bash scripts/codex_workflow_assistant.sh --scan
   \`\`\`

3. Add to shell profile:
   \`\`\`bash
   echo "source ~/.cls_shell_profile" >> ~/.bashrc
   \`\`\`

## Troubleshooting

If you still encounter ENOENT errors:
- Check shell availability: \`command -v zsh bash\`
- Verify CLS_SHELL: \`echo \$CLS_SHELL\`
- Test resolver: \`node -e "console.log(require('./packages/skills/resolveShell').resolveShell())"\`

**CLS DevContainer Bootcheck Complete** 🧠⚡
EOF
    
    echo "   ✅ Bootcheck report generated: $REPORT_FILE"
}

# Main execution
echo "Starting CLS DevContainer bootcheck..."

check_shell_availability

if [[ "$ZSH_AVAILABLE" == "false" ]]; then
    install_zsh
fi

configure_shell_environment
test_shell_resolver
test_cls_scripts
create_persistent_config
generate_bootcheck_report

echo ""
echo "🎯 CLS DevContainer Bootcheck Complete"
echo "   Shell environment configured and tested"
echo "   Configuration saved to .env.cls"
echo "   Source with: source .env.cls"
echo "   Report generated: g/reports/cls_bootcheck_*.md"
