#!/usr/bin/env bash
set -euo pipefail

# CLS Immediate Fix - Direct Shell Resolution
# Bypasses terminal access issues and applies fixes directly

echo "🧠 CLS Immediate Fix - Direct Resolution"
echo "======================================="

# Function to create shell configuration
create_shell_config() {
    echo "1) Creating shell configuration..."
    
    # Create configuration directory
    mkdir -p g/config
    
    # Create shell environment file
    cat > g/config/cls_shell.env << 'EOF'
# CLS Shell Configuration
export CLS_SHELL="/bin/bash"
export SHELL="/bin/bash"
export PATH="/usr/local/bin:/usr/bin:/bin"

# CLS aliases
alias cls-validate="bash scripts/cls_go_live_validation.sh"
alias cls-scan="bash scripts/codex_workflow_assistant.sh --scan"
alias cls-monitor="bash scripts/cls_daily_monitoring.sh"
alias cls-rollback="bash scripts/cls_rollback.sh"
alias cls-cutover="bash scripts/cls_final_cutover.sh"
alias cls-workflow="bash scripts/cls_complete_workflow.sh"
EOF
    
    echo "   ✅ Shell configuration created: g/config/cls_shell.env"
}

# Function to update shell resolver
update_shell_resolver() {
    echo ""
    echo "2) Updating shell resolver..."
    
    if [[ -f "packages/skills/resolveShell.js" ]]; then
        echo "   ✅ Shell resolver already exists"
    else
        echo "   Creating shell resolver..."
        mkdir -p packages/skills
        
        cat > packages/skills/resolveShell.js << 'EOF'
// packages/skills/resolveShell.js
const fs = require('fs');

function exists(p) { 
    try { 
        return p && fs.existsSync(p); 
    } catch { 
        return false; 
    } 
}

// Resolution order (left→right). You can override with env CLS_SHELL.
const CANDIDATES = [
    process.env.CLS_SHELL,     // explicit override
    process.env.SHELL,         // user shell
    '/bin/bash',
    '/usr/bin/bash',
    '/bin/zsh',
    '/usr/bin/zsh',
    '/bin/sh'
];

function resolveShell() {
    for (const p of CANDIDATES) {
        if (exists(p)) return p;
    }
    // Last resort: rely on system PATH
    return 'sh';
}

module.exports = { resolveShell };
EOF
        
        echo "   ✅ Shell resolver created"
    fi
}

# Function to create activation script
create_activation_script() {
    echo ""
    echo "3) Creating activation script..."
    
    cat > scripts/cls_activate.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# CLS Activation Script
# Sources shell configuration and activates CLS environment

echo "🧠 CLS Activation"
echo "================="

# Source shell configuration
if [[ -f "g/config/cls_shell.env" ]]; then
    source g/config/cls_shell.env
    echo "✅ CLS shell environment activated"
    echo "   CLS_SHELL: $CLS_SHELL"
    echo "   SHELL: $SHELL"
else
    echo "❌ CLS shell configuration not found"
    exit 1
fi

# Test shell resolver
if [[ -f "packages/skills/resolveShell.js" ]]; then
    echo "   Testing shell resolver..."
    RESOLVED=$(node -e "console.log(require('./packages/skills/resolveShell').resolveShell())" 2>/dev/null || echo "unknown")
    echo "   Resolved shell: $RESOLVED"
    
    if [[ "$RESOLVED" == "/bin/bash" ]] || [[ "$RESOLVED" == "/usr/bin/bash" ]]; then
        echo "   ✅ Shell resolver working correctly"
    else
        echo "   ⚠️  Shell resolver returned unexpected value"
    fi
else
    echo "   ⚠️  Shell resolver not found"
fi

echo ""
echo "🎯 CLS Environment Activated"
echo "   Available commands:"
echo "   - cls-validate: Run CLS validation"
echo "   - cls-scan: Run workflow scan"
echo "   - cls-monitor: Run daily monitoring"
echo "   - cls-rollback: Emergency rollback"
echo "   - cls-cutover: Production cutover"
echo "   - cls-workflow: Complete workflow"
EOF
    
    chmod +x scripts/cls_activate.sh
    echo "   ✅ Activation script created: scripts/cls_activate.sh"
}

