# DEPRECATED: Complex Validation System

## ⚠️ DO NOT USE

These files are deprecated and kept only as reference examples of over-engineering:

- `validation.config.yml` - 400+ lines of unnecessary config
- `validation-hooks/` - Unused hook system
- `../tools/global_validate.sh` - 300+ lines of complex code
- `../tools/lib/validation_smart.sh` - 600+ lines of abstractions
- `../docs/global-validation.md` - Documentation for unused system

## Why Deprecated?

1. **Over-engineered**: 1500+ lines for what 45 lines does better
2. **No clear value**: Hooks, caching, parallel workers for 5 checks?
3. **Hard to maintain**: Complex abstractions nobody needs
4. **Display issues**: Output doesn't work properly
5. **Heavy dependencies**: yq, jq, complex bash arrays

## What to Use Instead

### ✅ tools/validate.sh (80 lines)
Simple wrapper around existing smoke.sh:
```bash
# Standard validation
./tools/validate.sh

# JSON output for CI
./tools/validate.sh --json

# Save metrics
./tools/validate.sh --metrics
```

### ✅ scripts/smoke.sh (45 lines)
The core validation that actually works:
- Clear, focused checks
- Beautiful output
- Fast and reliable
- Easy to maintain

## Lessons Learned

1. **Simple > Complex** - Don't add complexity without clear value
2. **Respect what works** - smoke.sh is excellent, don't replace it
3. **Measure value** - Every feature should solve a real problem
4. **YAGNI** - You Aren't Gonna Need It
5. **Maintainability** - Can you understand it in 6 months?

## Documentation

See `docs/validation-redesign.md` for full explanation of why simplicity wins.

## Should These Be Deleted?

Probably yes, but keeping temporarily as:
- Example of what not to do
- Reference for learning
- Reminder to stay simple

**If you're reading this, use `tools/validate.sh` instead.**

---
Last updated: 2025-01-15
Status: DEPRECATED - DO NOT USE
Replacement: tools/validate.sh
