# Hybrid Router - Use Case Matrix & Engine Recommendations

**Date:** 2025-12-01  
**Feature:** Hybrid Router (Local + GG + Alter)  
**File:** `g/reports/feature-dev/hybrid_router/251201_hybrid_router_use_case_matrix.md`

---

## Executive Summary

This matrix provides **engine recommendations** for 6 real use cases in 02luka, based on:
- **Sensitivity** (internal vs client-facing)
- **Volume** (single vs batch)
- **Quality requirements** (draft vs polished)
- **Privacy/compliance** needs

**Decision Framework:**
- **Local (Ollama):** Internal, sensitive, high-volume, draft/analysis
- **GG (ChatGPT Plus):** General reasoning, orchestration, complex tasks
- **Alter (Polish API):** Client-facing, polish, translation, presentation

---

## Use Case Matrix

| Use Case | Sensitivity | Volume | Quality | Recommended Engine | Risk | Benefit |
|----------|-------------|--------|---------|-------------------|------|---------|
| **1. Internal Draft** | High | High | Draft | **Local** | Low | Privacy, Cost-free, Speed |
| **2. Cost Calculation** | High | Medium | Analysis | **Local** | Low | Privacy, Accuracy, No leaks |
| **3. Client Report** | Low | Low | Polish | **GG → Alter** | Low | Quality, Professional |
| **4. Proposal** | Low | Low | Polish | **GG → Alter** | Low | Presentation, Bilingual |
| **5. Translation** | Medium | Medium | Polish | **Local → Alter** | Low | Privacy + Quality |
| **6. Backup Doc** | High | High | Draft | **Local** | Low | Privacy, Speed, Cost-free |

---

## Detailed Use Case Analysis

### 1. Internal Draft (Analysis, Protocol, Spec)

**Context:**
- Internal documentation
- Analysis, protocol, spec writing
- Not client-facing
- May contain sensitive data

**Recommended Engine:** **Local (Ollama)**

**Flow:**
```
Input → Local (Ollama) → Draft Output
```

**Rationale:**
- ✅ **Privacy:** Data stays on-premises
- ✅ **Cost:** Free (no API costs)
- ✅ **Speed:** No network latency
- ✅ **Volume:** Can handle batch processing
- ⚠️ **Quality:** May need manual review for complex topics

**Risk:** Low
- Local model may not be as strong as cloud
- **Mitigation:** Use GG for complex reasoning if needed

**Benefit:** High
- Privacy protection
- Cost savings
- Fast processing
- No quota limits

**Example:**
```python
context = {
    "sensitivity": "high",
    "client_facing": False,
    "mode": "draft",
    "source_agent": "docs_worker"
}
result = hybrid_route_text(text, context)
# → Routes to Local (Ollama)
```

---

### 2. Cost Calculation (BOQ, Budget Analysis)

**Context:**
- Internal cost calculations
- BOQ (Bill of Quantities)
- Budget analysis
- Financial data (sensitive)

**Recommended Engine:** **Local (Ollama)**

**Flow:**
```
Input → Local (Ollama) → Analysis Output
```

**Rationale:**
- ✅ **Privacy:** Financial data stays local
- ✅ **Compliance:** No data leaks to cloud
- ✅ **Accuracy:** Local model sufficient for calculations
- ✅ **Audit:** Full control over data path

**Risk:** Low
- Local model may need verification for complex calculations
- **Mitigation:** Use GG for complex financial reasoning if needed

**Benefit:** High
- Privacy protection
- Compliance
- Cost savings
- Audit trail

**Example:**
```python
context = {
    "sensitivity": "high",
    "client_facing": False,
    "mode": "analysis",
    "project_id": "PD17",
    "source_agent": "lac_manager"
}
result = hybrid_route_text(text, context)
# → Routes to Local (Ollama)
```

---

### 3. Client Report (Final Report, Summary)

**Context:**
- Client-facing reports
- Final summaries
- Professional presentation
- May need bilingual (Thai/English)

**Recommended Engine:** **GG → Alter**

**Flow:**
```
Input → GG (draft) → Alter (polish) → Final Output
```

**Rationale:**
- ✅ **Quality:** GG creates high-quality draft
- ✅ **Polish:** Alter enhances language for client presentation
- ✅ **Bilingual:** Alter handles translation if needed
- ✅ **Professional:** Formal tone, polished language

**Risk:** Low
- Uses Alter quota (40k lifetime)
- **Mitigation:** Check quota before calling Alter, fallback to GG draft if needed

**Benefit:** High
- Professional quality
- Client-ready output
- Bilingual support
- Time savings

**Example:**
```python
context = {
    "sensitivity": "normal",
    "client_facing": True,
    "mode": "polish",
    "project_id": "PD17",
    "language": "th-en",
    "source_agent": "docs_worker"
}
result = hybrid_route_text(text, context)
# → Routes to GG (draft) → Alter (polish)
```

---

### 4. Proposal (Client Proposal, Presentation)

**Context:**
- Client proposals
- Presentation materials
- Marketing content
- Professional presentation

**Recommended Engine:** **GG → Alter**

**Flow:**
```
Input → GG (draft) → Alter (polish) → Final Output
```

**Rationale:**
- ✅ **Quality:** GG creates compelling draft
- ✅ **Polish:** Alter enhances for presentation
- ✅ **Bilingual:** Alter handles translation
- ✅ **Professional:** Client-ready output

