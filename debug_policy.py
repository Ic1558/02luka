import sys
import os
sys.path.append(os.getcwd())
from agents.clc_local.policy import check_file_allowed

path = "g/src/antigravity/core/hello.py"
allowed, reason = check_file_allowed(path)
print(f"Path: {path}")
print(f"Allowed: {allowed}")
print(f"Reason: {reason}")

path_abs = os.path.abspath(path)
allowed_abs, reason_abs = check_file_allowed(path_abs)
print(f"Path (Abs): {path_abs}")
print(f"Allowed (Abs): {allowed_abs}")
print(f"Reason (Abs): {reason_abs}")
