#!/usr/bin/env zsh
set -euo pipefail

BASE="${LUKA_SOT:-$HOME/02luka}"
INBOX="$BASE/bridge/inbox/main"

echo "📝 PR-10 CLS Auto-Approve Test"
echo ""

############################
# Case 1: Templates
############################
echo "📥 Creating Case 1: Templates..."

cat > "$INBOX/WO-PR10-CLS-TEMPLATE.yaml" <<'YAML'
wo_id: WO-PR10-CLS-TEMPLATE
version: v1
source: pr10_cls_template
trigger: cursor
actor: CLS

target_paths:
  - "bridge/templates/pr10_auto_approve_email.html"

context:
  rollback_strategy: git_revert
  boss_approved_pattern: "template_updates"

operations:
  - type: write_file
    path: "bridge/templates/pr10_auto_approve_email.html"
    mode: replace
    content: |
      <!-- PR-10 CLS auto-approve test (templates) -->
      <p>This change was auto-approved by CLS under mission scope.</p>
YAML

echo "✅ Created: WO-PR10-CLS-TEMPLATE.yaml"

############################
# Case 2: Docs
############################
echo ""
echo "📥 Creating Case 2: Docs..."

cat > "$INBOX/WO-PR10-CLS-DOC.yaml" <<'YAML'
wo_id: WO-PR10-CLS-DOC
version: v1
source: pr10_cls_doc
trigger: cursor
actor: CLS

target_paths:
  - "bridge/docs/pr10_auto_approve_note.md"

context:
  rollback_strategy: git_revert
  boss_approved_pattern: "docs_updates"

operations:
  - type: write_file
    path: "bridge/docs/pr10_auto_approve_note.md"
    mode: replace
    content: |
      PR-10 CLS auto-approve test (docs)

      This note was written under CLS mission scope auto-approve.
YAML

echo "✅ Created: WO-PR10-CLS-DOC.yaml"

echo ""
echo "✅ PR-10 WOs created"
echo ""
echo "⏳ Waiting for gateway/router to process..."
echo "   Then run: zsh $BASE/tools/pr10_verify.zsh"

