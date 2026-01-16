"""Telemetry stubs for dev_oss workers."""
from typing import Any, Dict, Callable
from contextlib import contextmanager
import functools


def track_execution(func_or_task_id=None, lane=None, model_used=None):
    """
    Compatibility wrapper: supports both decorator and context manager usage.

    Usage 1 (decorator):
        @track_execution
        def my_func(): ...

    Usage 2 (context manager):
        with track_execution(task_id, lane, model_used) as tracker:
            tracker["status"] = "running"
    """
    # Detect usage pattern by checking arguments
    if lane is not None or model_used is not None:
        # Context manager usage: called with (task_id, lane, model_used)
        @contextmanager
        def _context_manager():
            # Yield a dict-like tracker that can be modified
            tracker = {
                "task_id": func_or_task_id,
                "lane": lane,
                "model_used": model_used,
                "status": "unknown"
            }
            yield tracker
            # Cleanup (no-op for now)
        return _context_manager()

    elif callable(func_or_task_id):
        # Decorator usage: called with function
        @functools.wraps(func_or_task_id)
        def wrapper(*args, **kwargs):
            return func_or_task_id(*args, **kwargs)
        return wrapper

    else:
        # Called with just task_id (single arg) - treat as context manager
        @contextmanager
        def _context_manager():
            tracker = {"task_id": func_or_task_id, "status": "unknown"}
            yield tracker
        return _context_manager()


def log_dev_execution(task: Dict[str, Any], result: Dict[str, Any]) -> None:
    """Stub: Log development execution. Currently does nothing."""
    pass


__all__ = ["track_execution", "log_dev_execution"]
