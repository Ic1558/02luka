# Phase 19 — CI Hygiene & Health Snapshot

## What

- **.gitignore** updates: ignore logs/tmp/artifacts to keep the repo clean.

- **tools/ci/health_snapshot.sh**: quick CI overview for open PRs.

  - Requires `gh` CLI (local/dev convenience)

  - Writes reports to `g/reports/ci/health_*.md`

## Why

- Reduce accidental noisy commits (logs/tmp).

- One command to see PR + checks status (for triage).

## Usage

```bash
tools/ci/health_snapshot.sh           # default (20 PRs)
tools/ci/health_snapshot.sh 50        # increase limit
```

## GC Flags

The `ci:health:gc` command supports multiple flags for safe garbage collection:

```bash
# Dry-run (default, safe)
./tools/dispatch_quick.zsh ci:health:gc                # 7 วัน (default)
./tools/dispatch_quick.zsh ci:health:gc 14             # 14 วัน (dry-run)

# ลบจริง (ต้องใส่ --force)
./tools/dispatch_quick.zsh ci:health:gc 14 --force

# ล้างไฟล์ทุกอายุแบบลองก่อน
./tools/dispatch_quick.zsh ci:health:gc --all

# ล้างทุกอายุลบจริง
./tools/dispatch_quick.zsh ci:health:gc --all --force

# ไม่ลบโฟลเดอร์ว่าง (แม้ใช้ --force)
./tools/dispatch_quick.zsh ci:health:gc --all --force --no-prune-empty
```

### Safety Matrix

| Flag | Description | Default |
|------|-------------|---------|
| `[DAYS]` | Keep files newer than N days | 7 |
| `--force` | Actually delete files (required for deletion) | dry-run |
| `--all` | Ignore age filter, operate on ALL files | age-based |
| `--no-prune-empty` | Do NOT prune empty directories (even with --force) | prune enabled |
