# Feature Plan: Telegram System Alerts Bot Merge

**Feature ID**: `feature_telegram_system_alerts_merge`  
**Created**: 2025-12-05  
**Status**: Planning  
**Priority**: P1 (Security & Infrastructure)

---

## Executive Summary

Merge `GUARD_BOT` and `GPT_ALERTS` into a single unified **SYSTEM_ALERTS_BOT** that sends all system/infra/error-level/guard-level alerts exclusively to Boss's private chat (`6351780525`), removing system alerts from company-facing channels like `@Edge.Work`.

**Rationale**: 
- Eliminates functional duplication (both bots serve identical system alert purposes)
- Improves security by isolating sensitive system information from team channels
- Simplifies alert routing and maintenance
- Aligns with DevOps best practices for alert segregation

---

## Clarifying Questions & Decisions

### ✅ Confirmed Decisions

1. **Merge Scope**: `GUARD_BOT` + `GPT_ALERTS` → `SYSTEM_ALERTS_BOT`
2. **Destination**: Boss private chat only (`6351780525`)
3. **Exclusion**: Remove system alerts from `@Edge.Work` group
4. **Bot Token Strategy**: Use `TELEGRAM_BOT_TOKEN_GPT_ALERTS` as the unified token (keep existing token, rename logically)

### ❓ Questions to Confirm

1. **Bot Token Selection**: 
   - Option A: Use `TELEGRAM_BOT_TOKEN_GPT_ALERTS` (existing token, rename to `TELEGRAM_SYSTEM_ALERT_BOT_TOKEN`)
   - Option B: Use `TELEGRAM_GUARD_BOT_TOKEN` (existing token, rename to `TELEGRAM_SYSTEM_ALERT_BOT_TOKEN`)
   - **Recommendation**: Option A (GPT_ALERTS token) since it's already configured for private chat

2. **Deprecation Timeline**:
   - Immediate removal of `TELEGRAM_GUARD_BOT_TOKEN` from `.env.local`?
   - Or keep as deprecated/backup for migration period?

3. **Backward Compatibility**:
   - Should existing scripts that reference `TELEGRAM_GUARD_BOT_TOKEN` continue to work via alias?
   - Or require explicit migration to new variable name?

4. **Alert Message Format**:
   - Keep existing formats from both bots?
   - Or standardize to a unified format with alert type prefixes?

---

## Current State Analysis

### Existing Bot Configuration

| Bot | Token Variable | Chat ID | Current Destination | Purpose |
|-----|---------------|---------|---------------------|---------|
| **GUARD_BOT** | `TELEGRAM_GUARD_BOT_TOKEN` | `-1002727852946` | `@Edge.Work` (group) | Guard health alerts |
| **GPT_ALERTS** | `TELEGRAM_BOT_TOKEN_GPT_ALERTS` | `6351780525` | Boss private | Error/system alerts |
| **EDGEWORK** | `TELEGRAM_BOT_TOKEN_EDGEWORK` | `-1002727852946` | `@Edge.Work` (group) | Company work messages |
| **KIM** | `TELEGRAM_BOT_TOKEN_KIM` | `-1002433798273` | `@IC_Notify` (group) | Team interaction |
| **TRADER** | `TELEGRAM_BOT_TOKEN_TRADER` | `6351780525` | Boss private | Trading alerts |
| **GGMESH** | `TELEGRAM_BOT_TOKEN_GGMESH` | `6351780525` | Boss private | Internal dev |

### Alert Sources (To Be Migrated)

**GUARD_BOT Sources:**
- `g/tools/guard_health_alert.zsh` (if exists)
- `g/tools/guard_health_daily.zsh` (guard health pipeline)
- Any scripts referencing `TELEGRAM_GUARD_BOT_TOKEN`

**GPT_ALERTS Sources:**
- Error monitoring scripts
- System health checkers
- Exception handlers
- Any scripts referencing `TELEGRAM_BOT_TOKEN_GPT_ALERTS` for alerts

### Files Requiring Updates

**Configuration:**
- `~/.env.local` - Rename/merge bot token variables
- `g/tools/get_all_telegram_chat_ids.sh` - Update bot list

**Alert Dispatchers:**
- `g/tools/guard_health_alert.zsh` (if exists) - Update token/chat ID
- `g/tools/guard_health_daily.zsh` - Update alert routing
- Any Python/shell scripts sending system alerts

**Documentation:**
- `g/docs/telegram_bot_routing.md` (to be created)
- Update any existing bot documentation

---

## Target State Design

### New Bot Architecture

```
SYSTEM_ALERTS_BOT
├── Token: TELEGRAM_SYSTEM_ALERT_BOT_TOKEN (from GPT_ALERTS)
├── Chat ID: 6351780525 (Boss private)
└── Purpose: All system/infra/error/guard alerts
```

