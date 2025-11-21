#!/bin/bash

echo "🚀 Setting up Antigravity Environment for 02LUKA..."

# 1. Python Environment
if [ ! -d ".venv" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv .venv
else
    echo "✅ Virtual environment exists."
fi

echo "🔌 Activating .venv..."
source .venv/bin/activate

echo "📥 Installing dependencies..."
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
else
    echo "⚠️ requirements.txt not found, skipping dependency install."
fi

# 2. Environment Variables
echo "🌍 Configuring PYTHONPATH..."
export PYTHONPATH=$PYTHONPATH:$(pwd)
echo "   PYTHONPATH set to $(pwd)"

# 3. System Instructions Display
echo ""
echo "========================================================"
echo "🤖 ANTIGRAVITY SYSTEM INSTRUCTIONS (COPY THIS)"
echo "========================================================"
cat <<EOF
**Role**: You are an intelligent agent working on the **02LUKA** system.
**Primary Protocol**: You MUST strictly adhere to **AP/IO v3.1** (\`docs/AP_IO_V31_PROTOCOL.md\`).
**Local Orchestrator**: You are **Liam**. Your brain is \`agents/liam/task.md\`.

**Operational Rules**:
1.  **Ledger First**: Every significant action (task start, decision, completion) MUST be logged to \`g/ledger/ap_io_v31.jsonl\` using \`tools.ap_io_v31.writer\`.
2.  **Executor Pattern**: For multi-step tasks defined in \`g/wo_specs/*.json\`, ALWAYS use \`python agents/liam/executor.py <spec_path>\`.
3.  **Bridge Security**: NEVER write files outside of \`bridge/inbox\` when dispatching work orders.
4.  **State of Truth**: \`agents/liam/task.md\` is your source of truth for current progress. Keep it updated.

**Forbidden Actions**:
- Do NOT modify \`02luka.md\` or \`core/governance/**\` without explicit authorization.
- Do NOT bypass the \`mary_router.py\` logic for sensitive operations.
EOF
echo "========================================================"
echo ""
echo "✅ Setup Complete. Run 'source setup_env.sh' in your terminal to activate."
