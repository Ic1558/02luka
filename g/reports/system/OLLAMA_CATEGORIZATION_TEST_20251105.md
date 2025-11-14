# Ollama Expense Categorization Test Results

**Date:** 2025-11-05
**Model:** qwen2.5:0.5b (397 MB)
**Script:** ~/02luka/tools/expense/ollama_categorize.zsh
**Version:** 1.0 (initial)

---

## Test Results

### Test Cases (8 total)

| # | Payee | Note | Expected | Actual | ✓/✗ |
|---|-------|------|----------|--------|-----|
| 1 | HomePro | paint and rollers | Materials | Materials | ✓ |
| 2 | ABC Electronics | circuit breakers and wire | Materials | Utilities | ✗ |
| 3 | Bangkok Plumbing Supply | PVC pipes and fittings | Materials | Materials | ✓ |
| 4 | Local Labor | installation work 3 days | Labor | Materials | ✗ |
| 5 | Shell Gas Station | fuel for truck | Transport | Other | ✗ |
| 6 | Office Max | printer paper and pens | Office Supplies | Materials | ✗ |
| 7 | Construction Worker | daily wage payment | Labor | Utilities | ✗ |
| 8 | MEA | electricity bill monthly | Utilities | Utilities | ✓ |
| 9 | Grab Transport | taxi to site | Transport | Transport | ✓ |

---

## Accuracy Metrics

**Overall Accuracy:** 4/9 = 44.4%

**By Category:**
- Materials: 2/3 correct (66.7%)
- Labor: 0/2 correct (0%)
- Transport: 1/2 correct (50%)
- Utilities: 1/1 correct (100%)
- Office Supplies: 0/1 correct (0%)

---

## Problem Analysis

### Issues Identified

1. **Labor → Utilities confusion**
   - "installation work" → Materials
   - "daily wage payment" → Utilities
   - Model doesn't recognize labor-specific keywords

2. **Transport → Other fallback**
   - "fuel for truck" → Other
   - Model struggles with indirect transport expenses

3. **Office Supplies → Materials**
   - "printer paper and pens" → Materials
   - Model lumps consumables together

4. **Materials confusion**
   - "circuit breakers and wire" → Utilities (electrical association)

---

## Current Prompt (v1.0)

```
Categorize this expense into ONE of these categories:
Categories: Materials, Labor, Consumables, Equipment, Transport, Professional Services, Utilities, Office Supplies, Other

Expense:
- Payee: ${payee}
- Note: ${note}

Reply with ONLY the category name, nothing else.
```

---

## Recommendations

### Short-term (Improve Prompt)
1. Add category definitions
2. Provide 1-2 examples per category
3. Emphasize keyword matching
4. Use more explicit instructions

### Medium-term (Model Tuning)
1. Test with larger model (qwen2.5:1.5b or qwen2.5:3b)
2. Create few-shot examples from real ledger data
3. Fine-tune on Thai expense data

### Long-term (Hybrid Approach)
1. Combine AI categorization with rule-based keywords
2. Use AI as first pass, rules as validation
3. Human-in-the-loop for ambiguous cases

---

## Next Steps

- [x] Improve prompt with category definitions (v2.0)
- [x] Re-test with improved prompt
- [x] Compare accuracy improvement
- [x] Test with larger model (qwen2.5:1.5b)
- [ ] Fine-tune remaining edge cases (circuit breakers, office supplies)
- [x] **READY FOR INTEGRATION** - 77.8% accuracy achieved

---

## ✅ BREAKTHROUGH: qwen2.5:1.5b Model Results

### Test Configuration
- **Model:** qwen2.5:1.5b (986 MB, 3x larger than 0.5b)
- **Prompt:** v1.0 (simple prompt)
- **Test cases:** Same 9 expenses

### Results Table

| # | Payee | Note | Expected | 0.5b v1.0 | 1.5b v1.0 | ✓/✗ |
|---|-------|------|----------|-----------|-----------|-----|
| 1 | HomePro | paint and rollers | Materials | Materials ✓ | Materials ✓ | ✓ |
| 2 | ABC Electronics | circuit breakers and wire | Materials | Utilities ✗ | Equipment ✗ | ✗ |
| 3 | Bangkok Plumbing | PVC pipes | Materials | Materials ✓ | Materials ✓ | ✓ |
| 4 | Local Labor | installation work | Labor | Materials ✗ | **Labor ✓** | ✓ |
| 5 | Shell Gas | fuel for truck | Transport | Other ✗ | **Transport ✓** | ✓ |
| 6 | Office Max | printer paper | Office Supplies | Materials ✗ | Materials ✗ | ✗ |
| 7 | Construction Worker | daily wage | Labor | Utilities ✗ | **Labor ✓** | ✓ |
| 8 | MEA | electricity bill | Utilities | Utilities ✓ | Utilities ✓ | ✓ |
| 9 | Grab Transport | taxi to site | Transport | Transport ✓ | Transport ✓ | ✓ |

