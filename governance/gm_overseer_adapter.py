# 02luka V4 - GM Overseer Adapter
# จุดนี้คุณจะเลือกเองว่าจะใช้ OpenAI หรือ Gemini จริง ๆ
# ผมทำแค่ "ช่อง" กับ prompt structure ให้

from __future__ import annotations

from typing import Any, Dict, Optional, TYPE_CHECKING

from .policy_loader import PolicyLoader

if TYPE_CHECKING:
    from .overseerd import TaskSpec

# NOTE:
# ที่นี่ห้ามใส่ API key ลงไปตรง ๆ
# ให้ไปอ่านจาก ENV ตามที่คุณ setup (เช่น GEMINI_API_KEY / OPENAI_API_KEY)


def maybe_call_gm_for_shell(
    spec: "TaskSpec",
    policy_loader: PolicyLoader,
    command: str,
) -> Optional[Dict[str, Any]]:
    """
    ถ้าอยากใช้ gm/GPT ช่วยคิด shell command นี้
    ให้ implement ที่นี่
    ตอนนี้ default = ไม่เรียก, คืน None
    """
    # TODO: connect to Gemini/OpenAI if needed
    return None


def maybe_call_gm_for_patch(
    spec: "TaskSpec",
    policy_loader: PolicyLoader,
    patch_meta: Dict[str, Any],
) -> Optional[Dict[str, Any]]:
    """
    ถ้าอยากใช้ gm/GPT ช่วยประเมิน patch
    ให้ implement ที่นี่
    ตอนนี้ default = ไม่เรียก, คืน None
    """
    # TODO: connect to Gemini/OpenAI if needed
    return None

# ต่อไปถ้าคุณอยากเสียบ Gemini 3 Pro:
# เราก็แค่เขียนฟังก์ชันเรียก gemini_g3pro_worker.g3pro_deep_prompt(...) 
# แล้ว parse JSON decision กลับไปตาม contract ที่เราคุยไว้ก่อนหน้า
