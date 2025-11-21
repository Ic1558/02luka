# GMX Agent Registration Instructions

## Files Created
✅ `agents/gmx/README.md` - Overview of GMX role  
✅ `agents/gmx/PERSONA_PROMPT.md` - System instructions for Antigravity

## Next Steps (Manual - Boss Action Required)

Since Antigravity stores agent configurations in its internal IDE state (not in workspace files), you need to manually register GMX in the UI.

### Step-by-Step Registration

1.  **Open Antigravity Agent Manager**
    - Look for the "Agents" or "Agent Manager" button in your IDE (usually in the sidebar or top toolbar)
    - OR: Use keyboard shortcut if available

2.  **Add New Agent**
    - Click "Add Agent", "New Agent", or "+" button
    - You should see a form or dialog

3.  **Configure GMX**
    Fill in the following:
    - **Name**: `GMX - Work Order Planner`
    - **Persona/System Prompt File**: Browse to:
      ```
      /Users/icmini/02luka/agents/gmx/PERSONA_PROMPT.md
      ```
    - **Model**: Select `Gemini 1.5 Pro` or `Gemini 2.0 Flash` (same as you use for coding)
    - **Execution Policy**: Set to **"Ask"** or **"Off"** (GMX should NOT auto-run commands)
    - **Terminal Access**: **Disabled** (GMX only plans, never executes)

4.  **Save**
    - Click "Save", "Create", or "OK"
    - GMX should now appear in your agent list

5.  **Verify**
    - Switch to GMX agent in the UI
    - Try a test prompt: "Create a spec to add logging to test.py"
    - GMX should respond with JSON (no code, no execution)

## Usage After Registration

### Typical Workflow
1.  **Boss → GMX**: "Add AP/IO logging to MLS tools"
2.  **GMX → Boss**: Returns JSON `task_spec`
3.  **Boss → Liam**: "Execute this spec" (or save to `g/wo_specs/` and run via executor)

### Example GMX Invocation
In Antigravity, switch to GMX and say:
> "Create a plan to refactor mary_router.py to use Pydantic models"

GMX will respond with:
```json
{
  "gmx_plan": { ... },
  "task_spec": { ... }
}
```

You can then:
- Save this JSON to `g/wo_specs/refactor_mary.json`
- Run: `python agents/liam/executor.py g/wo_specs/refactor_mary.json`

## Troubleshooting

**Issue**: GMX tries to write code  
**Fix**: Remind GMX: "You are a planner, not an executor. Output JSON only."

**Issue**: GMX can't be found in agent list  
**Fix**: Re-check the persona file path is correct: `/Users/icmini/02luka/agents/gmx/PERSONA_PROMPT.md`

**Issue**: GMX runs shell commands  
**Fix**: Ensure execution policy is set to "Ask" or "Off" in agent settings
