# Boss Workspace - Email Paradigm Interface

## 📧 Workflow Overview

```
dropbox/       → System pickup (You drop work here)
inbox/         ← System queries (System asks questions)
sent/          → Your responses (You answer/command)
deliverables/  ← Final outputs (System delivers results)
```

## 📁 Folder Structure

### Active Folders
- **dropbox/** - Drop any file here for system processing
  - `.processing/` - Files being processed (system managed)
- **inbox/** - System notifications and queries requiring your attention
  - `.read/` - Marked as read but kept for reference
- **sent/** - Your responses to queries and commands
  - `.consumed/` - Processed responses (system managed)
- **deliverables/** - Completed work from the system
  - `.archived/` - Auto-archived after 30 days

### Personal Folders
- **drafts/** - Your work-in-progress files
- **documents/** - Your reference documents
- **templates/** - Template files for common workflows
- **.config/** - Personal configuration and routing rules

## 🔄 Example Workflows

### Simple Request
1. Drop `request.md` in `dropbox/`
2. System processes → Result appears in `deliverables/`

### Query Loop
1. Drop unclear file in `dropbox/`
2. System creates query → `inbox/query_123.md`
3. You edit and move to `sent/query_123.md`
4. System resumes → Result in `deliverables/`

### Priority Processing
- Add "urgent" in filename → High priority routing
- Add "draft" in filename → Low priority, batch processing

## 📝 Query Response Format

When responding to queries in `inbox/`:
```markdown
Decision: [Your choice from provided options]
Notes: [Additional context or instructions]
Priority: [high/normal/low]
```

## 🎯 Best Practices

1. **Check inbox regularly** - System may have questions
2. **Use descriptive filenames** - Helps routing decisions
3. **Keep sent/ clean** - Archive old responses periodically
4. **Review deliverables/** - Move important results to your storage

## 🚀 Quick Commands

```bash
# Check pending queries
ls boss/inbox/

# See recent deliverables
ls -t boss/deliverables/ | head -10

# Drop a file for processing
cp myfile.md boss/dropbox/

# Check processing status
ls boss/dropbox/.processing/
```

---
*Boss Workspace v1.0 - Part of 02luka System*