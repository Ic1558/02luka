# Deploy Summary — {{ feature_name }}

**Deploy Type**: full  
**Date**: {{ date }}  
**Risk Level**: {{ risk }}  
**Owner**: Liam / Hybrid  

---

## 1. Objective

{{ description }}

---

## 2. Changes

### Files Changed:
{% for file in files_changed %}
- `{{ file }}`
{% endfor %}

### Components Affected:
{% for component in components_affected %}
- {{ component }}
{% endfor %}

---

## 3. Impact Assessment (V3.5)

- **Deploy Type**: full
- **Risk Level**: {{ risk }}
- **Requires Rollback**: {{ requires_rollback }}
- **SOT Update**: {{ update_sot }}
- **AI Context Update**: {{ update_ai_context }}
- **Worker Notification**: {{ notify_workers }}

**Reason**: {{ reason }}

---

## 4. Deployment Steps

1. Pre-deployment validation
2. Files updated via Hybrid executor
3. {% if update_sot %}SOT updated via `tools/update_sot_v35.zsh`{% endif %}
4. {% if update_ai_context %}AI context updated via `tools/update_ai_context_v35.py`{% endif %}
5. {% if notify_workers %}Workers notified via AP/IO events{% endif %}
6. Post-deployment health checks
7. Rollback script generated

---

## 5. Rollback

**Rollback Script**: `rollback.zsh`

To rollback this deployment:
```bash
./rollback.zsh
```

---

## 6. Validation Checks

- [ ] All files deployed successfully
- [ ] No errors in AP/IO ledger
- [ ] {% if update_sot %}SOT updated correctly{% endif %}
- [ ] {% if update_ai_context %}AI context refreshed{% endif %}
- [ ] {% if notify_workers %}Workers acknowledged{% endif %}

---

## 7. AP/IO Reference

- **Event**: `deploy_impact_assessed`
- **Deploy Type**: `full`
- **Logged**: {{ timestamp }}

---

**Status**: ✅ Deployed (Full)
