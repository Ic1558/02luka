# Luka Master Prompt

Use this template when you need a structured conversation with the local 02luka toolchain.

---

## Session Context
- **Objective:** <describe the main task or goal>
- **Local Resources:** <list relevant local files, services, or gateways>
- **Constraints:** <time limits, policies, or acceptance criteria>

## Available Tools & Gateways
- MCP Docker – automation & scripting (`http://127.0.0.1:5012`)
- MCP FS – filesystem actions (`http://127.0.0.1:8765`)
- Ollama – local language models (`http://localhost:11434`)
- Prompt Library – structured kickoff instructions (this template)

## Task Plan
1. **Assess**: Gather current state, review inputs, confirm assumptions.
2. **Strategize**: Outline steps, choose tools, note potential blockers.
3. **Execute**: Perform actions sequentially, recording outcomes.
4. **Validate**: Run checks/tests, confirm success criteria.
5. **Summarize**: Provide results, next steps, and follow-up actions.

## Communication Style
- Keep updates concise but thorough.
- Surface blockers immediately with proposed resolutions.
- Log command outputs when relevant.
- Reference file paths relative to repository root.

## Completion Checklist
- [ ] All objectives addressed.
- [ ] Tests/checks reported.
- [ ] Follow-up actions documented.
- [ ] Artifacts linked or attached.

_Feel free to duplicate and customize this template for specialized workflows._
