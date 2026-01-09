---
title: Anthropic Claude Skills Installation
date: 2026-01-09
agent: CLC
status: completed
---

# Anthropic Claude Skills Installation

## Overview

Successfully installed the official Anthropic Claude Skills repository to enable advanced document processing, design, development, and enterprise communication capabilities.

## Installation Details

**Repository:** https://github.com/anthropics/skills
**Location:** `/Users/icmini/02luka/tools/claude/skills/`
**Installation Date:** 2026-01-09
**Total Skills:** 16 skills

## Installed Skills

### Document Processing (4 skills)
- **docx** - Comprehensive Word document creation, editing, tracked changes
- **pdf** - PDF manipulation, text/table extraction, forms, merging/splitting
- **pptx** - PowerPoint presentation creation, editing, layouts
- **xlsx** - Excel spreadsheet creation, formulas, data analysis, visualization

### Creative & Design (5 skills)
- **algorithmic-art** - p5.js generative art with seeded randomness
- **canvas-design** - Beautiful PNG/PDF visual art and poster design
- **frontend-design** - Production-grade frontend interfaces and web components
- **slack-gif-creator** - Animated GIFs optimized for Slack
- **theme-factory** - Styling artifacts with 10 pre-set themes

### Development & Technical (3 skills)
- **mcp-builder** - Create high-quality MCP servers for external service integration
- **webapp-testing** - Playwright-based local web app testing toolkit
- **web-artifacts-builder** - Complex React/Tailwind/shadcn artifacts

### Enterprise & Communication (4 skills)
- **brand-guidelines** - Anthropic's official brand colors and typography
- **doc-coauthoring** - Structured documentation workflow for technical specs
- **internal-comms** - Templates for status reports, updates, FAQs
- **skill-creator** - Tools for creating new custom skills

## Usage in Claude Code

### Method 1: Plugin Marketplace (Recommended)
```bash
# Register the marketplace
/plugin marketplace add anthropics/skills

# Install document skills
/plugin install document-skills@anthropic-agent-skills

# Install example skills
/plugin install example-skills@anthropic-agent-skills
```

### Method 2: Direct Usage
Simply mention the skill in conversation:
```
"Use the PDF skill to extract form fields from path/to/file.pdf"
"Use the docx skill to create a professional report"
"Use the frontend-design skill to build a landing page"
```

## Repository Structure

```
tools/claude/skills/
├── README.md              # Main documentation
├── THIRD_PARTY_NOTICES.md # License information
├── skills/                # All 16 skills
│   ├── algorithmic-art/
│   ├── brand-guidelines/
│   ├── canvas-design/
│   ├── doc-coauthoring/
│   ├── docx/
│   ├── frontend-design/
│   ├── internal-comms/
│   ├── mcp-builder/
│   ├── pdf/
│   ├── pptx/
│   ├── skill-creator/
│   ├── slack-gif-creator/
│   ├── theme-factory/
│   ├── web-artifacts-builder/
│   ├── webapp-testing/
│   └── xlsx/
├── spec/                  # Agent Skills specification
└── template/              # Skill creation template
```

## Key Features

1. **Document Skills** - Professional document creation (Word, Excel, PowerPoint, PDF)
2. **Design Skills** - Visual and web design with modern aesthetics
3. **Developer Tools** - MCP server building, web app testing
4. **Enterprise Tools** - Brand guidelines, internal communications
5. **Custom Skills** - Template and creator for building new skills

## Notes

- Many skills are Apache 2.0 open source
- Document skills (docx/pdf/pptx/xlsx) are source-available (not open source)
- These skills demonstrate production-quality implementations used in Claude
- Each skill has a SKILL.md file with instructions and metadata

## References

- [Agent Skills Standard](http://agentskills.io)
- [What are skills?](https://support.claude.com/en/articles/12512176-what-are-skills)
- [Using skills in Claude](https://support.claude.com/en/articles/12512180-using-skills-in-claude)
- [Creating custom skills](https://support.claude.com/en/articles/12512198-creating-custom-skills)
- [Equipping agents for the real world with Agent Skills](https://anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills)

## Next Steps

1. Register as plugin marketplace: `/plugin marketplace add anthropics/skills`
2. Browse and install specific skill sets as needed
3. Explore individual skills in `tools/claude/skills/skills/`
4. Create custom skills using the template in `template/`

---
**Status:** ✅ Installation Complete
**Verified:** All 16 skills present with SKILL.md files
**Ready:** Skills available for use in Claude Code
