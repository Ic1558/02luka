# MLS Prompt Capture Gap - Critical Issue

**Date:** 2025-11-13  
**Status:** 🔴 CRITICAL - System Failure  
**Priority:** P1

## Problem

User tried to train AI with prompts, but MLS system didn't automatically capture them. This is a **critical failure** because:

1. **Training Lost**: All training efforts are lost if not manually recorded
2. **No Memory**: System cannot learn from past conversations
3. **MLS Purpose Failed**: MLS is supposed to be the "core brain" but it's not capturing conversations
4. **Manual Dependency**: Requires manual invocation = work gets forgotten

## Root Cause

- `mls_auto_record.zsh` exists but requires **manual invocation**
- No automatic hook for Cursor conversations
- No automatic hook for prompts/training sessions
- System relies on manual recording = **work gets lost**

## Solution Created

1. ✅ **Work Order Created**: `WO-20251113-MLS-PROMPT-CAPTURE.yaml`
2. ✅ **Hook Script Created**: `tools/mls_cursor_hook.zsh`
3. ⏳ **Integration Needed**: Hook into Cursor workflow

## Next Steps

1. Investigate Cursor API/integration options
2. Create automatic conversation capture
3. Test with real conversations
4. Ensure all prompts/training captured automatically

## Impact

**Without fix**: All training/prompts lost unless manually recorded  
**With fix**: MLS becomes true "core brain" that remembers everything
