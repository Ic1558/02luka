import json, subprocess, time, os, sys
from pathlib import Path
from datetime import datetime

SOT = Path(os.environ.get("LUKA_SOT", str(Path.home()/"02luka")))
MEM_TOOL = SOT / "tools" / "memory_sync.sh"
OUTBOX = SOT / "bridge" / "memory" / "outbox"

def _run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True, check=True).stdout

def get_context_for_gpt():
    """Get shared context formatted for GPT system message"""
    out = _run([str(MEM_TOOL), "get"])
    context = json.loads(out)
    
    # Format as system message
    agents_status = json.dumps(context.get('agents', {}), indent=2)
    current_work = json.dumps(context.get('current_work', {}), indent=2)
    
    return f"""You are part of 02luka system. Current agents status:
{agents_status}

Current work: {current_work}

Maintain consistency with other agents."""

def save_gpt_response(response):
    """Save GPT response to shared memory"""
    try:
        _run([str(MEM_TOOL), "update", "gg", "active"])
    except Exception as e:
        print(f"WARN: memory_sync failed: {e}", file=sys.stderr)
    
    # Handle different response types
    if isinstance(response, dict):
        response_str = json.dumps(response)
    elif isinstance(response, str):
        response_str = response
    else:
        response_str = str(response)
    
    # Save to bridge
    output = {
        'agent': 'gg',
        'response': response_str[:500],
        'response_full': response_str,
        'timestamp': datetime.now().isoformat()
    }
    
    OUTBOX.mkdir(parents=True, exist_ok=True)
    ts = int(time.time() * 1000)
    (OUTBOX / f'gg_{ts}.json').write_text(json.dumps(output, indent=2))

if __name__ == "__main__":
    # Smoke test
    ctx = get_context_for_gpt()
    print(ctx[:200])
    save_gpt_response("Test response from GPT bridge")
    print("gpt_memory: ok")
