from __future__ import annotations

import builtins
import os
import shutil
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, Optional


class DryRunBlockedWrite(RuntimeError):
    """Raised when dry-run mode blocks a write outside the allowed root."""


def _is_truthy(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if value is None:
        return False
    return str(value).strip().lower() in {"1", "true", "yes", "y", "on"}


def _sanitize_wo_id(raw: Any) -> str:
    text = str(raw or "UNKNOWN").strip()
    if not text:
        return "UNKNOWN"
    text = text.replace(os.sep, "_")
    if os.altsep:
        text = text.replace(os.altsep, "_")
    return text


def _is_write_mode(mode: str) -> bool:
    return any(ch in mode for ch in ("w", "a", "x", "+"))


def _is_relative_to(path: Path, base: Path) -> bool:
    try:
        path.relative_to(base)
        return True
    except ValueError:
        return False


@dataclass
class DryRunCtx:
    enabled: bool
    lane: str
    wo_id: str
    repo_root: Path
    out_dir: Path
    _orig_env: Dict[str, Optional[str]] = field(default_factory=dict)
    _orig_funcs: Dict[str, Any] = field(default_factory=dict)

    def _resolve_write_path(self, raw_path: Any) -> Path:
        path = Path(raw_path).expanduser()
        if not path.is_absolute():
            path = self.out_dir / path
        try:
            resolved = path.resolve()
        except Exception:
            resolved = path.absolute()
        if not _is_relative_to(resolved, self.out_dir):
            raise DryRunBlockedWrite(f"dry_run_blocked_write: {resolved}")
        return resolved

    def assert_safe_path(self, raw_path: Any) -> Path:
        return self._resolve_write_path(raw_path)

    def open_for_write(self, raw_path: Any, mode: str = "w", *args: Any, **kwargs: Any):
        safe_path = self._resolve_write_path(raw_path)
        opener = self._orig_funcs.get("open", builtins.open)
        return opener(safe_path, mode, *args, **kwargs)

    def _install_guards(self) -> None:
        if self._orig_funcs:
            return

        self._orig_funcs["open"] = builtins.open
        self._orig_funcs["path_open"] = Path.open
        self._orig_funcs["os_rename"] = os.rename
        self._orig_funcs["os_replace"] = os.replace
        self._orig_funcs["os_remove"] = os.remove
        self._orig_funcs["os_unlink"] = os.unlink
        self._orig_funcs["os_rmdir"] = os.rmdir
        self._orig_funcs["os_mkdir"] = os.mkdir
        self._orig_funcs["os_makedirs"] = os.makedirs
        self._orig_funcs["shutil_move"] = shutil.move
        self._orig_funcs["shutil_copy"] = shutil.copy
        self._orig_funcs["shutil_copy2"] = shutil.copy2
        self._orig_funcs["shutil_copyfile"] = shutil.copyfile

        def guarded_open(file, mode="r", *args, **kwargs):
            if _is_write_mode(mode):
                safe_path = self._resolve_write_path(file)
                return self._orig_funcs["open"](safe_path, mode, *args, **kwargs)
            return self._orig_funcs["open"](file, mode, *args, **kwargs)

        def guarded_path_open(path_obj, mode="r", *args, **kwargs):
            if _is_write_mode(mode):
                safe_path = self._resolve_write_path(path_obj)
                return self._orig_funcs["path_open"](safe_path, mode, *args, **kwargs)
            return self._orig_funcs["path_open"](path_obj, mode, *args, **kwargs)

        def guarded_rename(src, dst):
            src_path = self._resolve_write_path(src)
            dst_path = self._resolve_write_path(dst)
            return self._orig_funcs["os_rename"](src_path, dst_path)

        def guarded_replace(src, dst):
            src_path = self._resolve_write_path(src)
            dst_path = self._resolve_write_path(dst)
            return self._orig_funcs["os_replace"](src_path, dst_path)

        def guarded_remove(path):
            safe_path = self._resolve_write_path(path)
            return self._orig_funcs["os_remove"](safe_path)

        def guarded_unlink(path):
            safe_path = self._resolve_write_path(path)
            return self._orig_funcs["os_unlink"](safe_path)

        def guarded_rmdir(path):
            safe_path = self._resolve_write_path(path)
            return self._orig_funcs["os_rmdir"](safe_path)

        def guarded_mkdir(path, mode=0o777):
            safe_path = self._resolve_write_path(path)
            return self._orig_funcs["os_mkdir"](safe_path, mode)

        def guarded_makedirs(name, mode=0o777, exist_ok=False):
            safe_path = self._resolve_write_path(name)
            return self._orig_funcs["os_makedirs"](safe_path, mode=mode, exist_ok=exist_ok)

        def guarded_move(src, dst, *args, **kwargs):
            src_path = self._resolve_write_path(src)
            dst_path = self._resolve_write_path(dst)
            return self._orig_funcs["shutil_move"](src_path, dst_path, *args, **kwargs)

        def guarded_copy(src, dst, *args, **kwargs):
            dst_path = self._resolve_write_path(dst)
            return self._orig_funcs["shutil_copy"](src, dst_path, *args, **kwargs)

        def guarded_copy2(src, dst, *args, **kwargs):
            dst_path = self._resolve_write_path(dst)
            return self._orig_funcs["shutil_copy2"](src, dst_path, *args, **kwargs)

        def guarded_copyfile(src, dst, *args, **kwargs):
            dst_path = self._resolve_write_path(dst)
            return self._orig_funcs["shutil_copyfile"](src, dst_path, *args, **kwargs)

        builtins.open = guarded_open
        Path.open = guarded_path_open
        os.rename = guarded_rename
        os.replace = guarded_replace
        os.remove = guarded_remove
        os.unlink = guarded_unlink
        os.rmdir = guarded_rmdir
        os.mkdir = guarded_mkdir
        os.makedirs = guarded_makedirs
        shutil.move = guarded_move
        shutil.copy = guarded_copy
        shutil.copy2 = guarded_copy2
        shutil.copyfile = guarded_copyfile

    def _restore_guards(self) -> None:
        if not self._orig_funcs:
            return
        builtins.open = self._orig_funcs["open"]
        Path.open = self._orig_funcs["path_open"]
        os.rename = self._orig_funcs["os_rename"]
        os.replace = self._orig_funcs["os_replace"]
        os.remove = self._orig_funcs["os_remove"]
        os.unlink = self._orig_funcs["os_unlink"]
        os.rmdir = self._orig_funcs["os_rmdir"]
        os.mkdir = self._orig_funcs["os_mkdir"]
        os.makedirs = self._orig_funcs["os_makedirs"]
        shutil.move = self._orig_funcs["shutil_move"]
        shutil.copy = self._orig_funcs["shutil_copy"]
        shutil.copy2 = self._orig_funcs["shutil_copy2"]
        shutil.copyfile = self._orig_funcs["shutil_copyfile"]
        self._orig_funcs.clear()

    def __enter__(self) -> "DryRunCtx":
        if not self.enabled:
            return self
        self.out_dir.mkdir(parents=True, exist_ok=True)
        self._orig_env = {
            "LUKA_DRY_RUN": os.environ.get("LUKA_DRY_RUN"),
            "LUKA_DRYRUN_ROOT": os.environ.get("LUKA_DRYRUN_ROOT"),
            "LAC_BASE_DIR": os.environ.get("LAC_BASE_DIR"),
        }
        os.environ["LUKA_DRY_RUN"] = "1"
        os.environ["LUKA_DRYRUN_ROOT"] = str(self.out_dir)
        os.environ["LAC_BASE_DIR"] = str(self.out_dir)
        self._install_guards()
        return self

    def __exit__(self, exc_type, exc, tb) -> bool:
        if not self.enabled:
            return False
        self._restore_guards()
        for key, value in self._orig_env.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value
        return False


def dry_run_context(wo: Dict[str, Any], lane: str) -> DryRunCtx:
    enabled = _is_truthy(wo.get("dry_run"))
    wo_id = _sanitize_wo_id(wo.get("wo_id") or wo.get("id") or "UNKNOWN")
    repo_root = Path(os.environ.get("LUKA_ROOT") or os.environ.get("LUKA_SOT") or Path.cwd()).resolve()
    out_root = Path("/tmp/02luka-dryrun").resolve()
    out_dir = out_root / wo_id
    return DryRunCtx(
        enabled=enabled,
        lane=lane,
        wo_id=wo_id,
        repo_root=repo_root,
        out_dir=out_dir,
    )


__all__ = ["DryRunBlockedWrite", "DryRunCtx", "dry_run_context"]
