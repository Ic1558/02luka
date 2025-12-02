"""
QA v4 - Production-ready quality assurance for LAC v4.

Features:
- Real linting (ruff/flake8)
- Test execution (pytest)
- Pattern-based QA checks
- Security basics
- Checklist evaluation
- R&D Lane integration
- 3-Mode System (Basic/Enhanced/Full)
"""

from agents.qa_v4.checklist_engine import evaluate_checklist
from agents.qa_v4.actions import QaActions
from agents.qa_v4.rnd_integration import send_to_rnd, analyze_failure_trends

# Backward compatibility: QAWorkerV4 = QAWorkerBasic
from agents.qa_v4.workers.basic import QAWorkerBasic

# Alias for backward compatibility
QAWorkerV4 = QAWorkerBasic

__all__ = [
    "QAWorkerV4",  # Backward compatibility (points to Basic)
    "QAWorkerBasic",  # Explicit Basic mode
    "evaluate_checklist",
    "QaActions",
    "send_to_rnd",
    "analyze_failure_trends",
]
