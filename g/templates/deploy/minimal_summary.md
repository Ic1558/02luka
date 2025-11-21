# Deploy Summary — {{ feature_name }}

**Deploy Type**: minimal  
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

- **Deploy Type**: minimal
- **Risk Level**: {{ risk }}
- **Requires Rollback**: No
- **SOT Update**: {{ update_sot }}
- **AI Context Update**: {{ update_ai_context }}
- **Worker Notification**: {{ notify_workers }}

**Reason**: {{ reason }}

---

## 4. Deployment Steps

1. Files updated via Hybrid executor
2. Changes validated
3. AP/IO events logged

---

## 5. AP/IO Reference

- **Event**: `deploy_impact_assessed`
- **Deploy Type**: `minimal`
- **Logged**: {{ timestamp }}

---

**Status**: ✅ Deployed (Minimal)
