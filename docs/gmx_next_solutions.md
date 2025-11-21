# GMX Next Solutions - Addressing launchd + Gemini CLI Issue

## Problem Summary

**Current State:**
- ✅ GMX Auto Flow code is production-ready
- ✅ Error handling works correctly
- ⚠️ Gemini CLI fails in launchd environment (works fine in Terminal)

**Root Cause:** The `gemini` CLI tool has environment dependencies that aren't available in launchd's minimal environment, even with `~/.zshrc` sourced.

---

## Solution Options (Ranked by Feasibility)

### 🥇 Solution 1: Direct Python API Integration (Recommended)

**Approach:** Replace `gemini` CLI subprocess call with direct Python API using `google-generativeai` library.

**Pros:**
- ✅ Eliminates external CLI dependency
- ✅ Full control over environment and error handling
- ✅ Works reliably in launchd
- ✅ Better error messages and debugging
- ✅ No shell environment issues

**Cons:**
- ⚠️ Requires adding `google-generativeai` dependency
- ⚠️ Need to refactor `run_gmx_mode()` function

**Implementation:**
```python
# g/tools/gmx_cli.py - Refactored to use existing connector
from g.connectors.gemini_connector import GeminiConnector

def run_gmx_mode(user_input: str) -> Dict[str, Any]:
    """Direct API call using existing gemini_connector."""
    system_prompt = load_gmx_system_prompt()
    if not system_prompt:
        return {"status": "ERROR", "reason": "Failed to load GMX system prompt."}
    
    full_prompt = f"{system_prompt}\n\nUSER REQUEST: {user_input}"
    
    try:
        # Use existing connector (already handles API key, model, errors)
        connector = GeminiConnector(model_name=GMX_MODEL)
        
        if not connector.is_available():
            return {"status": "ERROR", "reason": "Gemini connector not available. Check GEMINI_API_KEY."}
        
        # Request JSON response format
        response = connector.generate_text(
            full_prompt,
            temperature=0.3,  # Lower temperature for structured output
            response_mime_type="application/json"  # Request JSON
        )
        
        if not response or "text" not in response:
            return {"status": "ERROR", "reason": "No response from Gemini API"}
        
        # Parse JSON directly (no two-step parsing needed!)
        return json.loads(response["text"])
        
    except json.JSONDecodeError as e:
        return {"status": "ERROR", "reason": f"Invalid JSON from Gemini: {e!r}"}
    except Exception as e:
        return {"status": "ERROR", "reason": f"Gemini API error: {e!r}"}
```

**Key Discovery:** The codebase already has `g/connectors/gemini_connector.py` that:
- ✅ Uses `google-generativeai` library
- ✅ Handles API key from environment
- ✅ Manages model initialization
- ✅ Has error handling and retry logic
- ✅ Returns structured response dict

**Benefits of reusing existing connector:**
- ✅ No new dependencies needed
- ✅ Consistent with rest of codebase
- ✅ Already tested and working
- ✅ Less code to maintain

**Effort:** Medium (2-3 hours)
**Risk:** Low
**Impact:** High - Solves the problem completely

---

### 🥈 Solution 2: Environment Wrapper Script

**Approach:** Create a wrapper script that sets up the full environment before calling `gemini` CLI.

**Pros:**
- ✅ Minimal code changes
- ✅ Keeps existing CLI-based approach
- ✅ Can debug environment issues

**Cons:**
- ⚠️ Still depends on external CLI tool
- ⚠️ May not solve all environment issues
- ⚠️ Adds another layer of complexity

**Implementation:**
```bash
# g/tools/gemini_wrapper.sh
#!/usr/bin/env zsh
set -euo pipefail

# Source full environment
source ~/.zshrc

# Ensure PATH includes gemini CLI location
export PATH="/opt/homebrew/bin:$PATH"

# Execute gemini CLI with all arguments
exec /opt/homebrew/bin/gemini "$@"
```

