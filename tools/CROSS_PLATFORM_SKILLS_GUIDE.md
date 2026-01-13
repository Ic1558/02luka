# Cross-Platform Agent Skills Guide

## TL;DR: YES, Skills Can Be Shared! 🎉

**Agent Skills use an open standard and CAN be shared across AI tools:**

✅ **Claude Code** (Anthropic)
✅ **Codex CLI** (OpenAI)
✅ **ChatGPT** (OpenAI - via API)
⚠️ **Gemini CLI** (Google - if they implement the standard)
⚠️ **ATG** (if they implement the standard)

## The Agent Skills Standard (December 2025)

**Created by:** Anthropic
**Released as:** Open specification at [agentskills.io](https://agentskills.io)
**Adopted by:** OpenAI (Codex CLI, ChatGPT), Microsoft, GitHub, Cursor, Goose, Amp, OpenCode

### Key Timeline
- **Dec 18, 2025** - Anthropic releases Agent Skills as open standard
- **Dec 2025** - OpenAI adopts the standard for Codex CLI and ChatGPT
- **Jan 2026** - Growing ecosystem adoption

## Format Compatibility

The Agent Skills format is **identical across platforms**. Compare these examples:

### OpenAI Codex Skill
```yaml
---
name: skill-creator
description: Guide for creating effective skills. Use when users want to create a new skill that extends Codex's capabilities.
metadata:
  short-description: Create or update a skill
---

# Skill Creator
[Instructions for Codex...]
```

### Anthropic Claude Skill
```yaml
---
name: skill-creator
description: Guide for creating effective skills. Use when users want to create a new skill that extends Claude's capabilities.
license: Complete terms in LICENSE.txt
---

# Skill Creator
[Instructions for Claude...]
```

**Only difference:** Agent name in description (Codex vs Claude)

## Sharing Anthropic Skills with Other Tools

### Option 1: Direct Copy (Recommended)

Anthropic skills work directly in Codex CLI:

```bash
# Copy Anthropic skill to Codex
cp -r /Users/icmini/02luka/tools/claude/skills/skills/pdf \
      /Users/icmini/02luka/tools/codex/skills/skills/.curated/

# Or symlink for automatic updates
ln -s /Users/icmini/02luka/tools/claude/skills/skills/pdf \
      /Users/icmini/02luka/tools/codex/skills/skills/.curated/pdf
```

### Option 2: Create Universal Skills Directory

Centralize skills for all AI tools:

```bash
# Create universal skills directory
mkdir -p ~/ai-skills

# Copy skills from Anthropic repo
cp -r /Users/icmini/02luka/tools/claude/skills/skills/* ~/ai-skills/

# Symlink to each AI tool
ln -s ~/ai-skills/* ~/.claude/skills/
ln -s ~/ai-skills/* /path/to/codex/skills/.curated/
ln -s ~/ai-skills/* /path/to/gemini/skills/
```

### Option 3: Version-Controlled Shared Skills

For team environments:

```bash
# Create shared skills repo
mkdir -p /Users/icmini/02luka/tools/shared-skills
cd /Users/icmini/02luka/tools/shared-skills
git init

# Copy base skills
cp -r /Users/icmini/02luka/tools/claude/skills/skills/* ./

# Customize for your team
# Edit descriptions to be tool-agnostic

# Link from all AI tools
ln -s /Users/icmini/02luka/tools/shared-skills ~/.claude/skills/shared
ln -s /Users/icmini/02luka/tools/shared-skills /path/to/codex/skills/.curated/shared
```

## Tool-Specific Installation Paths

### Claude Code
```
Personal: ~/.claude/skills/
Project:  .claude/skills/
Plugin:   /plugin install /path/to/skills
```

### OpenAI Codex CLI
```
System:   $CODEX_HOME/skills/.system/
Curated:  $CODEX_HOME/skills/.curated/
User:     $CODEX_HOME/skills/
Project:  .codex/skills/
```

### ChatGPT (API)
```
Upload via: https://docs.claude.com/en/api/skills-guide
API call:   POST /skills with skill content
```

### Gemini CLI (If Supported)
```
Check: gemini --help | grep skills
Likely: ~/.gemini/skills/ or .gemini/skills/
```

### ATG/Other Tools
```
Check documentation for skills support
Look for: --skills-dir flag or config files
```

## Making Skills Truly Cross-Platform

### 1. Use Generic Descriptions

**Bad (tool-specific):**
```yaml
description: Helps Claude create Word documents with formatting
```

**Good (tool-agnostic):**
```yaml
description: Create and edit Word documents (.docx) with formatting, tracked changes, and comments. Use when working with professional documents.
```

### 2. Replace Tool Names in Instructions

Use a preprocessor or maintain variants:

```markdown
# Before (Claude-specific)
Claude will use Python scripts to process PDFs.

# After (generic)
The AI agent will use Python scripts to process PDFs.
```

### 3. Avoid Tool-Specific Features

Some features may not work across all platforms:

| Feature | Claude | Codex | ChatGPT | Notes |
|:--------|:-------|:------|:--------|:------|
| `SKILL.md` format | ✅ | ✅ | ✅ | Universal |
| Scripts in `scripts/` | ✅ | ✅ | ✅ | Universal |
| `references/` folder | ✅ | ✅ | ⚠️ | Check docs |
| `allowed-tools` | ✅ | 🔬 | ❓ | Experimental |
| `context: fork` | ✅ | ❓ | ❓ | Claude-specific? |

## Testing Cross-Platform Skills

### Test Matrix

```bash
# 1. Test in Claude Code
cd /Users/icmini/02luka
claude # Start Claude Code
# Try: "Use the PDF skill to extract text from test.pdf"

# 2. Test in Codex CLI
codex # Start Codex
# Try: "Use the PDF skill to extract text from test.pdf"

# 3. Test in ChatGPT API
curl -X POST https://api.openai.com/v1/skills \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d @skill.json
```

### Validation Checklist

- [ ] Skill has valid YAML frontmatter
- [ ] Name matches directory (lowercase, hyphens)
- [ ] Description is tool-agnostic
- [ ] No tool-specific references in instructions
- [ ] Scripts use portable shebang (`#!/usr/bin/env python3`)
- [ ] Dependencies are documented in `compatibility` field
- [ ] Test in at least 2 different AI tools

## Current Status: Which Tools Support Agent Skills?

### ✅ Confirmed Support
- **Claude Code** - Full support, native implementation
- **Claude.ai** - Full support, all paid plans
- **Claude API** - Full support via Skills API
- **Codex CLI** - Full support (Dec 2025)
- **ChatGPT** - API support (Dec 2025)

### ⚠️ Unknown/Partial Support
- **Gemini CLI** - No public documentation found
- **ATG** - Unknown (depends on implementation)
- **Cursor AI** - Mentioned as adopter, check docs
- **GitHub Copilot** - Not confirmed

### 🔍 How to Check
```bash
# Claude Code
claude --help | grep -i skill

# Codex CLI
codex --help | grep -i skill

# Gemini CLI (if installed)
gemini --help | grep -i skill

# Or check for config directories
ls ~/.claude/skills
ls ~/.codex/skills
ls ~/.gemini/skills
```

## Practical Example: Sharing PDF Skill

### Step-by-Step

```bash
# 1. Source: Anthropic skills repo
SOURCE="/Users/icmini/02luka/tools/claude/skills/skills/pdf"

# 2. Make generic (optional - create modified version)
cp -r "$SOURCE" /tmp/pdf-skill-generic
# Edit /tmp/pdf-skill-generic/SKILL.md
# Replace "Claude" with "the agent" or "the AI"

# 3. Install to Claude Code
ln -s "$SOURCE" ~/.claude/skills/pdf

# 4. Install to Codex CLI
ln -s "$SOURCE" /path/to/codex/skills/.curated/pdf

# 5. Install to project (version controlled)
mkdir -p /Users/icmini/02luka/.claude/skills
cp -r "$SOURCE" /Users/icmini/02luka/.claude/skills/pdf

# 6. Test in both tools
echo "Test with: 'Extract text from sample.pdf using the PDF skill'"
```

## Best Practices

### 1. Maintain a Central Skills Library

```
~/ai-skills/
├── document-processing/
│   ├── pdf/
│   ├── docx/
│   ├── xlsx/
│   └── pptx/
├── development/
│   ├── mcp-builder/
│   └── webapp-testing/
├── design/
│   ├── frontend-design/
│   └── canvas-design/
└── custom/
    ├── 02luka-core/
    └── company-brand/
```

### 2. Use Symlinks for Sync

```bash
# Link central library to all tools
for tool in claude codex gemini; do
  ln -sf ~/ai-skills/* ~/.$tool/skills/
done
```

### 3. Version Control Custom Skills

```bash
cd ~/ai-skills
git init
git add .
git commit -m "Initial skills library"
git remote add origin git@github.com:yourusername/ai-skills.git
git push -u origin main
```

### 4. Document Tool Compatibility

Add to each skill's README:

```markdown
## Compatibility

✅ Tested with:
- Claude Code v1.x
- Codex CLI v2.x

⚠️ Not tested:
- Gemini CLI
- ChatGPT API

## Installation

See [CROSS_PLATFORM_SKILLS_GUIDE.md](../../CROSS_PLATFORM_SKILLS_GUIDE.md)
```

## Limitations & Gotchas

### 1. Tool-Specific Features
Some advanced features may not be portable:
- Claude's `context: fork` for sub-conversations
- Codex's `$skill-installer` helper
- API-specific skill upload mechanisms

### 2. Scripts and Dependencies
Skills with scripts require:
- Same runtime (Python 3, Node.js, etc.)
- Same available system tools
- Same file system structure

### 3. Tool Names in Instructions
Many Anthropic skills say "Claude will..." - edit these for true portability.

### 4. Testing Required
**Always test skills in the target tool** - the standard is new and implementations vary.

## Resources

- **Agent Skills Standard:** https://agentskills.io
- **Specification:** https://agentskills.io/specification
- **Anthropic Skills Repo:** https://github.com/anthropics/skills
- **OpenAI Skills Repo:** https://github.com/openai/skills
- **Claude Skills Docs:** https://support.claude.com/en/articles/12512176-what-are-skills
- **Codex Skills Docs:** https://developers.openai.com/codex/skills

## Summary

**Yes, you CAN share these skills across AI tools!**

| Aspect | Status |
|:-------|:-------|
| Format compatibility | ✅ Identical standard |
| Claude → Codex | ✅ Works with minor edits |
| Claude → ChatGPT | ✅ Via API |
| Claude → Gemini | ⚠️ Unknown (check docs) |
| Claude → ATG | ⚠️ Unknown (check docs) |
| Central library | ✅ Recommended approach |
| Version control | ✅ Fully supported |

**Next Steps:**
1. Create `~/ai-skills/` central library
2. Copy/symlink Anthropic skills
3. Test with multiple AI tools
4. Customize descriptions for portability
5. Document compatibility in each skill

---

**Location:** `/Users/icmini/02luka/tools/CROSS_PLATFORM_SKILLS_GUIDE.md`
**Updated:** 2026-01-09
**Agent Skills Standard:** v1.0 (December 2025)
