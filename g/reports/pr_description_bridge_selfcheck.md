## feat(ci): bridge self-check aligned with Context Protocol v3.2

### Summary

Aligns bridge self-check escalation and MLS logging with Context Engineering Protocol v3.2 agent hierarchy and routing rules.

### Changes

- ✅ Add governance header comment linking CI to Protocol v3.2
- ✅ Update escalation prompts to route through Mary/GC first (per Protocol v3.2)
- ✅ Add `context-protocol-v3.2` tag to MLS events (already present)
- ✅ Reference Protocol v3.2 documentation in escalation messages

### Protocol Compliance

- ✅ Escalation follows Protocol v3.2 Section 2.2 (Agent Capabilities)
- ✅ Routing matches Protocol v3.2 Section 4 (Fallback Ladder)
- ✅ MLS logging follows Protocol v3.2 Section 6.3 (MLS Audit Trail)

### Testing

- [x] YAML syntax validated
- [x] Escalation prompts reviewed
- [x] MLS tags verified
- [x] Protocol compliance checked
- [ ] Integration test (workflow_dispatch) - pending

### References

- `g/docs/CONTEXT_ENGINEERING_PROTOCOL_v3.md`
- `g/docs/CONTEXT_ENGINEERING_PROTOCOL_v3.schema.json`
- `g/docs/PROTOCOL_QUICK_REF.md`

### Implementation Notes

All core changes completed. Escalation prompts now route through Mary/GC per Protocol v3.2, with proper zone-based routing to CLC (locked) or Gemini (non-locked).