Then update `gmx_cli.py`:
```python
result = subprocess.run(
    ["/Users/icmini/02luka/g/tools/gemini_wrapper.sh", full_prompt, "--model", GMX_MODEL, "--output-format", "json"],
    ...
)
```

**Effort:** Low (30 minutes)
**Risk:** Medium (may not fully solve the issue)
**Impact:** Medium - Partial solution

---

### 🥉 Solution 3: Enhanced launchd Environment Configuration

**Approach:** Configure launchd plist with explicit environment variables and PATH.

**Pros:**
- ✅ No code changes needed
- ✅ Keeps existing architecture

**Cons:**
- ⚠️ May not solve the root cause
- ⚠️ Hard to debug what's missing
- ⚠️ Platform-specific configuration

**Implementation:**
```xml
<!-- launchd/com.02luka.gmx_cli.plist -->
<key>EnvironmentVariables</key>
<dict>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
    <key>HOME</key>
    <string>/Users/icmini</string>
    <key>SHELL</key>
    <string>/bin/zsh</string>
</dict>
```

**Effort:** Low (15 minutes)
**Risk:** High (may not work)
**Impact:** Low - Unlikely to solve the issue

---

### 🏅 Solution 4: Hybrid Approach - Fallback to Direct API

**Approach:** Try CLI first, fallback to direct API if CLI fails.

**Pros:**
- ✅ Best of both worlds
- ✅ Maintains compatibility
- ✅ Automatic fallback

**Cons:**
- ⚠️ More complex code
- ⚠️ Two code paths to maintain

**Implementation:**
```python
def run_gmx_mode(user_input: str) -> Dict[str, Any]:
    """Try CLI first, fallback to direct API."""
    # Try CLI approach
    result = _try_gemini_cli(user_input)
    if result.get("status") != "ERROR":
        return result
    
    # Fallback to direct API
    logger.warning("Gemini CLI failed, falling back to direct API")
    return _try_direct_api(user_input)
```

**Effort:** Medium-High (3-4 hours)
**Risk:** Low
**Impact:** High - Robust solution

---

### 🎯 Solution 5: Alternative Launch Mechanism

**Approach:** Replace launchd with a Python-based daemon or cron job.

**Pros:**
- ✅ Full control over environment
- ✅ Better debugging capabilities
- ✅ Cross-platform potential

**Cons:**
- ⚠️ Requires rewriting launch mechanism
- ⚠️ Lose launchd's file watching
- ⚠️ More complex deployment

**Implementation:**
```python
# g/tools/gmx_daemon.py
import time
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

class GMXFileHandler(FileSystemEventHandler):
    def on_modified(self, event):
        if event.src_path.endswith('gmx_todo.txt'):
            subprocess.run(['g/tools/gmx_todo_processor.sh'])

if __name__ == '__main__':
    observer = Observer()
    observer.schedule(GMXFileHandler(), '~/02luka', recursive=False)
    observer.start()
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()
```

**Effort:** High (4-6 hours)
**Risk:** Medium
**Impact:** Medium - Different approach, may introduce new issues

---

## Recommended Path Forward

### 🎯 **BEST SOLUTION: Use Existing Gemini Connector (Solution 1 - Enhanced)**

**Timeline:** 1-2 hours
**Goal:** Replace CLI subprocess with existing `gemini_connector.py`

**Why this is best:**
- ✅ **No new dependencies** - connector already exists
- ✅ **Already tested** - used elsewhere in codebase
- ✅ **Consistent architecture** - follows existing patterns
- ✅ **Eliminates CLI dependency** - solves launchd issue completely
- ✅ **Better error handling** - connector has retry logic

**Implementation Steps:**

1. **Update `g/tools/gmx_cli.py`:**
   ```python
   # Replace subprocess.run() with:
   from g.connectors.gemini_connector import GeminiConnector
   
   connector = GeminiConnector(model_name=GMX_MODEL)
   response = connector.generate_text(full_prompt, temperature=0.3)
   # Parse response["text"] as JSON
   ```

