"""
Requirement Parser - LAC v4
Parses Requirement.md files into structured task definitions.
Supports: Fenced JSON/YAML blocks, Key:Value pairs.
"""
import re
import yaml
import json
from typing import Dict, Any

def parse_requirement_md(content: str) -> Dict[str, Any]:
    """
    Parse Requirement.md content into a structured dictionary.
    
    Strategy:
    1. Look for fenced code blocks marked as 'json' or 'yaml' containing 'wo_id'.
    2. If found, parse and return.
    3. If not, fall back to parsing Key: Value lines.
    """
    
    # 1. Try Fenced Blocks
    json_match = re.search(r'```json\s*(\{.*?\})\s*```', content, re.DOTALL)
    if json_match:
        try:
            data = json.loads(json_match.group(1))
            if "wo_id" in data:
                return _apply_defaults(data)
        except json.JSONDecodeError:
            pass

    yaml_match = re.search(r'```yaml\s*(.*?)\s*```', content, re.DOTALL)
    if yaml_match:
        try:
            data = yaml.safe_load(yaml_match.group(1))
            if isinstance(data, dict) and "wo_id" in data:
                return _apply_defaults(data)
        except yaml.YAMLError:
            pass

    # 2. Fallback: Key-Value Parsing
    data = {}
    lines = content.split('\n')
    current_section = None
    
    for line in lines:
        line = line.strip()
        if not line:
            continue
            
        # Parse Metadata (e.g., "**ID:** REQ-001")
        meta_match = re.match(r'\*\*([a-zA-Z0-9_]+):\*\*\s*(.*)', line)
        if meta_match:
            key = meta_match.group(1).lower()
            val = meta_match.group(2).strip()
            data[key] = val
            continue
            
        # Parse Sections (e.g., "## Objective")
        header_match = re.match(r'^##\s+(.*)', line)
        if header_match:
            current_section = header_match.group(1).lower().replace(" ", "_")
            data[current_section] = ""
            continue
            
        # Append content to section
        if current_section:
            data[current_section] += line + "\n"

    # Map parsed keys to standard schema
    structured = {
        "wo_id": data.get("id", "UNKNOWN"),
        "objective": data.get("objective", "").strip(),
        "priority": data.get("priority", "P2"),
        "complexity": data.get("complexity", "moderate").lower(),
        "routing_hint": _infer_hint(data.get("complexity", "")),
        "raw_content": content
    }
    
    return _apply_defaults(structured)

def _apply_defaults(data: Dict[str, Any]) -> Dict[str, Any]:
    """Apply LAC v4 defaults."""
    defaults = {
        "self_apply": True,
        "requires_paid_lane": False,
        "priority": "P2",
        "complexity": "moderate"
    }
    for k, v in defaults.items():
        if k not in data:
            data[k] = v
    return data

def _infer_hint(complexity: str) -> str:
    if "simple" in complexity.lower():
        return "dev_oss"
    if "complex" in complexity.lower():
        return "dev_gmxcli" # Fallback to GMX for complex unless paid requested
    return "dev_gmxcli"
