# Claude Code Mobile Setup Guide

**Created:** 2025-11-05
**For:** Accessing 02luka system from Claude Code mobile app

---

## 🎯 Goal

Access your 02luka operational data on mobile devices through Claude Code app with full context awareness.

---

## ✅ Step 1: Verify GitHub Push

Your operational data is now on GitHub!

**Repository:** https://github.com/Ic1558/02luka
**Branch:** `clc/operational-data-v2.0.2`

**What's included:**
- Dashboard v2.0.2
- All reports and roadmaps
- MLS knowledge base
- Progress tracking
- Manuals and guides

---

## 📱 Step 2: Mobile Access Methods

### Method A: Via GitHub Mobile (Read-Only, Instant)

1. **Install GitHub app** on your mobile device
2. **Navigate to:** https://github.com/Ic1558/02luka
3. **Switch to branch:** `clc/operational-data-v2.0.2`
4. **View files:**
   - `CLAUDE_CONTEXT.md` - Main context file
   - `roadmaps/ROADMAP_*.md` - Project roadmaps
   - `reports/ROADMAP_ACCELERATION_*.md` - Latest progress
   - `apps/dashboard/dashboard_data.json` - Current system state

### Method B: Via Google Drive (Full Access, Synced)

1. **Already configured** - Your `~/02luka/` syncs to Google Drive
2. **On mobile:** Open Google Drive app
3. **Navigate to:** My Drive → 02luka → g
4. **All files accessible** in real-time (updated every 4 hours)

### Method C: Via Claude Code Mobile + GitHub (Recommended)

1. **Open Claude Code app** on mobile
2. **When starting conversation:**
   ```
   I'm working on the 02luka project.
   Context at: github.com/Ic1558/02luka branch clc/operational-data-v2.0.2
   Please read CLAUDE_CONTEXT.md for current state.
   ```
3. **Claude Code will:**
   - Fetch the context from GitHub
   - Understand your system state
   - Answer questions about roadmap, agents, etc.

---

## 🔍 Step 3: Key Files for Mobile

When using Claude Code mobile, reference these files:

### Must-Read Context
```
CLAUDE_CONTEXT.md          # Complete system overview
README.md                  # Quick reference
```

### Current State
```
apps/dashboard/dashboard_data.json           # Real-time metrics
roadmaps/ROADMAP_2025-11-04_autonomous_systems.md  # Roadmap (70% complete)
progress/current_progress.json                # Progress tracking
```

### Latest Work
```
reports/ROADMAP_ACCELERATION_20251105.md     # Latest achievement
reports/AGENT_IMPROVEMENTS_20251105.md       # Agent fixes
reports/sessions/session_*.md                # Recent sessions
```

### Knowledge Base
```
knowledge/mls_lessons.jsonl      # Lessons learned (15+)
knowledge/delegations.jsonl      # Delegation records
```

---

## 💬 Step 4: Example Mobile Conversations

### Checking System Status

**You say:**
```
What's the current status of 02luka?
Context: github.com/Ic1558/02luka branch clc/operational-data-v2.0.2
Read: CLAUDE_CONTEXT.md
```

**Claude Code will know:**
- Roadmap at 70% complete
- Phase 3 in progress (Ollama integration)
- 4 WOs executed successfully
- All agents stable

### Checking Specific Phase

**You say:**
```
What's the status of Phase 3?
Repo: github.com/Ic1558/02luka branch clc/operational-data-v2.0.2
Read: roadmaps/ROADMAP_2025-11-04_autonomous_systems.md
```

**Claude Code will tell you:**
- Phase 3: Local AI Integration (50% complete)
- Ollama installed (v0.12.9)
- qwen2.5:0.5b model ready
- Next: Integrate with expense OCR

### Viewing Recent Work

**You say:**
```
What was accomplished recently?
Repo: github.com/Ic1558/02luka branch clc/operational-data-v2.0.2
Read: reports/ROADMAP_ACCELERATION_20251105.md
```

**Claude Code will show:**
- Roadmap acceleration (40% → 70%)
- Dashboard v2.0.2 deployed
- Ollama integration complete
- Agent thrashing fixed

---

## 🔄 Step 5: Keeping Mobile Synced

### Auto-Sync (Google Drive)
- **Desktop changes** → Synced to Google Drive → **Mobile sees updates**
- **Sync frequency:** Every 4 hours (automatic)
- **No action needed** - happens in background

