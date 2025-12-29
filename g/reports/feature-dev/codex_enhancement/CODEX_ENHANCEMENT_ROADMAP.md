# Codex CLI Enhancement Roadmap
**Goal:** Replace CLC (Claude Code) with Enhanced Codex CLI for 60-80% quota savings
**Current:** Codex CLI 0.77.0 installed at `/opt/homebrew/bin/codex`
**Target:** Codex = near-parity with CLC capabilities

---

## Enhancement Strategy

### Phase 1: Official Skills (Install Now)
**Repo:** `openai/skills`
**Why:** Official OpenAI skills with built-in Codex support

**Install:**
```bash
# Clone official skills repo
cd ~/02luka/tools/codex
git clone https://github.com/openai/skills.git

# Install core skills
cd skills
./skill-installer code-review      # Code review skill
./skill-installer refactor          # Refactoring skill
./skill-installer test-generation   # Test generation skill
./skill-installer debug-assistant   # Debugging skill
```

**Skills structure:**
- `skills/.system` - Pre-installed skills
- `skills/.curated` - Curated skills (install on demand)
- `skills/.experimental` - Experimental (specify path)

**Value:** Immediate 40% capability boost (review, refactor, test, debug)

---

### Phase 2: Claude Code to Codex Bridge (Integration layer)
**Repo:** `skills-directory/skill-codex`
**Why:** Allows Claude Code to delegate to Codex CLI programmatically

**Install:**
```bash
# Clone skill-codex
cd ~/.claude/skills
git clone https://github.com/skills-directory/skill-codex.git codex

# Edit ~/.claude/skills/codex/SKILL.md to configure:
# - Model selection (GPT-5.2-Codex)
# - Reasoning effort (low/medium/high)
# - Sandbox settings
```

**Usage (from Claude Code):**
```
/skills codex "refactor this module for better performance"
```

**Value:** Enables CLC to Codex delegation (saves CLC tokens)

---

### Phase 3: Workflow Automation (Complete ecosystem)
**Repo:** `fcakyon/claude-codex-settings`
**Why:** Full workflow system (hooks, MCP servers, plugins)

**Install:**
```bash
# Clone settings repo
cd ~/02luka/tools/codex
git clone https://github.com/fcakyon/claude-codex-settings.git

# Install via Claude Code plugin system
# (from Claude Code CLI)
/plugin marketplace add https://github.com/fcakyon/claude-codex-settings
/plugin install claude-codex-settings
```

**Components:**
- `.claude-plugin/marketplace.json` - Plugin registry
- `.claude/settings.json` - Claude Code settings
- `.codex/config.toml` - Codex config
- `plugins/` - MCP servers (github-dev, playwright-tools, etc.)

**Value:** Full workflow automation (hooks, MCP, plugins)

---

### Phase 4: Research/Reasoning Skills (Advanced)
**Repo:** `zechenzhangAGI/AI-research-SKILLs`
**Why:** Advanced reasoning workflows for complex tasks

**Install (selective):**
```bash
# Clone research skills
cd ~/02luka/tools/codex/skills
git clone https://github.com/zechenzhangAGI/AI-research-SKILLs.git research

# Install specific categories:
./skill-installer research/03-fine-tuning         # Fine-tuning workflows
./skill-installer research/11-evaluation          # Evaluation methods
./skill-installer research/15-rag                 # RAG patterns
./skill-installer research/16-prompt-engineering  # Prompt engineering
```

**Categories:**
- `01-model-architecture` - Model design patterns
- `03-fine-tuning` - Fine-tuning workflows
- `11-evaluation` - Evaluation methods
- `15-rag` - RAG patterns
- `16-prompt-engineering` - Prompt engineering

**Value:** Advanced reasoning for complex 02luka tasks

---

## Enhancement Stack Summary

| Phase | Repo | Purpose | Impact |
|-------|------|---------|--------|
| 1 **Core** | `openai/skills` | Official skills (review/refactor/test/debug) | 40% boost |
| 2 **Bridge** | `skills-directory/skill-codex` | CLC to Codex delegation | Token savings |
| 3 **Workflow** | `fcakyon/claude-codex-settings` | Hooks, MCP, plugins | Full automation |
| 4 **Advanced** | `zechenzhangAGI/AI-research-SKILLs` | Reasoning workflows | Complex tasks |

---

## Expected Outcomes

**After Phase 1+2:**
- Codex handles: code review, refactoring, test generation, debugging
- CLC delegates heavy tasks to Codex
- **Estimated savings: 40-50% CLC quota**

**After Phase 3:**
- Full workflow automation (MCP servers, hooks)
- Codex works autonomously like CLC
- **Estimated savings: 60-70% CLC quota**

**After Phase 4:**
- Codex handles complex reasoning tasks
- CLC only for locked zones + governance
- **Estimated savings: 70-80% CLC quota**

---

## Complementary Tools

**To enhance Codex further, install:**

### 1. Aider (Repo Context)
```bash
pipx install aider-chat
```
**Usage:** Generate repo map for Codex
```bash
aider --just-map > /tmp/repo_map.txt
codex --context /tmp/repo_map.txt "refactor auth module"
```

### 2. ast-grep (Structural Search)
```bash
brew install ast-grep
```
**Usage:** Find structural patterns
```bash
ast-grep --pattern 'function $NAME($$$)' src/
```

### 3. pre-commit (Approval Gate)
```bash
brew install pre-commit
```
**Usage:** Review gate before Codex writes
```bash
pre-commit install
```

### 4. reviewdog (Lint Feedback)
```bash
brew install reviewdog
```
**Usage:** Auto-fix lint errors
```bash
reviewdog -reporter=github-pr-review
```

---