# Function to create quick test script
create_test_script() {
    echo ""
    echo "4) Creating quick test script..."
    
    cat > scripts/cls_quick_test.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# CLS Quick Test
# Tests core CLS functionality without full validation

echo "🧠 CLS Quick Test"
echo "================="

# Test 1: Shell resolver
echo "1) Testing shell resolver..."
if [[ -f "packages/skills/resolveShell.js" ]]; then
    RESOLVED=$(node -e "console.log(require('./packages/skills/resolveShell').resolveShell())" 2>/dev/null || echo "unknown")
    echo "   Resolved shell: $RESOLVED"
    
    if [[ "$RESOLVED" == "/bin/bash" ]] || [[ "$RESOLVED" == "/usr/bin/bash" ]]; then
        echo "   ✅ Shell resolver working"
    else
        echo "   ❌ Shell resolver failed"
    fi
else
    echo "   ❌ Shell resolver not found"
fi

# Test 2: Script availability
echo ""
echo "2) Testing script availability..."
SCRIPTS=(
    "scripts/cls_go_live_validation.sh"
    "scripts/codex_workflow_assistant.sh"
    "scripts/cls_daily_monitoring.sh"
    "scripts/cls_rollback.sh"
    "scripts/cls_final_cutover.sh"
    "scripts/cls_complete_workflow.sh"
)

for script in "${SCRIPTS[@]}"; do
    if [[ -f "$script" ]]; then
        echo "   ✅ $script"
    else
        echo "   ❌ $script"
    fi
done

# Test 3: LaunchAgent files
echo ""
echo "3) Testing LaunchAgent files..."
LAUNCHAGENTS=(
    "Library/LaunchAgents/com.02luka.cls.verification.plist"
    "Library/LaunchAgents/com.02luka.cls.workflow.plist"
)

for plist in "${LAUNCHAGENTS[@]}"; do
    if [[ -f "$plist" ]]; then
        echo "   ✅ $plist"
    else
        echo "   ❌ $plist"
    fi
done

echo ""
echo "🎯 CLS Quick Test Complete"
echo "   All core components checked"
EOF
    
    chmod +x scripts/cls_quick_test.sh
    echo "   ✅ Quick test script created: scripts/cls_quick_test.sh"
}

# Function to create fix report
create_fix_report() {
    echo ""
    echo "5) Creating fix report..."
    
    REPORT_FILE="g/reports/cls_immediate_fix_$(date +%Y%m%d_%H%M).md"
    mkdir -p "$(dirname "$REPORT_FILE")"
    
    cat > "$REPORT_FILE" << EOF
# CLS Immediate Fix Report

**Generated:** $(date -Iseconds)  
**Status:** Shell Environment Fixed  

## Fix Applied

- Shell Configuration: g/config/cls_shell.env
- Shell Resolver: packages/skills/resolveShell.js
- Activation Script: scripts/cls_activate.sh
- Quick Test: scripts/cls_quick_test.sh

## Next Steps

1. **Activate CLS Environment:**
   \`\`\`bash
   source g/config/cls_shell.env
   \`\`\`

2. **Run Quick Test:**
   \`\`\`bash
   bash scripts/cls_quick_test.sh
   \`\`\`

3. **Run Full Validation:**
   \`\`\`bash
   bash scripts/cls_go_live_validation.sh
   \`\`\`

4. **Test Workflow Scan:**
   \`\`\`bash
   bash scripts/codex_workflow_assistant.sh --scan
   \`\`\`

## Available Commands

- \`cls-validate\` - Run CLS validation
- \`cls-scan\` - Run workflow scan
- \`cls-monitor\` - Run daily monitoring
- \`cls-rollback\` - Emergency rollback
- \`cls-cutover\` - Production cutover
- \`cls-workflow\` - Complete workflow

## Troubleshooting

If you still encounter issues:
1. Check shell availability: \`command -v bash\`
2. Verify CLS_SHELL: \`echo \$CLS_SHELL\`
3. Test resolver: \`node -e "console.log(require('./packages/skills/resolveShell').resolveShell())"\`

**CLS Immediate Fix Complete** 🧠⚡
EOF
    
    echo "   ✅ Fix report generated: $REPORT_FILE"
}

# Main execution
echo "Starting CLS immediate fix..."

create_shell_config
update_shell_resolver
create_activation_script
create_test_script
create_fix_report

echo ""
echo "🎯 CLS Immediate Fix Complete"
echo "   Shell environment fixed and configured"
echo "   Configuration: g/config/cls_shell.env"
echo "   Activation: source g/config/cls_shell.env"
echo "   Quick test: bash scripts/cls_quick_test.sh"
echo "   Report: g/reports/cls_immediate_fix_*.md"
