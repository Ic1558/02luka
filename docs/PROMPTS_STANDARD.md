# Prompts Standard

## AI Interaction Guidelines

### 1. System Prompts

**CLS Learning Prompts**:
- Clear, actionable descriptions
- Include context and metadata
- Use structured JSON format

**Example**:
```json
{
  "type": "command",
  "context": "git workflow",
  "metadata": {
    "command": "git commit -m \"message\"",
    "exit_code": 0,
    "timestamp": "2025-10-31T06:00:00Z"
  }
}
```

### 2. Documentation Prompts

**Style**:
- Concise and technical
- Include code examples
- Use markdown formatting

**Structure**:
```markdown
# Title

## Overview
[Brief description]

## Usage
[Code examples]

## Details
[Technical explanation]
```

### 3. Error Handling

**Format**:
```
❌ Error: [description]
📍 Location: [file:line]
🔧 Fix: [solution]
```

### 4. Commit Messages

**Format**:
```
type(scope): description

- Detail 1
- Detail 2

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```

**Types**: feat, fix, docs, chore, ci, refactor

## Best Practices

1. **Be Specific**: Include exact commands and paths
2. **Be Concise**: Focus on essential information
3. **Be Consistent**: Follow established patterns
4. **Be Helpful**: Include context and examples
