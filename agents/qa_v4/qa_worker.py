"""Compatibility shim for legacy QAWorkerV4 imports."""

from agents.qa_v4.workers.basic import QAWorkerBasic

QAWorkerV4 = QAWorkerBasic

__all__ = ["QAWorkerV4", "QAWorkerBasic"]
