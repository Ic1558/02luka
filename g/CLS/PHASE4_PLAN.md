# Phase 4 - Advanced Decision-Making (Plan)

**Status:** Basic policy engine installed
**Date:** 2025-10-30

## Artifacts

- ~/tools/cls_policy_eval.zsh - Policy evaluation engine
- ~/02luka/memory/cls/policies.json - Policy rules
- ~/02luka/g/logs/cls_phase4.log - Decision log

## Behavior

Evaluates actions (command, optional path), returns decision (allow|ask|deny) with confidence and rule.

## Quick Tests

```bash
# Low-risk commands (should allow)
~/tools/cls_policy_eval.zsh evaluate ls
~/tools/cls_policy_eval.zsh evaluate echo

# Safe-zone writes (should allow)
~/tools/cls_policy_eval.zsh evaluate touch "$HOME/02luka/g/tmp.txt"

# Sensitive paths (should deny)
~/tools/cls_policy_eval.zsh evaluate rm /etc/hosts

# Check logs
tail -n 50 ~/02luka/g/logs/cls_phase4.log
```

## Next Steps

- Expand policy rules (learning-based)
- Add approval workflow integration
- Implement confidence scoring improvements
