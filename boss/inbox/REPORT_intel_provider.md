# 2025-02-14 IntelSphere Provider Report

## Environment Setup
Add the following variables to your Paula/Mary `.env` (or host environment):

```
KKU_INTELSPHERE_BASE=https://api.intelsphere.kku.ac.th/v1
KKU_INTELSPHERE_KEY=<api_key>
```

## Usage
```python
from g.providers import intel_provider

if intel_provider.healthcheck():
    reply = intel_provider.chat_complete([
        {"role": "user", "content": "สรุปภาพรวมเศรษฐกิจไทยวันนี้"}
    ])
    print(reply)
else:
    raise RuntimeError("IntelSphere offline")
```

## Health Verification
Run inside the project root:

```
python3 - <<'PY'
from g.providers import intel_provider
print("health", intel_provider.healthcheck())
print("sample", intel_provider.chat_complete([
    {"role": "system", "content": "ตอบสั้น ๆ"},
    {"role": "user", "content": "บทสรุปเงินเฟ้อ"}
]))
PY
```

## Notes
- Requests time out after 30 seconds and retry twice on transient errors.
- Errors raise `IntelSphereError` with contextual messages.
