#!/usr/bin/env python3
"""
GG Command Router for CLC Export Mode Control
Handles Telegram/Kim commands and translates to Redis messages
"""
import os
import json
import redis
import subprocess
import sys
from pathlib import Path

# Configuration
REDIS_URL = os.getenv('REDIS_URL', 'redis://localhost:6379')
CHAN = "gg:clc:export_mode"
STATE_FILE = os.getenv('CLC_STATE_FILE', '/workspaces/02luka-repo/g/state/clc_export_mode.env')

def get_redis_connection():
    """Get Redis connection with error handling"""
    try:
        r = redis.from_url(REDIS_URL, decode_responses=True)
        r.ping()  # Test connection
        return r
    except Exception as e:
        print(f"Redis connection failed: {e}")
        return None

def read_clc_state():
    """Read current CLC export mode state"""
    if not os.path.exists(STATE_FILE):
        return "State file not found"
    
    try:
        with open(STATE_FILE, 'r') as f:
            content = f.read().strip()
        return content
    except Exception as e:
        return f"Error reading state: {e}"

def send_telegram_message(message):
    """Send message via telegram-send (if available)"""
    try:
        subprocess.run(['telegram-send', message], check=True, capture_output=True)
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        print(f"Telegram message: {message}")
        return False

def handle_clc_command(text, chat_id=None):
    """Handle CLC export mode commands"""
    text = text.strip().lower()
    r = get_redis_connection()
    
    if not r:
        send_telegram_message("❌ Redis connection failed")
        return
    
    payload = None
    response = ""
    
    # Command mapping
    if text in ["/clc mode off", "clc off", "ปิด export", "หยุดส่งออก", "/clc off"]:
        payload = {"mode": "off"}
        response = "✅ CLC mode set: off (fastest - no exports)"
        
    elif text in ["/clc mode drive", "clc drive", "เปิด export", "/clc drive"]:
        payload = {"mode": "drive"}
        response = "✅ CLC mode set: drive (non-blocking Drive exports)"
        
    elif text.startswith("/clc mode local") or text.startswith("clc local") or text.startswith("ส่งออกโลคัล"):
        parts = text.split(" ", 3)
        if len(parts) > 3:
            custom_dir = parts[-1]
            payload = {"mode": "local", "dir": custom_dir}
            response = f"✅ CLC mode set: local (custom dir: {custom_dir})"
        else:
            payload = {"mode": "local"}
            response = "✅ CLC mode set: local (default directory)"
            
    elif text in ["/clc mode status", "สถานะ clc", "/clc status", "clc status"]:
        state = read_clc_state()
        response = f"📦 CLC Export Mode Status:\n```\n{state}\n```"
        send_telegram_message(response)
        return
        
    elif text in ["/clc help", "clc help", "ช่วย clc"]:
        help_text = """
🤖 CLC Export Mode Commands:

• `/clc mode off` - Turn off exports (fastest)
• `/clc mode local` - Export locally (no Drive sync)
• `/clc mode local /path` - Local export to custom directory
• `/clc mode drive` - Resume Drive export (non-blocking)
• `/clc mode status` - Check current mode
• `/clc help` - Show this help

Examples:
• `/clc off` - Quick off
• `/clc drive` - Quick drive mode
• `/clc status` - Check status
        """
        send_telegram_message(help_text)
        return
    
    # Send Redis message if payload exists
    if payload:
        try:
            r.publish(CHAN, json.dumps(payload))
            send_telegram_message(response)
            print(f"Published to {CHAN}: {payload}")
        except Exception as e:
            error_msg = f"❌ Failed to send command: {e}"
            send_telegram_message(error_msg)
            print(error_msg)
    else:
        send_telegram_message("❓ Unknown command. Use `/clc help` for available commands.")

def main():
    """Main function for command line usage"""
    if len(sys.argv) < 2:
        print("Usage: python3 gg_command_router.py '<command>'")
        print("Example: python3 gg_command_router.py '/clc mode off'")
        sys.exit(1)
    
    command = sys.argv[1]
    handle_clc_command(command)

if __name__ == "__main__":
    main()
