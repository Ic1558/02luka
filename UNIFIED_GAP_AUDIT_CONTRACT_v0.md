# Unified Gap Audit Contract v0

This contract standardizes how to report gaps so each finding is isolated, source-scoped, and layer-safe.

## Pre-Gap Gate (must pass before any gap is logged)

1. **State source authority**
   - Name the canonical source document/system of record.
   - If multiple candidates exist, select one primary and mark alternates as references.

2. **State layer**
   - Declare exactly one layer for the next finding:
     - `constitutional`
     - `registry`
     - `schema`
     - `runtime`

3. **One-gap-one-mismatch**
   - Each gap entry must represent one mismatch only.
   - If two mismatches are discovered, emit two entries.

4. **Status mark is mandatory**
   - Every gap entry must include exactly one status:
     - `duplicate`
     - `refute`
     - `verify-needed`

5. **No cross-layer mixing**
   - A single gap entry cannot include evidence from multiple layers as the mismatch basis.
   - Cross-layer implications are recorded as notes only, not as part of mismatch proof.

6. **Ambiguity HOLD rule**
   - If gap IDs or source references are ambiguous, stop and return:
     - `HOLD: ambiguous gap id/source`
   - Do not log a gap until ambiguity is resolved.

## Gap Entry Template

```yaml
gap_id: <id or HOLD>
source_authority: <canonical source>
layer: <constitutional|registry|schema|runtime>
mismatch: <single mismatch statement>
status: <duplicate|refute|verify-needed>
evidence:
  - <specific citation/artifact>
notes:
  - <optional, non-mismatch context>
```

## HOLD Response Template

```text
HOLD: ambiguous gap id/source
needed:
  - canonical_source
  - explicit_gap_id_or_target_scope
  - declared_layer
```
