# Spec: /warroom CLI Command

**Goal:** Implement the "Consultant Mode" pipeline in 02luka without building a web app.  
**Philosophy:** Clear Box, Artifact-Based, Human-in-Loop.

---

## 1. Command Interface

```bash
zsh tools/warroom.zsh "<topic>"
# or via slash command alias
/warroom "<topic>"
```

---

## 2. Pipeline Flow (The "Brain" Logic)

### Step 1: Intake & Clarify
- **Input:** User topic string.
- **Action:** 
  - Analyze topic for ambiguity.
  - Generate 2-3 clarifying questions (max).
  - *Pause* and wait for user input.
- **Artifact:** `g/decision/drafts/<timestamp>_intake.json`

### Step 2: Research (The "Analyst")
- **Input:** User answers.
- **Action:**
  - **Scan Repo:** `grep` / `ls` relevant paths.
  - **Scan Decisions:** Check `g/decision/` for past context.
  - **(Optional) Web Search:** If enabled/allowed.
- **Artifact:** `g/decision/drafts/<timestamp>_research.md`

### Step 3: Synthesis (The "Writer")
- **Input:** Research findings + Intake.
- **Action:** 
  - Fill out the `g/decision/DECISION_BOX.md` template.
  - Apply "Reasoning Mirror" checks (simulate LAC).
- **Output:** A new file: `g/decision/<date>_<topic_slug>.md`

### Step 4: STOP
- **Action:** Print path to the new Decision Box.
- **Status:** Exit 0.
- **Note:** **NO EXECUTION.** The user must read the file and decide.

---

## 3. Implementation Details

- **Language:** Python (`tools/warroom_core.py`) wrapped in ZSH.
- **Dependencies:** Standard 02luka toolchain (`gemini` CLI for generation).
- **Template:** Uses `g/decision/DECISION_BOX.md` as the gold standard.

---

## 4. Usage Rules

- **Strictly Strategic:** Do not use for "fix typo" or "restart server".
- **Execution Barrier:** The tool *cannot* run code changes. It *only* produces Markdown.

---

## Smoke Test

```bash
zsh tools/warroom.zsh "test decision"
ls g/decision/drafts/*warroom_stub.md
```