### Manual GitHub Sync
When you make changes on desktop:

```bash
cd ~/02luka/g
git add -A
git commit -m "Update: describe your changes"
git push origin clc/operational-data-v2.0.2
```

Then on mobile, Claude Code will fetch latest from GitHub automatically.

---

## 📋 Step 6: Mobile-Specific Commands

### Quick Status Check (Copy-Paste for Mobile)

```
Check 02luka status:
- Repo: github.com/Ic1558/02luka
- Branch: clc/operational-data-v2.0.2
- Read: apps/dashboard/dashboard_data.json
Show: roadmap progress, running services, completed WOs
```

### View Latest Report (Copy-Paste for Mobile)

```
Show latest work:
- Repo: github.com/Ic1558/02luka
- Branch: clc/operational-data-v2.0.2
- Read: reports/ROADMAP_ACCELERATION_20251105.md
Summarize in bullet points
```

### Check Agent Health (Copy-Paste for Mobile)

```
Agent status:
- Repo: github.com/Ic1558/02luka
- Branch: clc/operational-data-v2.0.2
- Read: reports/AGENT_IMPROVEMENTS_20251105.md
Are all agents healthy?
```

---

## 🛠️ Troubleshooting

### "Claude Code can't access GitHub"
- Make sure repo is public, OR
- Provide context file content directly in chat

### "File not found on mobile"
- Verify branch: `clc/operational-data-v2.0.2`
- Check file path (case-sensitive)

### "Data seems outdated"
On desktop, run:
```bash
cd ~/02luka/g
git status
git push origin clc/operational-data-v2.0.2
```

---

## 📊 What's Synced

### ✅ Included in GitHub (Always Available)
- Roadmaps and reports
- Dashboard data
- Knowledge base (MLS lessons)
- Manuals and guides
- Session history

### ❌ Not in GitHub (Desktop Only)
- Live logs (`~/02luka/logs/`)
- Running agents (`~/02luka/agents/`)
- System config (`~/02luka/config/`)
- LaunchAgents (`~/Library/LaunchAgents/`)

**Why?** These are runtime files that change constantly and contain system-specific paths.

---

## 🎓 Best Practices

### DO ✅
- Start conversations with repo context
- Reference specific files when asking questions
- Use pre-made command templates (Step 6)
- Check CLAUDE_CONTEXT.md first

### DON'T ❌
- Try to edit files on mobile (read-only mode)
- Assume mobile Claude knows desktop file paths
- Forget to specify branch name
- Mix up `~/02luka/` paths with GitHub paths

---

## 📱 Mobile Workflow Example

**Morning routine on mobile:**

1. Open Claude Code app
2. Paste:
   ```
   Good morning! Check 02luka system status.
   Repo: github.com/Ic1558/02luka branch clc/operational-data-v2.0.2
   Read: CLAUDE_CONTEXT.md and apps/dashboard/dashboard_data.json
   Summary: roadmap progress, agent health, recent accomplishments
   ```
3. Claude Code responds with full status
4. You can ask follow-up questions with full context

---

## 🔐 Security Note

**Public Repository:**
- This repo contains operational data only
- No secrets, credentials, or API keys
- Safe to share with mobile Claude Code

**Private Data:**
- Secrets stay in `~/.config/02luka/` (not in repo)
- No sensitive paths exposed

---

## ✅ Verification Checklist

Before using on mobile, verify:

- [ ] GitHub repo exists: https://github.com/Ic1558/02luka
- [ ] Branch exists: `clc/operational-data-v2.0.2`
- [ ] CLAUDE_CONTEXT.md is readable
- [ ] dashboard_data.json shows 70% roadmap
- [ ] Google Drive sync is active (optional)

---

## 🚀 Next Steps

1. **Test on mobile now:**
   - Open Claude Code app
   - Try the "Quick Status Check" command from Step 6
   - Verify it reads the context correctly

2. **Bookmark this guide:**
   - On GitHub: https://github.com/Ic1558/02luka/blob/clc/operational-data-v2.0.2/MOBILE_SETUP_GUIDE.md

3. **Update when needed:**
   - After major changes, commit and push from desktop
   - Mobile will always have latest context

---

**Questions?** Check CLAUDE_CONTEXT.md for detailed system information.

**Last Updated:** 2025-11-05 06:40 ICT
