---
project: general
tags: [legacy]
---
# Codex Merge Plan - Critical Features Missing

## Current Status
- **Unmerged Codex Branches**: 41 branches
- **Current System**: Basic boss-api/boss-ui structure
- **Missing**: Major API endpoints, UI features, automation

## Priority 1: Critical API Features
1. **origin/codex/add-api-endpoints-for-snapshot-and-run**
   - Snapshot automation
   - Run automation
   - Essential for system management

2. **origin/codex/add-clc-runner-and-model-router**
   - CLC runner integration
   - Model router functionality
   - AI model dispatch

3. **origin/codex/add-human-mailbox-and-update-ui/api**
   - Human mailbox system
   - UI/API wiring
   - Core communication features

## Priority 2: UI Enhancements
4. **origin/codex/add-drag-and-drop-upload-feature**
   - File upload capabilities
   - User experience improvement

5. **origin/codex/add-prompt-optimizer-tool-to-toolbar**
   - Prompt optimization
   - AI interaction enhancement

## Priority 3: System Integration
6. **origin/codex/implement-local-engines-in-server.cjs**
   - Local engine integration
   - Performance optimization

## Merge Strategy
1. Start with Priority 1 features (API endpoints)
2. Resolve conflicts systematically
3. Test each merge before proceeding
4. Create intermediate tags for rollback points

## Risk Assessment
- **High Risk**: Multiple API endpoint merges
- **Medium Risk**: UI feature conflicts
- **Low Risk**: Documentation updates

## Next Steps
1. Merge Priority 1 features first
2. Test system stability
3. Continue with Priority 2
4. Create production tag after all critical features merged