**Risk:** Low
- Uses Alter quota
- **Mitigation:** Check quota, fallback to GG draft

**Benefit:** High
- Professional presentation
- Client-ready
- Bilingual support
- Time savings

**Example:**
```python
context = {
    "sensitivity": "normal",
    "client_facing": True,
    "mode": "polish",
    "project_id": "PD17",
    "language": "th-en",
    "tone": "formal",
    "source_agent": "docs_worker"
}
result = hybrid_route_text(text, context)
# → Routes to GG (draft) → Alter (polish)
```

---

### 5. Translation (Bilingual Content)

**Context:**
- Bilingual translation
- Thai ↔ English
- May contain sensitive content
- Needs quality translation

**Recommended Engine:** **Local → Alter**

**Flow:**
```
Input → Local (draft) → Alter (translate + polish) → Final Output
```

**Rationale:**
- ✅ **Privacy:** Sensitive content stays local for draft
- ✅ **Quality:** Alter provides high-quality translation
- ✅ **Polish:** Alter enhances translated text
- ✅ **Hybrid:** Best of both worlds

**Risk:** Low
- Uses Alter quota
- **Mitigation:** Check quota, fallback to Local draft

**Benefit:** High
- Privacy protection (draft stays local)
- Quality translation
- Professional output
- Time savings

**Example:**
```python
context = {
    "sensitivity": "medium",
    "client_facing": True,
    "mode": "translate",
    "language": "th-en",
    "source_agent": "docs_worker"
}
result = hybrid_route_text(text, context)
# → Routes to Local (draft) → Alter (translate + polish)
```

---

### 6. Backup Doc (Internal Archive, Version Control)

**Context:**
- Internal backup documents
- Version control
- Archive materials
- Not client-facing

**Recommended Engine:** **Local (Ollama)**

**Flow:**
```
Input → Local (Ollama) → Draft Output
```

**Rationale:**
- ✅ **Privacy:** Backup data stays local
- ✅ **Cost:** Free (no API costs)
- ✅ **Speed:** Fast processing
- ✅ **Volume:** Can handle batch processing

**Risk:** Low
- Local model sufficient for backup docs

**Benefit:** High
- Privacy protection
- Cost savings
- Fast processing
- No quota limits

**Example:**
```python
context = {
    "sensitivity": "high",
    "client_facing": False,
    "mode": "draft",
    "source_agent": "docs_worker"
}
result = hybrid_route_text(text, context)
# → Routes to Local (Ollama)
```

---

## Decision Matrix Summary

### Engine Selection Rules

| Condition | Engine | Reason |
|-----------|--------|--------|
| `sensitivity == "high"` | **Local** | Privacy, compliance |
| `client_facing == False` AND `mode in ["draft", "analysis"]` | **Local** | Internal work, cost-free |
| `client_facing == True` OR `mode in ["polish", "translate"]` | **GG → Alter** | Quality, presentation |
| `sensitivity == "medium"` AND `mode == "translate"` | **Local → Alter** | Privacy + quality |

### Risk vs Benefit Matrix

| Use Case | Risk Level | Benefit Level | Recommendation |
|----------|-----------|---------------|---------------|
| Internal Draft | Low | High | ✅ **Use Local** |
| Cost Calculation | Low | High | ✅ **Use Local** |
| Client Report | Low | High | ✅ **Use GG → Alter** |
| Proposal | Low | High | ✅ **Use GG → Alter** |
| Translation | Low | High | ✅ **Use Local → Alter** |
| Backup Doc | Low | High | ✅ **Use Local** |

---

## Implementation Recommendations

### Phase 1: Start with Low-Risk Use Cases

**Priority 1 (Start Here):**
1. **Internal Draft** → Local (Ollama)
2. **Backup Doc** → Local (Ollama)

**Why:** Low risk, high benefit, no quota usage

### Phase 2: Add Client-Facing Use Cases

**Priority 2 (After Phase 1):**
3. **Client Report** → GG → Alter
4. **Proposal** → GG → Alter

**Why:** Higher value, uses Alter quota (monitor usage)

### Phase 3: Add Hybrid Use Cases

**Priority 3 (After Phase 2):**
5. **Translation** → Local → Alter
6. **Cost Calculation** → Local

**Why:** More complex, requires testing

---

## Measurement Criteria

### For Each Use Case, Measure:

1. **Time Saved**
   - Manual time vs automated time
   - Target: 50%+ time savings

2. **Quality**
   - Compare output to manual work
   - Target: 80%+ quality match

3. **Cost**
   - Quota usage (Alter)
   - Hardware costs (Local)
   - Target: Cost-effective

4. **Privacy/Compliance**
   - Data leak risk
   - Audit trail
   - Target: Zero leaks, full audit

---

## Success Metrics

### Overall Success Criteria:

- ✅ **5-6 use cases** implemented and working
- ✅ **50%+ time savings** vs manual
- ✅ **80%+ quality** match vs manual
- ✅ **Zero data leaks** (privacy maintained)
- ✅ **Cost-effective** (Alter quota usage < 20% of lifetime)

---

## Next Steps

1. **Review this matrix** with team
2. **Select 1-2 use cases** to start (Priority 1)
3. **Implement router** (Phase H1 from plan)
4. **Test with selected use cases**
5. **Measure results** (time, quality, cost, privacy)
6. **Scale to more use cases** if successful

---

**Matrix Version:** 1.0  
**Last Updated:** 2025-12-01  
**Status:** ✅ Ready for Review
