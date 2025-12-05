# CLC Patch Spec v1

**Date:** 2025-12-06  
**Type:** Specification  
**Status:** 📋 **DRAFT**  
**Target:** CLC Auto-Patcher Worker

---

## 🎯 **OBJECTIVE**

Define a deterministic, machine-readable specification format for CLC auto-patcher worker to apply code changes without requiring LLM interpretation of free-form text.

**Rationale:** While CLC (Claude Code) can read English, the auto-patcher worker needs structured, deterministic instructions to apply patches reliably.

---

## 📋 **SPEC FORMAT**

### **Structure:**

```yaml
clc_patch:
  version: "1.0"
  wo_id: "WO-20251206-LAC-PROCESSING-DEBUG"
  patches:
    - id: "P1"
      file: "agents/lac_manager/lac_manager.py"
      patch_type: "insert_after"
      anchor: "except Exception as e:"
      anchor_context: |
        except Exception as e:
            logging.error(f"Error processing {task_file.name}: {e}")
      payload: |
        # Move to processed even on error
        proc_path.rename(processed / task_file.name)
        logging.warning(f"Moved {task_file.name} to processed/ after error")
      validation:
        - type: "grep"
          pattern: "proc_path.rename.*processed"
          expected: "found"
        - type: "syntax_check"
          command: "python3 -m py_compile {file}"
```

---

## 🔧 **PATCH TYPES**

### **1. insert_after**
Insert code after a specific anchor line.

**Fields:**
- `file`: Target file path
- `anchor`: Line pattern to search for (regex or exact match)
- `anchor_context`: Multi-line context for better matching (optional)
- `payload`: Code to insert
- `indent`: Indentation level (auto-detect if not specified)

**Example:**
```yaml
patch_type: "insert_after"
anchor: "except Exception as e:"
payload: |
    # Error handling
    proc_path.rename(processed / task_file.name)
```

---

### **2. insert_before**
Insert code before a specific anchor line.

**Fields:** Same as `insert_after`

---

### **3. replace**
Replace a code block.

**Fields:**
- `file`: Target file path
- `old`: Code block to replace (exact match or regex)
- `new`: Replacement code
- `multiline`: true if old/new span multiple lines

**Example:**
```yaml
patch_type: "replace"
old: |
    def process_task(self, task: Dict[str, Any]):
        intent = task.get("intent", "")
        lane = self.route_request(intent)
new: |
    def process_task(self, task: Dict[str, Any]):
        intent = task.get("intent", "")
        lane = self.route_request(intent)
        # Add error handling wrapper
        try:
            self._process_task_internal(task, lane)
        except Exception as e:
            logging.error(f"Task processing failed: {e}")
            raise
```

---

### **4. append**
Append code to end of file or function.

**Fields:**
- `file`: Target file path
- `target`: "file" or function name
- `payload`: Code to append

---

### **5. delete**
Delete a code block.

**Fields:**
- `file`: Target file path
- `anchor`: Pattern to identify block
- `lines`: Number of lines to delete (or until next pattern)

---

## ✅ **VALIDATION**

Each patch can include validation steps:

```yaml
validation:
  - type: "grep"
    pattern: "proc_path.rename.*processed"
    expected: "found"  # or "not_found"
  - type: "syntax_check"
    command: "python3 -m py_compile {file}"
  - type: "import_check"
    module: "agents.lac_manager.lac_manager"
  - type: "test"
    command: "./tools/test_lac_qa_suite.zsh"
    expected_exit: 0
```

---

## 🔄 **WORKFLOW**

### **Step 1: Parse Spec**
Worker reads `clc_patch` section from WO YAML.

### **Step 2: Apply Patches (Deterministic)**
For each patch:
1. Locate anchor in file
2. Apply patch according to `patch_type`
3. Run validation steps
4. If validation fails → rollback and log error

### **Step 3: LLM Assistance (Optional)**
If patch requires complex logic:
- Use LLM to generate `payload` based on `description`
- But apply patch deterministically using anchor/pattern

### **Step 4: Verify**
Run acceptance criteria tests.

---

## 📊 **DETERMINISTIC vs LLM**

### **Deterministic (Worker handles):**
- ✅ Finding anchor lines
- ✅ Applying patch types (insert/replace/append)
- ✅ Running validation
- ✅ Syntax checking
- ✅ File I/O

### **LLM-Assisted (Optional):**
- 🤖 Generating `payload` from `description` (if payload not provided)
- 🤖 Suggesting better anchor patterns
- 🤖 Code review/optimization

**Key:** Worker should work even if LLM is unavailable (fallback to provided payload).

---

## 📝 **EXAMPLE: LAC Processing Fix**

See: `bridge/inbox/CLC/WO-20251206-LAC-PROCESSING-DEBUG.yaml` (with `clc_patch` section)

---

## 🔗 **RELATED**

- WO Format: `.cursor/commands/do.md`
- CLC Worker: (to be implemented or located)
- Patch Templates: (to be created)

---

**Status:** 📋 **DRAFT** - Ready for implementation
