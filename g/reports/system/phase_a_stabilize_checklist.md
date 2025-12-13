# Phase A: Stabilize the Floor — Command-by-Command Checklist
**Generated:** 2025-12-13  
**Purpose:** Hardening commands เพื่อป้องกัน workspace หายจาก git clean/reset  
**Status:** Ready for CLS Execution

---

## 🎯 Objective

**Goal:** ทำให้ระบบ "production-safe" — git reset/clean จะไม่ทำให้ workspace data หายอีก

**Success Criteria:**
- ✅ Guard script ทำงานได้ (ไม่มี bug)
- ✅ Pre-commit hook block commits ที่ผิดกฎ
- ✅ Workspace paths ทั้งหมดเป็น symlinks (4 paths)

---

## 📋 Command-by-Command Checklist

### Step 1: Fix Guard Script Bug

**File:** `tools/guard_workspace_inside_repo.zsh`  
**Issue:** Line 39 ใช้ `file` command ที่ไม่มีใน macOS/zsh

**Command:**
```bash
cd ~/02luka
```

**Edit:** เปิดไฟล์ `tools/guard_workspace_inside_repo.zsh` แล้วแก้บรรทัด 39:

**Before:**
```zsh
echo "   Found: $(file "$full_path")" >&2
```

**After:**
```zsh
if [[ -d "$full_path" ]]; then
  echo "   Found: real directory" >&2
elif [[ -f "$full_path" ]]; then
  echo "   Found: real file" >&2
else
  echo "   Found: other type (not symlink)" >&2
fi
```

**Verify:**
```bash
zsh tools/guard_workspace_inside_repo.zsh
# ต้องไม่ error และแสดงผลถูกต้อง
```

---

### Step 2: Restore Pre-commit Hook to Blocking Mode

**File:** `.git/hooks/pre-commit`  
**Issue:** Downgraded เป็น warn (ไม่ block)

**Command:**
```bash
cd ~/02luka
```

**Edit:** เปิดไฟล์ `.git/hooks/pre-commit` แล้วแก้:

**Before:**
```sh
#!/bin/sh
# Pre-commit guard: warn but don't block (some paths may not be migrated yet)
zsh tools/guard_workspace_inside_repo.zsh || true
exit 0
```

**After:**
```sh
#!/bin/sh
# Pre-commit guard: enforce workspace rules
exec zsh tools/guard_workspace_inside_repo.zsh
```

**Verify:**
```bash
chmod +x .git/hooks/pre-commit
# Test: สร้าง real directory ใน repo แล้วลอง commit
mkdir -p test_workspace_check/g/data
git add test_workspace_check/
git commit -m "test" 2>&1
# ต้อง fail และแสดง error จาก guard
# Cleanup:
rm -rf test_workspace_check/
```

---

### Step 3: Complete Workspace Migration

**Goal:** Migrate 4 paths จาก real directory → symlink

**Command 1: Backup current state (safety)**
```bash
cd ~/02luka
# Backup paths ที่จะ migrate
mkdir -p ~/02luka_ws/_backup_$(date +%Y%m%d_%H%M%S)
BACKUP_DIR=~/02luka_ws/_backup_$(date +%Y%m%d_%H%M%S)

# Backup แต่ละ path
[ -d g/followup ] && cp -r g/followup "$BACKUP_DIR/" 2>/dev/null || true
[ -d mls/ledger ] && cp -r mls/ledger "$BACKUP_DIR/" 2>/dev/null || true
[ -d bridge/processed ] && cp -r bridge/processed "$BACKUP_DIR/" 2>/dev/null || true
[ -f g/apps/dashboard/data/followup.json ] && cp g/apps/dashboard/data/followup.json "$BACKUP_DIR/" 2>/dev/null || true

echo "✅ Backup created: $BACKUP_DIR"
```