2. **Update `test_gmx_cli.py`:**
   - Mock `GeminiConnector.generate_text()` instead of `subprocess.run()`
   - Simpler mocking - no need to mock CLI output structure

3. **Test:**
   - Terminal: `python3 g/tools/gmx_cli.py "test"`
   - LaunchAgent: Write to `gmx_todo.txt` and verify

**Expected Result:** ✅ Works in both Terminal and launchd environments

---

### Alternative: Quick Test (Solution 2 - Wrapper Script)
**Timeline:** 30 minutes
**Goal:** Quick test if environment fixes the issue

**Use this if:** You want to test quickly before refactoring
**Skip this if:** You want the robust solution immediately

---

## Implementation Checklist

### For Solution 1 (Direct API - Recommended):

- [ ] Install `google-generativeai`: `pip install google-generativeai`
- [ ] Refactor `run_gmx_mode()` in `g/tools/gmx_cli.py`
- [ ] Update error handling for API-specific errors
- [ ] Update `test_gmx_cli.py` to mock `genai.GenerativeModel`
- [ ] Test in Terminal environment
- [ ] Test in launchd environment
- [ ] Update documentation

### For Solution 2 (Wrapper Script):

- [ ] Create `g/tools/gemini_wrapper.sh`
- [ ] Make executable: `chmod +x g/tools/gemini_wrapper.sh`
- [ ] Update `gmx_cli.py` to use wrapper path
- [ ] Test in launchd environment
- [ ] Document wrapper approach

---

## Testing Strategy

### Test Plan for Any Solution:

1. **Terminal Test:**
   ```bash
   cd ~/02luka
   python3 g/tools/gmx_cli.py "Test task"
   ```

2. **Manual Processor Test:**
   ```bash
   echo "Test task" >> ~/02luka/gmx_todo.txt
   g/tools/gmx_todo_processor.sh
   ```

3. **LaunchAgent Test:**
   ```bash
   echo "Test task" >> ~/02luka/gmx_todo.txt
   # Wait for launchd to trigger
   tail -f ~/02luka/logs/gmx_todo_processor.log
   ```

4. **Verify Work Order Created:**
   ```bash
   ls -lt ~/02luka/bridge/inbox/LIAM/ | head -1
   ```

---

## Decision Matrix

| Solution | Effort | Risk | Impact | Recommended? |
|----------|--------|------|--------|--------------|
| **Use Existing Connector** | **Low** | **Low** | **High** | ✅ **BEST** |
| Direct API (new code) | Medium | Low | High | ⚠️ Redundant (connector exists) |
| Wrapper Script | Low | Medium | Medium | ⚠️ Maybe (quick test) |
| Enhanced launchd | Low | High | Low | ❌ No |
| Hybrid | Medium-High | Low | High | ⚠️ Overkill |
| Alternative Launch | High | Medium | Medium | ❌ No (overkill) |

---

## Next Steps

1. **Immediate (Recommended):** Implement Solution 1 using existing `gemini_connector.py`
   - Refactor `g/tools/gmx_cli.py` to use `GeminiConnector`
   - Update tests to mock connector
   - Test in both Terminal and launchd
   - **Expected:** Solves launchd issue completely

2. **Alternative:** Quick test with Solution 2 (Wrapper Script)
   - 30-minute test to see if environment fixes it
   - If it works → great! If not → proceed to Solution 1

3. **Future Enhancement:** Add JSON response format support to connector
   - Currently connector returns text, we parse as JSON
   - Could enhance connector to support `response_mime_type="application/json"`

**Recommendation:** **Use existing `gemini_connector.py`** - it's the cleanest, most maintainable solution that leverages existing codebase infrastructure.

---

**Last Updated:** 2025-01-15 | **Status:** Planning Phase