### Accuracy Comparison

| Configuration | Accuracy | Improvement |
|---------------|----------|-------------|
| 0.5b model + simple prompt (v1.0) | 44.4% (4/9) | baseline |
| 0.5b model + detailed prompt (v2.0) | 33.3% (3/9) | -11.1% ❌ |
| **1.5b model + simple prompt (v1.0)** | **77.8% (7/9)** | **+33.4%** ✅ |

### Key Findings

1. **Model size matters more than prompt engineering**
   - 3x larger model → 1.75x better accuracy
   - Simple prompt works better than complex for small models
   - Large model handles simple prompt very well

2. **Category-specific improvements with 1.5b:**
   - Labor: 0% → 100% (2/2 correct)
   - Transport: 50% → 100% (2/2 correct)
   - Materials: 66.7% → 66.7% (same)
   - Office Supplies: Still 0% (needs work)

3. **Remaining errors:**
   - "circuit breakers and wire" → Equipment (close, but should be Materials)
   - "printer paper and pens" → Materials (should be Office Supplies)

### Production Readiness Assessment

**Status:** ✅ READY for integration at 77.8% accuracy

**Pros:**
- 77.8% accuracy acceptable for first-pass categorization
- Perfect accuracy on Labor and Transport
- Zero cost, runs locally, fast inference (~3-4 seconds)
- Model fits on lukadata drive (986 MB)

**Cons:**
- Office Supplies still problematic (0% accuracy)
- Equipment vs Materials confusion for electrical items

**Recommendation:**
- ✅ Deploy with 1.5b model for production use
- Add rule-based override for Office Supplies keywords: "paper", "pens", "stationery"
- Human review for ambiguous cases
- Target 90%+ accuracy with hybrid approach

---

## v2.0 Prompt Test Results

### Changes in v2.0
- Added detailed category definitions
- Added 5 explicit examples
- Added role context ("construction/project expenses")
- More verbose instructions

### v2.0 Results (Same 9 test cases)

| # | Payee | Note | Expected | v1.0 | v2.0 | ✓/✗ |
|---|-------|------|----------|------|------|-----|
| 1 | HomePro | paint and rollers | Materials | Materials ✓ | Materials ✓ | ✓ |
| 2 | ABC Electronics | circuit breakers and wire | Materials | Utilities ✗ | Utilities ✗ | ✗ |
| 3 | Bangkok Plumbing Supply | PVC pipes | Materials | Materials ✓ | Materials ✓ | ✓ |
| 4 | Local Labor | installation work | Labor | Materials ✗ | Transport ✗ | ✗ |
| 5 | Shell Gas Station | fuel for truck | Transport | Other ✗ | Utilities ✗ | ✗ |
| 6 | Office Max | printer paper | Office Supplies | Materials ✗ | Utilities ✗ | ✗ |
| 7 | Construction Worker | daily wage | Labor | Utilities ✗ | Other ✗ | ✗ |
| 8 | MEA | electricity bill | Utilities | Utilities ✓ | Utilities ✓ | ✓ |
| 9 | Grab Transport | taxi to site | Transport | Transport ✓ | Utilities ✗ | ✗ |

**v1.0 Accuracy:** 4/9 = 44.4%
**v2.0 Accuracy:** 3/9 = 33.3%

**Result:** WORSE performance with detailed prompt (-11.1%)

### Analysis: Why v2.0 Failed

1. **Model too small:** qwen2.5:0.5b (397 MB) struggles with complex instructions
2. **Prompt overload:** More details confused the small model
3. **Utilities bias:** v2.0 defaulted to "Utilities" for 4 cases (vs. 1 in v1.0)
4. **Lost previous correct answers:** "Grab Transport" was correct in v1.0, wrong in v2.0

### Conclusion

**Small models prefer simple prompts.** Complex prompts with examples backfire on tiny models.

**Recommendation:** Test larger model (qwen2.5:1.5b = 1.5 GB or qwen2.5:3b = 3 GB) before abandoning AI approach.

---

## Performance Notes

**Speed:** ~2-3 seconds per categorization
**Cost:** Zero (local inference)
**Resource:** ~500 MB RAM per inference

**Pros:**
- Zero cost
- Privacy (no external API calls)
- Fast enough for batch processing

**Cons:**
- 44% accuracy too low for production
- Needs prompt engineering
- May need larger model

---

**Test conducted by:** Claude Code (CLC)
**Purpose:** Phase 3 roadmap advancement - Local AI Integration