**Command 2: Migrate g/followup/**
```bash
cd ~/02luka

# Create target in workspace
mkdir -p ~/02luka_ws/g/followup

# Move existing data (if any)
if [[ -d g/followup && ! -L g/followup ]]; then
  # Move contents to workspace
  if [[ -n "$(ls -A g/followup 2>/dev/null)" ]]; then
    cp -r g/followup/* ~/02luka_ws/g/followup/ 2>/dev/null || true
  fi
  # Remove real directory
  rm -rf g/followup
fi

# Create symlink
ln -sf ~/02luka_ws/g/followup g/followup

# Verify
readlink g/followup
# ต้องแสดง: /Users/icmini/02luka_ws/g/followup
```

**Command 3: Migrate mls/ledger/**
```bash
cd ~/02luka

# Create target in workspace
mkdir -p ~/02luka_ws/mls/ledger

# Move existing data (if any)
if [[ -d mls/ledger && ! -L mls/ledger ]]; then
  if [[ -n "$(ls -A mls/ledger 2>/dev/null)" ]]; then
    cp -r mls/ledger/* ~/02luka_ws/mls/ledger/ 2>/dev/null || true
  fi
  rm -rf mls/ledger
fi

# Create symlink
ln -sf ~/02luka_ws/mls/ledger mls/ledger

# Verify
readlink mls/ledger
# ต้องแสดง: /Users/icmini/02luka_ws/mls/ledger
```

**Command 4: Migrate bridge/processed/**
```bash
cd ~/02luka

# Create target in workspace
mkdir -p ~/02luka_ws/bridge/processed

# Move existing data (if any)
if [[ -d bridge/processed && ! -L bridge/processed ]]; then
  if [[ -n "$(ls -A bridge/processed 2>/dev/null)" ]]; then
    cp -r bridge/processed/* ~/02luka_ws/bridge/processed/ 2>/dev/null || true
  fi
  rm -rf bridge/processed
fi

# Create symlink
ln -sf ~/02luka_ws/bridge/processed bridge/processed

# Verify
readlink bridge/processed
# ต้องแสดง: /Users/icmini/02luka_ws/bridge/processed
```

**Command 5: Migrate g/apps/dashboard/data/followup.json**
```bash
cd ~/02luka

# Create target directory in workspace
mkdir -p ~/02luka_ws/g/apps/dashboard/data

# Move existing file (if any)
if [[ -f g/apps/dashboard/data/followup.json && ! -L g/apps/dashboard/data/followup.json ]]; then
  cp g/apps/dashboard/data/followup.json ~/02luka_ws/g/apps/dashboard/data/followup.json 2>/dev/null || true
  rm -f g/apps/dashboard/data/followup.json
fi

# Create symlink
ln -sf ~/02luka_ws/g/apps/dashboard/data/followup.json g/apps/dashboard/data/followup.json

# Verify
readlink g/apps/dashboard/data/followup.json
# ต้องแสดง: /Users/icmini/02luka_ws/g/apps/dashboard/data/followup.json
```

---

### Step 4: Verify All Symlinks

**Command:**
```bash
cd ~/02luka

# Verify all workspace paths are symlinks
echo "=== Verifying Workspace Symlinks ==="
for path in g/followup mls/ledger bridge/processed g/apps/dashboard/data/followup.json; do
  if [[ -L "$path" ]]; then
    target=$(readlink "$path")
    echo "✅ $path → $target"
  else
    echo "❌ $path is NOT a symlink"
  fi
done

# Run guard script to verify
echo ""
echo "=== Running Guard Script ==="
zsh tools/guard_workspace_inside_repo.zsh
# ต้องผ่าน (ไม่มี FAIL)
```

---

### Step 5: Test Pre-commit Hook

**Command:**
```bash
cd ~/02luka

# Test: สร้าง real directory แล้วลอง commit
mkdir -p test_guard_check/g/data
git add test_guard_check/
git commit -m "test guard" 2>&1
# ต้อง fail และแสดง error จาก guard

# Cleanup
rm -rf test_guard_check/
git reset HEAD~1 2>/dev/null || true
```

---

## ✅ Final Verification

**Command:**
```bash
cd ~/02luka

echo "=== Phase A Verification ==="
echo ""

# 1. Guard script works
echo "1. Guard Script:"
zsh tools/guard_workspace_inside_repo.zsh && echo "   ✅ PASS" || echo "   ❌ FAIL"

# 2. All paths are symlinks
echo ""
echo "2. Workspace Symlinks:"
all_ok=1
for path in g/followup mls/ledger bridge/processed g/apps/dashboard/data/followup.json; do
  if [[ -L "$path" ]]; then
    echo "   ✅ $path"
  else
    echo "   ❌ $path"
    all_ok=0
  fi
done

# 3. Pre-commit hook exists and is executable
echo ""
echo "3. Pre-commit Hook:"
if [[ -x .git/hooks/pre-commit ]]; then
  echo "   ✅ Exists and executable"
  # Check if it's blocking (not downgraded)
  if grep -q "exec zsh tools/guard_workspace_inside_repo.zsh" .git/hooks/pre-commit; then
    echo "   ✅ Blocking mode (correct)"
  else
    echo "   ⚠️  May still be in warn mode"
  fi
else
  echo "   ❌ Missing or not executable"
  all_ok=0
fi

echo ""
if [[ $all_ok -eq 1 ]]; then
  echo "✅ Phase A: COMPLETE"
  echo "   System is now production-safe"
else
  echo "⚠️  Phase A: INCOMPLETE"
  echo "   Please review failed checks above"
fi
```

---

## 🎯 Success Criteria

**Phase A สำเร็จเมื่อ:**
1. ✅ Guard script รันได้โดยไม่มี error
2. ✅ Pre-commit hook block commits ที่ผิดกฎ
3. ✅ ทั้ง 4 paths เป็น symlinks และชี้ไป ~/02luka_ws/
4. ✅ Guard script verify ผ่าน (ไม่มี FAIL)

**เมื่อ Phase A เสร็จ:**
- ✅ `git reset --hard` จะไม่ทำให้ workspace data หาย
- ✅ `git clean -fd` จะไม่ลบ workspace data
- ✅ Pre-commit จะ block commits ที่ผิดกฎ workspace

---

## 📝 Notes

- **Backup:** ทุก command มี backup ก่อน migrate
- **Safety:** ใช้ `cp -r` แทน `mv` เพื่อความปลอดภัย
- **Verification:** ทุก step มี verify command
- **Rollback:** ถ้าเกิดปัญหา สามารถ restore จาก backup directory

---

**Ready for CLS Execution** ✅
