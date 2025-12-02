
import subprocess
import re
from pathlib import Path
from typing import List, Dict, Any

class QaActions:
    """
    Encapsulates QA actions for testability and mocking.
    """
    def run_command(self, cmd: List[str]) -> Dict[str, Any]:
        """Run a shell command and return output."""
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            return {
                "success": result.returncode == 0,
                "stdout": result.stdout,
                "stderr": result.stderr,
                "exit_code": result.returncode
            }
        except Exception as e:
            return {
                "success": False,
                "stdout": "",
                "stderr": str(e),
                "exit_code": -1
            }

    def run_ruff(self, file_path: str) -> Dict[str, Any]:
        """Run ruff linting on a file."""
        cmd = ["ruff", "check", file_path]
        return self.run_command(cmd)

    def run_flake8(self, file_path: str) -> Dict[str, Any]:
        """Run flake8 linting on a file."""
        cmd = ["flake8", file_path]
        return self.run_command(cmd)

    def run_pytest(self, file_path: str) -> Dict[str, Any]:
        """Run pytest on a file."""
        cmd = ["pytest", file_path]
        res = self.run_command(cmd)
        if res["exit_code"] == 5:
            res["success"] = True
            res["stdout"] += "\n(No tests collected - treated as success)"
        return res

    def check_security_basics(self, file_path: str) -> List[str]:
        """Check for basic security issues via regex."""
        issues = []
        patterns = [
            (r"sk-[a-zA-Z0-9]{20,}", "Potential API Key found"),
            (r"password\s*=\s*['\"][^'\"]+['\"]", "Hardcoded password found"),
            (r"eval\(", "Use of eval() detected"),
            (r"exec\(", "Use of exec() detected"),
            (r"os\.system\(", "Use of os.system() detected"),
            (r"subprocess\.call\(.*shell=True", "subprocess with shell=True detected"),
        ]
        
        try:
            content = Path(file_path).read_text()
            for pat, msg in patterns:
                if re.search(pat, content):
                    issues.append(msg)
        except Exception:
            pass 
        return issues

    def run_pattern_check(self, files: List[str], patterns: List[str]) -> Dict[str, Any]:
        """Check files against forbidden regex patterns."""
        issues = []
        for f in files:
            try:
                content = Path(f).read_text()
                for pat in patterns:
                    if re.search(pat, content):
                        issues.append(f"Pattern violation in {f}: {pat}")
            except Exception:
                pass
        
        if issues:
            return {"status": "failed", "issues": issues}
        return {"status": "success"}
