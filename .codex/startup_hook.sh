#!/usr/bin/env bash
# Startup Hook for Hybrid Memory System
# This script runs when the project is opened

set -euo pipefail

# Add to .bashrc for auto-start
if ! grep -q "02luka-hybrid-memory" ~/.bashrc 2>/dev/null; then
    cat >> ~/.bashrc << 'EOF'

# 02luka Hybrid Memory System Auto-start
if [ -f "/workspaces/02luka-repo/.codex/auto_start.sh" ]; then
    cd /workspaces/02luka-repo
    bash .codex/auto_start.sh
fi
EOF
    echo "✅ Added auto-start to .bashrc"
fi

# Create desktop entry for easy access
cat > ~/.local/share/applications/02luka-hybrid-memory.desktop << EOF
[Desktop Entry]
Name=02luka Hybrid Memory
Comment=Start 02luka with Hybrid Memory System
Exec=bash /workspaces/02luka-repo/.codex/auto_start.sh
Icon=applications-development
Terminal=true
Type=Application
Categories=Development;
EOF

echo "✅ Created desktop entry"

# Create alias for easy access
if ! grep -q "02luka-memory" ~/.bashrc 2>/dev/null; then
    cat >> ~/.bashrc << 'EOF'

# 02luka Hybrid Memory aliases
alias 02luka-memory='cd /workspaces/02luka-repo && bash .codex/auto_start.sh'
alias 02luka-save='cd /workspaces/02luka-repo && bash .codex/save_context.sh'
alias 02luka-load='cd /workspaces/02luka-repo && bash .codex/load_context.sh'
alias 02luka-adapt='cd /workspaces/02luka-repo && bash .codex/adapt_style.sh'
EOF
    echo "✅ Added aliases to .bashrc"
fi

echo "🎯 Hybrid Memory System startup hook installed!"
echo "   - Auto-start on terminal open"
echo "   - Desktop entry created"
echo "   - Aliases added: 02luka-memory, 02luka-save, 02luka-load, 02luka-adapt"






