# tools/_archive/

This directory contains **legacy/deprecated** scripts that have been archived.

## Purpose

- **Reduce noise** in sandbox checks (archived files not scanned)
- **Preserve history** for reference
- **Clear separation** from active tools

## Files

| File | Replaced By | Archive Date |
|------|-------------|--------------|
| clear_mem_optimized.zsh | mole_headless_clean.zsh | 2025-12-19 |

## Rules

1. All files here MUST have `# LEGACY` header
2. Include `Replaced by: <path>` in header
3. Never call these scripts directly
4. Keep for reference only