### Bot Role Matrix (Post-Merge)

| Bot | Room | Purpose | Alert Level |
|-----|------|---------|-------------|
| **SYSTEM_ALERTS_BOT** | Boss Private (`6351780525`) | System health, errors, guard alerts | Critical/Error/Guard |
| **EDGEWORK Bot** | `@Edge.Work` | Company work, progress reports | Info (non-sensitive) |
| **KIM Bot** | `@IC_Notify` | Team interaction, file sharing | Interactive |
| **TRADER Bot** | Boss Private | Trading signals | Trading-specific |
| **GGMESH** | Boss Private | Internal dev | Dev-specific |

### Alert Routing Rules

**→ SYSTEM_ALERTS_BOT (Boss Private):**
- ✅ Guard health failures
- ✅ Infrastructure failures (Redis, tunnels, reverse proxy)
- ✅ Agent/orchestrator crashes
- ✅ Error-level exceptions
- ✅ Fatal logs
- ✅ Any alert requiring immediate Boss attention

**→ EDGEWORK Bot (@Edge.Work):**
- ✅ Work progress reports
- ✅ Site photos
- ✅ Non-sensitive status updates
- ❌ NO system errors
- ❌ NO infrastructure details

**→ Other Bots:**
- Unchanged (KIM, TRADER, GGMESH keep existing roles)

---

## Implementation Tasks

### Phase 1: Environment Configuration

- [ ] **T1.1**: Create `TELEGRAM_SYSTEM_ALERT_BOT_TOKEN` in `.env.local`
  - Copy value from `TELEGRAM_BOT_TOKEN_GPT_ALERTS`
  - Set `TELEGRAM_SYSTEM_ALERT_CHAT_ID="6351780525"`

- [ ] **T1.2**: Deprecate old variables (keep for migration period)
  - Comment out `TELEGRAM_GUARD_BOT_TOKEN` with deprecation notice
  - Add migration notes to `TELEGRAM_BOT_TOKEN_GPT_ALERTS`

- [ ] **T1.3**: Update helper scripts
  - Update `get_all_telegram_chat_ids.sh` to recognize new variable names
  - Add backward compatibility checks

### Phase 2: Alert Dispatcher Updates

- [ ] **T2.1**: Create/update `g/tools/system_alert_send.sh`
  - Unified dispatcher for all system alerts
  - Uses `TELEGRAM_SYSTEM_ALERT_BOT_TOKEN` and `TELEGRAM_SYSTEM_ALERT_CHAT_ID`
  - Supports alert type prefixes (GUARD, ERROR, INFRA, etc.)

- [ ] **T2.2**: Update `g/tools/guard_health_alert.zsh` (if exists)
  - Change from `TELEGRAM_GUARD_BOT_TOKEN` → `TELEGRAM_SYSTEM_ALERT_BOT_TOKEN`
  - Change chat ID from `@Edge.Work` → Boss private

- [ ] **T2.3**: Update `g/tools/guard_health_daily.zsh`
  - Modify alert hook to use new dispatcher
  - Ensure routing to Boss private only

- [ ] **T2.4**: Find and update all error alert scripts
  - Search for references to `TELEGRAM_BOT_TOKEN_GPT_ALERTS`
  - Update to use `TELEGRAM_SYSTEM_ALERT_BOT_TOKEN`
  - Verify chat ID routing

### Phase 3: Python Alert Handlers

- [ ] **T3.1**: Update `g/tools/redis_to_telegram.py` (if used for alerts)
  - Add support for `TELEGRAM_SYSTEM_ALERT_BOT_TOKEN`
  - Route system alerts to Boss private

- [ ] **T3.2**: Audit Python exception handlers
  - Find all Python scripts that send Telegram alerts
  - Update to use unified system alert bot

### Phase 4: Documentation & Routing Spec

- [ ] **T4.1**: Create `g/docs/telegram_bot_routing.md`
  - Document bot roles and purposes
  - Alert routing matrix
  - Migration guide

- [ ] **T4.2**: Update `.env.local` comments
  - Add clear descriptions for each bot
  - Mark deprecated variables

- [ ] **T4.3**: Create migration checklist
  - Step-by-step guide for updating scripts
  - Testing procedures

### Phase 5: Testing & Validation

- [ ] **T5.1**: Test guard health alert flow
  - Trigger guard failure
  - Verify alert reaches Boss private chat
  - Verify NO alert in `@Edge.Work`

- [ ] **T5.2**: Test error alert flow
  - Trigger system error
  - Verify routing to Boss private
  - Verify message format

- [ ] **T5.3**: Test backward compatibility (if implemented)
  - Verify old variable names still work during migration
  - Test deprecation warnings

