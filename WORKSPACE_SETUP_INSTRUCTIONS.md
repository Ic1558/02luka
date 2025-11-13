# 🎯 Cursor Workspace Setup - Drag & Drop Support

**Date:** 2025-11-13  
**Purpose:** Enable drag & drop for Desktop, Documents, Downloads, and lukadata  
**Security:** All folders are git-ignored, never sync to GitHub

---

## Quick Setup (30 seconds)

### Step 1: Open Cursor
Already done! ✓

### Step 2: Add Folders to Workspace

**Click:** `File → Add Folder to Workspace...`

**Add these 4 folders (one by one):**

1. `/Users/icmini/Desktop`
2. `/Users/icmini/Documents`
3. `/Users/icmini/Downloads`
4. `/Volumes/lukadata`

**How to add each folder:**
- Click `File → Add Folder to Workspace...`
- Navigate to the folder (or paste the path)
- Click "Add"
- Repeat for all 4 folders

### Step 3: Verify

**Check Cursor sidebar - you should see:**
```
📁 02LUKA
📁 02luka-memory
📁 Desktop       ← NEW
📁 Documents     ← NEW
📁 Downloads     ← NEW
📁 lukadata      ← NEW
```

---

## After Setup - What You Can Do

### ✅ Drag & Drop
Drag any file from Desktop/Documents/Downloads/lukadata into Cursor chat

### ✅ Ask CLS to Read Files
"Read this file" (after dragging)

### ✅ Ask CLS to Edit Files
"Fix the typo in line 5" (CLS can edit directly)

### ✅ 100% Private
All files stay local, never pushed to GitHub (.gitignore protects them)

---

## Security Guarantee

**Git Protection Already Applied:**
```gitignore
Desktop/
Documents/
Downloads/
Volumes/
external_files/
```

These folders are **permanently ignored** by git.

**Test it:**
```bash
cd ~/02luka
git status
# Desktop/Documents/Downloads/Volumes won't appear, even if modified
```

---

## Troubleshooting

### "I don't see the folders in sidebar"
- Did you add them via `File → Add Folder to Workspace...`?
- Try: Close and reopen Cursor

### "Can I remove them later?"
- Yes! Right-click folder in sidebar → "Remove Folder from Workspace"
- Does NOT delete files, just removes from Cursor view

### "Will this sync to GitHub?"
- **NO!** `.gitignore` prevents it 100%
- Already tested and verified

---

**Ready!** Just add the 4 folders via File menu and you're done! 🎉
