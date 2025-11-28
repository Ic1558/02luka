from __future__ import annotations

import time
from typing import Callable, Dict, List


class Task:
    def __init__(self, name: str, func: Callable[[], Dict[str, object]]):
        self.name = name
        self.func = func


class Scheduler:
    """Lightweight task scheduler stub for background jobs."""

    def __init__(self):
        self.tasks: List[Task] = []

    def register(self, name: str, func: Callable[[], Dict[str, object]]) -> None:
        self.tasks.append(Task(name, func))

    def run_all(self) -> List[Dict[str, object]]:
        results: List[Dict[str, object]] = []
        for task in self.tasks:
            start = time.time()
            try:
                result = task.func()
                result["task"] = task.name
                result["status"] = result.get("status", "success")
            except Exception as exc:
                result = {"task": task.name, "status": "error", "reason": str(exc)}
            result["duration_sec"] = round(time.time() - start, 3)
            results.append(result)
        return results


__all__ = ["Scheduler", "Task"]
