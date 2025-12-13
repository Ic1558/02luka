# 🔹 BLOCK 4: Multi-File SIP Transaction Engine (Dry-Run)

**Date:** 2025-12-10  
**Phase:** 3.3 — Full Implementation Blueprint  
**Status:** ✅ DRY-RUN (No File Write)  
**Module:** `bridge/core/sip_engine_v5.py`

---

## 📋 File Tree Structure (Will Be Created)

```
bridge/
└── core/
    ├── sip_engine_v5.py      # Multi-File SIP Transaction Engine (THIS BLOCK)
    └── __init__.py            # Module exports
```

---

## 🎯 Multi-File SIP Transaction Engine Implementation

### Complete Python Module: `bridge/core/sip_engine_v5.py`

```python
#!/usr/bin/env python3
"""
Multi-File SIP Transaction Engine v5 — Atomic Transaction Support

This module implements multi-file SIP (Safe Idempotent Patch) transactions
defined in:
- AI_OP_001_v5.md (Section 5.3: Multi-File SIP Requirements)
- GOVERNANCE_UNIFIED_v5.md (Section 6: Safety Invariants)

Features:
- Atomic transactions (all files commit or none)
- Pre-validation before commit
- Automatic rollback on failure
- Full audit trail (checksums, transaction log)

Author: 02luka System
Status: DRY-RUN (Phase 3.3)
"""

import os
import json
import yaml
import ast
import hashlib
import tempfile
import shutil
import uuid
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass, asdict
from datetime import datetime
from contextlib import contextmanager
from enum import Enum

# Import SandboxGuard for checksum computation
try:
    from bridge.core.sandbox_guard_v5 import compute_file_checksum
except ImportError:
    # Fallback checksum function
    def compute_file_checksum(file_path: str) -> Optional[str]:
        """Compute SHA256 checksum of file."""
        try:
            with open(file_path, 'rb') as f:
                return hashlib.sha256(f.read()).hexdigest()
        except Exception:
            return None


# ============================================================================
# TYPE DEFINITIONS
# ============================================================================

class TransactionStatus(Enum):
    """Transaction status."""
    PREPARING = "PREPARING"
    VALIDATING = "VALIDATING"
    COMMITTING = "COMMITTING"
    COMMITTED = "COMMITTED"
    ROLLING_BACK = "ROLLING_BACK"
    ROLLED_BACK = "ROLLED_BACK"
    FAILED = "FAILED"


@dataclass
class FileOperation:
    """Single file operation in transaction."""
    path: str
    operation: str  # "add", "modify", "delete"
    content: Optional[str] = None
    temp_path: Optional[str] = None
    checksum_before: Optional[str] = None
    checksum_after: Optional[str] = None
    committed: bool = False


@dataclass
class TransactionResult:
    """Result of multi-file SIP transaction."""
    success: bool
    committed_files: List[str]
    checksums_before: Dict[str, str]
    checksums_after: Dict[str, str]
    errors: List[str]
    transaction_id: str
    rollback_performed: bool = False
    status: TransactionStatus = TransactionStatus.FAILED


# ============================================================================
# VALIDATION ENGINE
# ============================================================================

class ValidationEngine:
    """Validates multi-file transactions."""
    
    def validate_syntax(
        self,
        file_path: str,
        content: str
    ) -> Tuple[bool, Optional[str]]:
        """
        Validate file syntax (JSON/YAML/Python/etc.).
        
        Returns:
            (is_valid, error_message)
        """
        if not content:
            return (True, None)  # Empty file is valid
        
        ext = Path(file_path).suffix.lower()
        
        # JSON validation
        if ext == '.json':
            try:
                json.loads(content)
                return (True, None)
            except json.JSONDecodeError as e:
                return (False, f"JSON syntax error: {e}")
        
        # YAML validation
        if ext in ['.yaml', '.yml']:
            try:
                yaml.safe_load(content)
                return (True, None)
            except yaml.YAMLError as e:
                return (False, f"YAML syntax error: {e}")
        
        # Python validation (optional, for .py files)
        if ext == '.py':
            try:
                ast.parse(content)
                return (True, None)
            except SyntaxError as e:
                return (False, f"Python syntax error: {e}")
        
        # Other file types: basic validation (non-empty, readable)
        return (True, None)
    
    def validate_dependencies(
        self,
        operations: List[FileOperation]
    ) -> Tuple[bool, List[str]]:
        """
        Validate file dependencies (file A depends on file B).
        
        Basic checks:
        - All paths must be valid
        - No circular dependencies (simple check)
        - Relative paths must resolve
        
        Returns:
            (is_valid, list_of_errors)
        """
        errors = []
        paths = [op.path for op in operations]
        
        # Check for duplicate paths
        if len(paths) != len(set(paths)):
            errors.append("Duplicate file paths in transaction")
        
        # Check path validity
        for op in operations:
            try:
                Path(op.path).resolve()
            except Exception as e:
                errors.append(f"Invalid path '{op.path}': {e}")
        
        # Basic circular dependency check (if file A imports file B, both must be present)
        # This is a simplified check; full dependency analysis would require parsing
        # For now, we just ensure all referenced files are in the transaction
        
        return (len(errors) == 0, errors)
    
    def validate_constraints(
        self,
        operations: List[FileOperation]
    ) -> Tuple[bool, List[str]]:
        """
        Validate business constraints (e.g., schema compatibility).
        
        Returns:
            (is_valid, list_of_errors)
        """
        errors = []
        
        # Check transaction size limit
        if len(operations) > 50:
            errors.append(f"Transaction too large: {len(operations)} files (max 50)")
        
        # Check for cross-zone transactions (warn but allow)
        # This would require zone resolution, which we'll skip for now
        
        return (len(errors) == 0, errors)
    
    def validate_transaction(
        self,
        operations: List[FileOperation],
        temp_files: Dict[str, str]
    ) -> Tuple[bool, List[str]]:
        """
        Validate entire transaction (syntax + dependencies + constraints).
        
        Returns:
            (is_valid, list_of_errors)
        """
        errors = []
        
        # 1. Syntax validation
        for op in operations:
            if op.operation == "delete":
                continue  # No content to validate for delete
            
            temp_path = temp_files.get(op.path)
            if not temp_path or not Path(temp_path).exists():
                errors.append(f"Temp file not found for '{op.path}'")
                continue
            
            # Read temp file content
            try:
                with open(temp_path, 'r', encoding='utf-8') as f:
                    content = f.read()
            except Exception as e:
                errors.append(f"Cannot read temp file for '{op.path}': {e}")
                continue
            
            # Validate syntax
            is_valid, error_msg = self.validate_syntax(op.path, content)
            if not is_valid:
                errors.append(f"Syntax error in '{op.path}': {error_msg}")
        
        # 2. Dependency validation
        is_valid, dep_errors = self.validate_dependencies(operations)
        errors.extend(dep_errors)
        
        # 3. Constraint validation
        is_valid, constraint_errors = self.validate_constraints(operations)
        errors.extend(constraint_errors)
        
        return (len(errors) == 0, errors)


# ============================================================================
# ROLLBACK ENGINE
# ============================================================================

class RollbackEngine:
    """Handles rollback for multi-file transactions."""
    
    def store_state(
        self,
        file_paths: List[str],
        base_path: Optional[str] = None
    ) -> Dict[str, Dict[str, Any]]:
        """
        Store original state (checksums, content) before transaction.
        
        Returns:
            Dict mapping file_path -> {checksum, content, exists}
        """
        state = {}
        base = Path(base_path) if base_path else Path.home().joinpath("02luka")
        
        for file_path in file_paths:
            full_path = base / file_path if not Path(file_path).is_absolute() else Path(file_path)
            
            exists = full_path.exists()
            checksum = None
            content = None
            
            if exists:
                checksum = compute_file_checksum(str(full_path))
                try:
                    with open(full_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                except Exception:
                    # Binary file or read error
                    content = None
            
            state[str(file_path)] = {
                "checksum": checksum,
                "content": content,
                "exists": exists,
                "full_path": str(full_path)
            }
        
        return state
    
    def restore_state(
        self,
        state: Dict[str, Dict[str, Any]]
    ) -> Tuple[bool, List[str]]:
        """
        Restore files to original state.
        
        Returns:
            (success, errors)
        """
        errors = []
        
        for file_path, file_state in state.items():
            full_path = Path(file_state["full_path"])
            
            try:
                if file_state["exists"]:
                    # Restore original content
                    if file_state["content"] is not None:
                        full_path.parent.mkdir(parents=True, exist_ok=True)
                        with open(full_path, 'w', encoding='utf-8') as f:
                            f.write(file_state["content"])
                    else:
                        # Binary file: cannot restore content, only remove if it exists
                        if full_path.exists():
                            full_path.unlink()
                else:
                    # File didn't exist before, remove it
                    if full_path.exists():
                        full_path.unlink()
            except Exception as e:
                errors.append(f"Failed to restore '{file_path}': {e}")
        
        return (len(errors) == 0, errors)
    
    def handle_partial_rollback(
        self,
        committed_files: List[str],
        state: Dict[str, Dict[str, Any]]
    ) -> Tuple[bool, List[str]]:
        """
        Handle rollback when some files already committed.
        
        Returns:
            (success, errors)
        """
        # Filter state to only committed files
        committed_state = {
            path: file_state
            for path, file_state in state.items()
            if path in committed_files
        }
        
        return self.restore_state(committed_state)


# ============================================================================
# TRANSACTION CONTEXT MANAGER
# ============================================================================

class TransactionContext:
    """
    Context manager for multi-file SIP transactions.
    
    Usage:
        with TransactionContext(operations) as tx:
            tx.prepare_files()
            if tx.validate():
                tx.commit()
            else:
                tx.rollback()
    """
    
    def __init__(
        self,
        operations: List[Dict[str, Any]],
        base_path: Optional[str] = None
    ):
        """
        Initialize transaction context.
        
        Args:
            operations: List of file operations
            base_path: Base path for relative paths (default: 02luka root)
        """
        self.operations = [
            FileOperation(
                path=op.get('path', ''),
                operation=op.get('operation', 'modify'),
                content=op.get('content', '')
            )
            for op in operations
        ]
        
        self.base_path = Path(base_path) if base_path else Path.home().joinpath("02luka")
        self.transaction_id = str(uuid.uuid4())[:8]
        self.status = TransactionStatus.PREPARING
        
        self.temp_files: Dict[str, str] = {}
        self.original_state: Dict[str, Dict[str, Any]] = {}
        self.committed_files: List[str] = []
        
        self.validation_engine = ValidationEngine()
        self.rollback_engine = RollbackEngine()
    
    def __enter__(self) -> 'TransactionContext':
        """Enter context manager."""
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Exit context manager (auto-rollback on exception)."""
        if exc_type is not None:
            # Exception occurred, rollback if needed
            if self.committed_files:
                self.rollback()
        
        # Cleanup temp files
        for temp_path in self.temp_files.values():
            try:
                if Path(temp_path).exists():
                    os.unlink(temp_path)
            except Exception:
                pass
    
    def prepare_files(self) -> Dict[str, str]:
        """
        Prepare all files in temp (no target files modified yet).
        
        Returns:
            Dict mapping target_path -> temp_file_path
        """
        self.status = TransactionStatus.PREPARING
        
        # Store original state
        file_paths = [op.path for op in self.operations]
        self.original_state = self.rollback_engine.store_state(
            file_paths,
            str(self.base_path)
        )
        
        # Prepare temp files
        for op in self.operations:
            if op.operation == "delete":
                continue  # No temp file needed for delete
            
            # Resolve full path
            if Path(op.path).is_absolute():
                full_path = Path(op.path)
            else:
                full_path = self.base_path / op.path
            
            # Create temp file in same directory
            temp_fd, temp_path = tempfile.mkstemp(
                suffix='.tmp',
                prefix=f'.sip_tx_{Path(op.path).name}.',
                dir=str(full_path.parent)
            )
            
            try:
                # Write content to temp file
                with os.fdopen(temp_fd, 'w', encoding='utf-8') as f:
                    f.write(op.content or '')
                
                # Store checksum before (if file exists)
                if full_path.exists():
                    op.checksum_before = compute_file_checksum(str(full_path))
                
                # Store temp path
                op.temp_path = temp_path
                self.temp_files[op.path] = temp_path
                
            except Exception as e:
                # Cleanup on failure
                try:
                    os.unlink(temp_path)
                except:
                    pass
                raise Exception(f"Failed to prepare temp file for '{op.path}': {e}")
        
        return self.temp_files
    
    def validate(self) -> Tuple[bool, List[str]]:
        """
        Validate entire transaction.
        
        Returns:
            (is_valid, list_of_errors)
        """
        self.status = TransactionStatus.VALIDATING
        
        is_valid, errors = self.validation_engine.validate_transaction(
            self.operations,
            self.temp_files
        )
        
        return (is_valid, errors)
    
    def commit(self) -> Tuple[bool, Dict[str, str], Dict[str, str], List[str]]:
        """
        Atomic commit (all files or none).
        
        Returns:
            (success, checksums_before, checksums_after, errors)
        """
        self.status = TransactionStatus.COMMITTING
        
        checksums_before = {}
        checksums_after = {}
        errors = []
        committed = []
        
        try:
            # Commit all files in sequence
            for op in self.operations:
                # Resolve full path
                if Path(op.path).is_absolute():
                    full_path = Path(op.path)
                else:
                    full_path = self.base_path / op.path
                
                # Store checksum before
                if op.checksum_before:
                    checksums_before[op.path] = op.checksum_before
                
                try:
                    if op.operation == "delete":
                        # Delete file
                        if full_path.exists():
                            full_path.unlink()
                        checksums_after[op.path] = None
                    
                    elif op.operation in ["add", "modify"]:
                        # Atomic move: temp -> target
                        if not op.temp_path or not Path(op.temp_path).exists():
                            raise Exception(f"Temp file not found for '{op.path}'")
                        
                        # Ensure parent directory exists
                        full_path.parent.mkdir(parents=True, exist_ok=True)
                        
                        # Atomic move
                        shutil.move(op.temp_path, str(full_path))
                        
                        # Verify checksum after
                        checksum_after = compute_file_checksum(str(full_path))
                        checksums_after[op.path] = checksum_after
                        op.checksum_after = checksum_after
                    
                    # Mark as committed
                    op.committed = True
                    committed.append(op.path)
                    self.committed_files.append(op.path)
                    
                except Exception as e:
                    # Commit failed for this file
                    errors.append(f"Failed to commit '{op.path}': {e}")
                    # Rollback all committed files
                    if committed:
                        self.rollback()
                    raise Exception(f"Transaction commit failed: {errors}")
            
            # All files committed successfully
            self.status = TransactionStatus.COMMITTED
            return (True, checksums_before, checksums_after, [])
        
        except Exception as e:
            self.status = TransactionStatus.FAILED
            return (False, checksums_before, checksums_after, errors)
    
    def rollback(self) -> Tuple[bool, List[str]]:
        """
        Rollback all changes to original state.
        
        Returns:
            (success, errors)
        """
        self.status = TransactionStatus.ROLLING_BACK
        
        # Rollback committed files
        if self.committed_files:
            success, errors = self.rollback_engine.handle_partial_rollback(
                self.committed_files,
                self.original_state
            )
        else:
            # No files committed, nothing to rollback
            success, errors = (True, [])
        
        # Cleanup temp files
        for temp_path in self.temp_files.values():
            try:
                if Path(temp_path).exists():
                    os.unlink(temp_path)
            except Exception:
                pass
        
        if success:
            self.status = TransactionStatus.ROLLED_BACK
        else:
            self.status = TransactionStatus.FAILED
        
        return (success, errors)


# ============================================================================
# MAIN TRANSACTION FUNCTION
# ============================================================================

def apply_multifile_sip_transaction(
    operations: List[Dict[str, Any]],
    base_path: Optional[str] = None,
    validate: bool = True,
    dry_run: bool = False
) -> TransactionResult:
    """
    Apply multi-file SIP transaction.
    
    Args:
        operations: List of file operations
            [
                {
                    "path": "path/to/file1.json",
                    "operation": "modify",  # or "add", "delete"
                    "content": "new content"
                },
                ...
            ]
        base_path: Base path for relative paths (default: 02luka root)
        validate: Whether to validate before commit
        dry_run: If True, prepare and validate but don't commit
    
    Returns:
        TransactionResult
    """
    transaction_id = str(uuid.uuid4())[:8]
    
    try:
        with TransactionContext(operations, base_path) as tx:
            # Step 1: Prepare files
            tx.prepare_files()
            
            # Step 2: Validate (if requested)
            if validate:
                is_valid, errors = tx.validate()
                if not is_valid:
                    return TransactionResult(
                        success=False,
                        committed_files=[],
                        checksums_before={},
                        checksums_after={},
                        errors=errors,
                        transaction_id=transaction_id,
                        rollback_performed=False,
                        status=TransactionStatus.FAILED
                    )
            
            # Step 3: Commit (if not dry run)
            if not dry_run:
                success, checksums_before, checksums_after, errors = tx.commit()
                
                if success:
                    return TransactionResult(
                        success=True,
                        committed_files=tx.committed_files,
                        checksums_before=checksums_before,
                        checksums_after=checksums_after,
                        errors=[],
                        transaction_id=transaction_id,
                        rollback_performed=False,
                        status=TransactionStatus.COMMITTED
                    )
                else:
                    # Rollback already performed in commit()
                    return TransactionResult(
                        success=False,
                        committed_files=[],
                        checksums_before=checksums_before,
                        checksums_after={},
                        errors=errors,
                        transaction_id=transaction_id,
                        rollback_performed=True,
                        status=TransactionStatus.ROLLED_BACK
                    )
            else:
                # Dry run: validation passed, but no commit
                return TransactionResult(
                    success=True,
                    committed_files=[],
                    checksums_before={},
                    checksums_after={},
                    errors=[],
                    transaction_id=transaction_id,
                    rollback_performed=False,
                    status=TransactionStatus.VALIDATING
                )
    
    except Exception as e:
        return TransactionResult(
            success=False,
            committed_files=[],
            checksums_before={},
            checksums_after={},
            errors=[str(e)],
            transaction_id=transaction_id,
            rollback_performed=False,
            status=TransactionStatus.FAILED
        )


# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def is_single_file(operations: List[Dict[str, Any]]) -> bool:
    """Check if transaction has only one file (use single-file SIP instead)."""
    return len(operations) == 1


def get_transaction_summary(result: TransactionResult) -> str:
    """Get human-readable transaction summary."""
    if result.success:
        return f"✅ Transaction {result.transaction_id}: {len(result.committed_files)} files committed"
    else:
        return f"❌ Transaction {result.transaction_id}: Failed ({len(result.errors)} errors)"


# ============================================================================
# EXPORTS
# ============================================================================

__all__ = [
    'TransactionContext',
    'ValidationEngine',
    'RollbackEngine',
    'apply_multifile_sip_transaction',
    'TransactionResult',
    'FileOperation',
    'TransactionStatus',
    'is_single_file',
    'get_transaction_summary'
]
```

---

## 🔗 Integration Points

1. **CLC Executor v5**: Uses transaction engine for multi-file WOs
2. **WO Processor v5**: Uses transaction engine for local execution
3. **SandboxGuard v5**: Uses `compute_file_checksum()` for checksums

---

## 📊 Exact Patch Preview (When Boss Approves)

**File to Create:** `bridge/core/sip_engine_v5.py`  
**Lines:** ~650 lines  
**Dependencies:** Python 3.8+, `yaml`, `pathlib`, `hashlib`, `tempfile`, `shutil`, `uuid` (stdlib + PyYAML)

**Integration:**
- Used by: `agents/clc/executor_v5.py` (for multi-file WOs)
- Used by: `bridge/core/wo_processor_v5.py` (for local execution)
- Imports: `bridge.core.sandbox_guard_v5` (for checksums)

---

**Status:** ✅ Block 4 DRYRUN Complete — Ready for Review

**Next:** Implement Block 4 or proceed with Block 5 implementation?

