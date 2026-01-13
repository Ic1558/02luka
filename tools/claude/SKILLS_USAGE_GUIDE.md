# Anthropic Skills - Seamless Usage Guide

## Quick Start (3 Steps)

### Step 1: Install as Local Plugin

From the project root (`/Users/icmini/02luka`), run:

```bash
/plugin install /Users/icmini/02luka/tools/claude --local
```

### Step 2: Restart Claude Code

Restart Claude Code to load the skills into memory.

### Step 3: Start Using!

Just talk naturally - skills activate automatically:

```
"Extract text from this PDF file"  → pdf skill activates
"Create a Word document with..."   → docx skill activates
"Build a landing page with..."     → frontend-design skill activates
"Analyze this Excel spreadsheet"   → xlsx skill activates
```

## How It Works

**Automatic Discovery:**
- Claude Code loads all 16 skill descriptions at startup
- When you make a request, Claude matches it against skill descriptions
- If a match is found, Claude automatically proposes using that skill
- You approve once, then the full skill loads and executes

**No Manual Invocation Needed:**
- ✅ Just describe what you want
- ❌ No need to say "use the PDF skill"
- ❌ No need for `/skill` commands

## Available Skills (16 Total)

### Document Processing
- **xlsx** - Excel: formulas, data analysis, charts
- **docx** - Word: tracked changes, comments, formatting
- **pptx** - PowerPoint: slides, layouts, speaker notes
- **pdf** - PDF: extract, merge, split, forms

### Creative & Design
- **algorithmic-art** - p5.js generative art
- **canvas-design** - PNG/PDF poster and visual design
- **frontend-design** - Production web interfaces
- **slack-gif-creator** - Animated GIFs for Slack
- **theme-factory** - Styling artifacts with themes

### Development & Technical
- **mcp-builder** - Create MCP servers for external APIs
- **webapp-testing** - Playwright-based testing
- **web-artifacts-builder** - Complex React/Tailwind artifacts

### Enterprise & Communication
- **brand-guidelines** - Anthropic brand colors/typography
- **doc-coauthoring** - Structured documentation workflow
- **internal-comms** - Status reports, updates, FAQs
- **skill-creator** - Build custom skills

## Example Usage

### Document Creation
```
You: "Create a professional report in Word about Q4 sales"
Claude: [Automatically uses docx skill]
```

### PDF Processing
```
You: "Extract all form fields from contract.pdf"
Claude: [Automatically uses pdf skill]
```

### Web Design
```
You: "Build a modern landing page for a SaaS product"
Claude: [Automatically uses frontend-design skill]
```

### Data Analysis
```
You: "Analyze sales data in data.xlsx and create pivot tables"
Claude: [Automatically uses xlsx skill]
```

### MCP Development
```
You: "Help me build an MCP server for the GitHub API"
Claude: [Automatically uses mcp-builder skill]
```

## Alternative: Direct Folder Access

If you prefer skills to be always available without plugin installation:

### Option A: Personal Scope (Your User Only)
```bash
ln -s /Users/icmini/02luka/tools/claude/skills/skills ~/.claude/skills/anthropic
```

### Option B: Project Scope (Team Access via Git)
```bash
mkdir -p /Users/icmini/02luka/.claude/skills
cp -r /Users/icmini/02luka/tools/claude/skills/skills/* /Users/icmini/02luka/.claude/skills/
```

## Skill Scope Hierarchy

Skills are loaded in priority order:

1. **Enterprise** (Admin-managed) - Highest priority
2. **Personal** (`~/.claude/skills/`) - Your user only
3. **Project** (`.claude/skills/`) - Team collaboration
4. **Plugin** (Installed plugins) - Lowest priority

## Checking Available Skills

To see what skills are loaded:

```
What skills are available?
```

Claude will list all active skills with descriptions.

## Manual Skill Invocation (Optional)

If you want to explicitly use a specific skill:

```
/skill pdf
```

But this is rarely needed - automatic discovery works great!

## Troubleshooting

**Skills not appearing?**
1. Verify plugin installed: `/plugin list`
2. Restart Claude Code
3. Check plugin.json exists: `ls /Users/icmini/02luka/tools/claude/.claude-plugin/`

**Skill not activating?**
- The skill description might not match your request
- Try being more explicit: "I need to work with a PDF file..."
- Or manually invoke: `/skill pdf`

**Want to disable a skill?**
- Edit plugin.json and remove from "skills" array
- Restart Claude Code

## Configuration Files

**Plugin Manifest:**
`/Users/icmini/02luka/tools/claude/.claude-plugin/plugin.json`

**Skills Location:**
`/Users/icmini/02luka/tools/claude/skills/skills/`

**Each Skill:**
`/Users/icmini/02luka/tools/claude/skills/skills/[skill-name]/SKILL.md`

## Best Practices

1. **Let skills auto-activate** - Trust the automatic discovery
2. **Be descriptive** - "Create a PowerPoint presentation..." triggers pptx
3. **Approve once** - After first approval, skills work seamlessly
4. **Check skill docs** - Each SKILL.md has examples and guidelines
5. **Create custom skills** - Use skill-creator to build your own

## Next Steps

1. ✅ Install plugin: `/plugin install /Users/icmini/02luka/tools/claude --local`
2. ✅ Restart Claude Code
3. ✅ Test: "Create a Word document with a table of contents"
4. 🎉 Enjoy seamless skill usage!

---

**Location:** `/Users/icmini/02luka/tools/claude/skills/`
**Plugin Name:** `02luka-anthropic-skills`
**Version:** 1.0.0
**Skills:** 16 total