- [ ] **T5.4**: Integration test
  - Full system alert pipeline test
  - Verify all alert types route correctly

### Phase 6: Cleanup

- [ ] **T6.1**: Remove deprecated variables (after migration period)
  - Remove `TELEGRAM_GUARD_BOT_TOKEN` from `.env.local`
  - Remove `TELEGRAM_BOT_TOKEN_GPT_ALERTS` (replaced by SYSTEM_ALERT)

- [ ] **T6.2**: Update all references
  - Final sweep for any remaining old variable references
  - Update documentation

---

## Test Strategy

### Unit Tests

1. **Alert Dispatcher Test**
   - Mock Telegram API
   - Verify correct token/chat ID usage
   - Test alert message formatting

2. **Environment Variable Loading**
   - Test fallback to deprecated variables
   - Test new variable precedence

### Integration Tests

1. **Guard Health Alert Pipeline**
   ```bash
   # Simulate guard failure
   # Verify alert sent to Boss private
   # Verify no alert in @Edge.Work
   ```

2. **Error Alert Pipeline**
   ```bash
   # Trigger system error
   # Verify routing to SYSTEM_ALERTS_BOT
   # Verify message format
   ```

### Manual Testing Checklist

- [ ] Send test guard alert → Verify Boss receives in private chat
- [ ] Send test error alert → Verify Boss receives in private chat
- [ ] Verify NO alerts appear in `@Edge.Work` group
- [ ] Verify EDGEWORK bot still works for company messages
- [ ] Verify other bots (KIM, TRADER) unaffected

---

## Migration Checklist

### Pre-Migration

- [ ] Backup `.env.local`
- [ ] Document current alert flows
- [ ] Identify all scripts using old bot tokens
- [ ] Create rollback plan

### Migration Steps

1. [ ] Add new `TELEGRAM_SYSTEM_ALERT_BOT_TOKEN` to `.env.local`
2. [ ] Add `TELEGRAM_SYSTEM_ALERT_CHAT_ID="6351780525"`
3. [ ] Update `system_alert_send.sh` dispatcher
4. [ ] Update guard health alert scripts
5. [ ] Update error alert scripts
6. [ ] Test each alert type
7. [ ] Verify no alerts in `@Edge.Work`
8. [ ] Document routing changes

### Post-Migration

- [ ] Monitor alert delivery for 24-48 hours
- [ ] Verify no missed alerts
- [ ] Remove deprecated variables (after confirmation period)
- [ ] Update all documentation

---

## Risk Assessment

### High Risk

- **Alert Delivery Failure**: If migration breaks alert routing, critical system issues may go unnoticed
  - **Mitigation**: Test thoroughly before removing old variables, keep both active during transition

### Medium Risk

- **Backward Compatibility**: Existing scripts may break if variables removed too quickly
  - **Mitigation**: Implement deprecation period with warnings, provide migration guide

### Low Risk

- **Team Confusion**: Team members may expect alerts in `@Edge.Work`
  - **Mitigation**: Clear documentation, communication about routing changes

---

## Success Criteria

✅ **Functional**
- All system alerts route to Boss private chat (`6351780525`)
- No system alerts appear in `@Edge.Work` group
- Guard health alerts work correctly
- Error alerts work correctly
- EDGEWORK bot continues working for company messages

✅ **Security**
- System information isolated from team channels
- Sensitive error details only visible to Boss

✅ **Maintainability**
- Single unified bot for system alerts
- Clear routing documentation
- No duplicate alert functionality

---

## Dependencies

- Telegram bot tokens configured in `.env.local`
- Chat IDs already obtained and configured
- Existing alert scripts identified
- Testing environment available

---

## Timeline Estimate

- **Phase 1** (Environment): 30 minutes
- **Phase 2** (Dispatchers): 1-2 hours
- **Phase 3** (Python): 1 hour
- **Phase 4** (Documentation): 1 hour
- **Phase 5** (Testing): 1-2 hours
- **Phase 6** (Cleanup): 30 minutes

**Total**: ~5-7 hours

---

## Open Questions

1. Should we implement backward compatibility layer (old variables → new variables)?
2. What is the deprecation period for old variables?
3. Should alert messages include source bot identifier (GUARD vs ERROR)?
4. Do we need alert deduplication logic?

---

## Next Steps

1. **Boss Review**: Confirm bot token selection (GPT_ALERTS vs GUARD_BOT)
2. **Confirm Questions**: Answer open questions above
3. **Begin Implementation**: Start with Phase 1 (Environment Configuration)
4. **Iterative Testing**: Test each phase before proceeding

---

**Plan Status**: ✅ Ready for Review  
**Next Action**: Await Boss confirmation on bot token selection and open questions
