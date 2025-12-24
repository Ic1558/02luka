#!/usr/bin/env python3
"""
CLC Enforcement Engine v5 — Background World Executor

This module implements the strict Background World executor defined in:
- AI_OP_001_v5.md (Section 4: Work Order Protocol, Section 5: SIP)
- GOVERNANCE_UNIFIED_v5.md (Section 4.2.2: Background World Capabilities)
- PERSONA_MODEL_v5.md (Section 2.3: Background Execution Layer)

CLC is the PRIMARY Background Executor that:
- Processes Work Orders (WO) from bridge/inbox/CLC/
- Enforces STRICT lane semantics
- Applies SIP (Safe Idempotent Patch) for all writes
- Provides full audit trail
- Supports rollback strategies

Author: 02luka System
Status: Implementation (Phase 3.3)
"""

import os
import json
import yaml
import hashlib
import tempfile
import shutil
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass, asdict
from datetime import datetime
from enum import Enum

# Import Router v5 and SandboxGuard v5
try:
    from bridge.core.router_v5 import route, resolve_zone, resolve_world
    from bridge.core.sandbox_guard_v5 import check_write_allowed, compute_file_checksum
except ImportError:
    # Fallback for standalone testing
    def route(trigger, actor, path, op="write", context=None):
        return type('obj', (object,), {
            'zone': 'OPEN',
            'lane': 'STRICT',
            'primary_writer': 'CLC',
            'lawset': [],
            'reason': 'Fallback routing'
        })()
    
    def resolve_zone(path: str) -> str:
        if any(p in path for p in ["/System/", "/usr/", "/etc/"]):
            return "DANGER"
        if any(p in path for p in ["core/", "bridge/core/"]):
            return "LOCKED"
        return "OPEN"
    
    def resolve_world(trigger: str, context=None) -> str:
        return "BACKGROUND"
    
    def check_write_allowed(path, actor, operation="write", content=None, context=None):
        return type('obj', (object,), {
            'allowed': True,
            'zone': resolve_zone(path),
            'normalized_path': Path(path),
            'warnings': []
        })()
    
    def compute_file_checksum(path: str) -> str:
        with open(path, 'rb') as f:
            return hashlib.sha256(f.read()).hexdigest()


# ============================================================================
# TYPE DEFINITIONS
# ============================================================================

class WOStatus(Enum):
    """Work Order status."""
    PENDING = "PENDING"
    VALIDATING = "VALIDATING"
    EXECUTING = "EXECUTING"
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"
    ROLLED_BACK = "ROLLED_BACK"


class ChangeType(Enum):
    """Change type in Work Order."""
    ADD = "ADD"
    MODIFY = "MODIFY"
    DELETE = "DELETE"
    MOVE = "MOVE"
    MIXED = "MIXED"


class RiskLevel(Enum):
    """Risk level in Work Order."""
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"


@dataclass
class FileOperation:
    """Single file operation in a Work Order."""
    path: str
    operation: str  # "add", "modify", "delete", "move"
    content: Optional[str] = None  # New content (for add/modify)
    source_path: Optional[str] = None  # Source (for move)
    checksum_before: Optional[str] = None
    checksum_after: Optional[str] = None
    temp_file: Optional[str] = None
    zone: Optional[str] = None
    validated: bool = False


@dataclass
class WorkOrder:
    """Work Order structure (AI_OP_001_v5 Section 4.2)."""
    wo_id: str
    created_at: str
    origin: Dict[str, str]  # {world, actor}
    target_paths: List[str]
    zone_summary: Dict[str, str]  # path -> zone
    risk_level: str
    desired_state: str
    change_type: str
    rollback_strategy: Optional[str]
    approver: Optional[str]
    constraints: Optional[List[str]]
    operations: Optional[List[Dict]] = None  # Detailed operations
    status: str = "PENDING"
    execution_log: List[str] = None
    errors: List[str] = None
    
    def __post_init__(self):
        if self.execution_log is None:
            self.execution_log = []
        if self.errors is None:
            self.errors = []


@dataclass
class ExecutionResult:
    """Result of WO execution."""
    wo_id: str
    status: WOStatus
    files_modified: List[str]
    checksums: Dict[str, Tuple[str, str]]  # path -> (before, after)
    execution_time: float
    errors: List[str]
    warnings: List[str]
    rollback_applied: bool = False
    audit_log_path: Optional[str] = None


# ============================================================================
# WORK ORDER READER/VALIDATOR
# ============================================================================

def read_work_order(wo_path: str) -> WorkOrder:
    """
    Read Work Order from file (YAML or JSON).
    
    Args:
        wo_path: Path to WO file
    
    Returns:
        WorkOrder object
    """
    path = Path(wo_path)
    
    if not path.exists():
        raise FileNotFoundError(f"Work Order not found: {wo_path}")
    
    with open(path, 'r', encoding='utf-8') as f:
        if path.suffix in ['.yaml', '.yml']:
            data = yaml.safe_load(f)
        else:
            data = json.load(f)
    
    # Validate minimal fields (AI_OP_001_v5 Section 4.2)
    required_fields = [
        'wo_id', 'created_at', 'origin', 'target_paths',
        'risk_level', 'desired_state', 'change_type'
    ]
    
    for field in required_fields:
        if field not in data:
            raise ValueError(f"Work Order missing required field: {field}")
    
    # Build WorkOrder object
    wo = WorkOrder(
        wo_id=data['wo_id'],
        created_at=data['created_at'],
        origin=data['origin'],
        target_paths=data['target_paths'],
        zone_summary=data.get('zone_summary', {}),
        risk_level=data['risk_level'],
        desired_state=data['desired_state'],
        change_type=data['change_type'],
        rollback_strategy=data.get('rollback_strategy'),
        approver=data.get('approver'),
        constraints=data.get('constraints', []),
        operations=data.get('operations', []),
        status=data.get('status', 'PENDING')
    )
    
    return wo


def validate_work_order(wo: WorkOrder) -> Tuple[bool, List[str]]:
    """
    Validate Work Order before execution.
    
    Checks:
    1. Origin world must be BACKGROUND
    2. All target paths must be valid
    3. Zone summary must match resolved zones
    4. Risk level must be valid
    5. Rollback strategy must be provided for HIGH/CRITICAL risk
    
    Returns:
        (is_valid, list_of_errors)
    """
    errors = []
    
    # Check origin world
    if wo.origin.get('world') != 'BACKGROUND':
        errors.append(f"Work Order origin world must be BACKGROUND, got: {wo.origin.get('world')}")
    
    # Validate target paths
    for path in wo.target_paths:
        if not path or not isinstance(path, str):
            errors.append(f"Invalid target path: {path}")
    
    # Validate zone summary matches resolved zones
    for path in wo.target_paths:
        resolved_zone = resolve_zone(path)
        declared_zone = wo.zone_summary.get(path)
        
        if declared_zone and declared_zone != resolved_zone:
            errors.append(f"Zone mismatch for {path}: declared={declared_zone}, resolved={resolved_zone}")
    
    # Validate risk level
    valid_risk_levels = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']
    if wo.risk_level not in valid_risk_levels:
        errors.append(f"Invalid risk level: {wo.risk_level}, must be one of {valid_risk_levels}")
    
    # Check rollback strategy for high-risk operations
    if wo.risk_level in ['HIGH', 'CRITICAL'] and not wo.rollback_strategy:
        errors.append(f"Rollback strategy required for {wo.risk_level} risk level")
    
    # Check for DANGER zone operations
    for path, zone in wo.zone_summary.items():
        if zone == 'DANGER':
            errors.append(f"DANGER zone operations are forbidden for autonomous agents: {path}")
    
    is_valid = len(errors) == 0
    return (is_valid, errors)


# ============================================================================
# SIP ENGINE (Safe Idempotent Patch)
# ============================================================================

def apply_sip_single_file(
    file_path: str,
    new_content: str,
    operation: str = "modify"
) -> Tuple[bool, Optional[str], Optional[str], Optional[str]]:
    """
    Apply SIP (Safe Idempotent Patch) for a single file.
    
    Algorithm (AI_OP_001_v5 Section 5.2):
    1. Read current state (if exists)
    2. Compute checksum before
    3. Create temp file
    4. Write full new content to temp
    5. Validate temp file
    6. Atomic move (mv temp target)
    7. Post-write verification
    8. Log checksums
    
    Args:
        file_path: Target file path
        new_content: New file content
        operation: Operation type (add/modify/delete)
    
    Returns:
        (success, checksum_before, checksum_after, temp_file_path)
    """
    # Resolve absolute path
    luka_root = Path(os.environ.get("LUKA_ROOT", os.environ.get("LUKA_SOT", Path.home() / "02luka")))
    if not Path(file_path).is_absolute():
        file_path = str(luka_root / file_path)
    
    path = Path(file_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    
    # Step 1: Read current state (if exists)
    checksum_before = None
    if path.exists() and operation != "add":
        checksum_before = compute_file_checksum(str(path))
    
    # Step 2: Create temp file
    temp_fd, temp_path = tempfile.mkstemp(
        suffix='.tmp',
        prefix=f'.clc_sip_{path.name}.',
        dir=str(path.parent)
    )
    
    try:
        # Step 3: Write full new content to temp
        with os.fdopen(temp_fd, 'w', encoding='utf-8') as f:
            f.write(new_content)
        
        # Step 4: Validate temp file (basic checks)
        # TODO: Add syntax validation for JSON/YAML/etc.
        temp_checksum = compute_file_checksum(temp_path)
        
        # Step 5: Atomic move
        if operation == "delete":
            # For delete, remove file
            if path.exists():
                path.unlink()
            os.unlink(temp_path)
            checksum_after = None
        else:
            # Atomic move
            shutil.move(temp_path, str(path))
            checksum_after = compute_file_checksum(str(path))
        
        return (True, checksum_before, checksum_after, temp_path)
    
    except Exception as e:
        # Cleanup on failure
        try:
            os.unlink(temp_path)
        except:
            pass
        raise Exception(f"SIP execution failed: {e}")


# ============================================================================
# FILE OPERATION PROCESSOR
# ============================================================================

def process_file_operation(
    op: Dict[str, Any],
    wo: WorkOrder
) -> Tuple[bool, FileOperation, List[str]]:
    """
    Process a single file operation from Work Order.
    
    Args:
        op: Operation dictionary
        wo: Work Order context
    
    Returns:
        (success, file_operation, errors)
    """
    errors = []
    file_op = FileOperation(
        path=op.get('path', ''),
        operation=op.get('operation', 'modify')
    )
    
    # Resolve absolute path
    luka_root = Path(os.environ.get("LUKA_ROOT", os.environ.get("LUKA_SOT", Path.home() / "02luka")))
    if not Path(file_op.path).is_absolute():
        file_op.path = str(luka_root / file_op.path)
    
    # Resolve zone
    file_op.zone = resolve_zone(file_op.path)
    
    # Sandbox check
    context = {
        'world': 'BACKGROUND',
        'wo_id': wo.wo_id,
        'zone': file_op.zone,
        'rollback_strategy': wo.rollback_strategy
    }
    
    sandbox_result = check_write_allowed(
        path=file_op.path,
        actor='CLC',
        operation='write',
        content=op.get('content'),
        context=context
    )
    
    if not sandbox_result.allowed:
        errors.append(f"Sandbox check failed: {sandbox_result.reason}")
        return (False, file_op, errors)
    
    # Apply SIP
    try:
        if file_op.operation == 'delete':
            # Delete operation
            if Path(file_op.path).exists():
                checksum_before = compute_file_checksum(file_op.path)
                Path(file_op.path).unlink()
                file_op.checksum_before = checksum_before
                file_op.checksum_after = None
            else:
                errors.append(f"File does not exist for delete: {file_op.path}")
                return (False, file_op, errors)
        
        elif file_op.operation in ['add', 'modify']:
            # Add/Modify operation
            content = op.get('content', '')
            if not content:
                errors.append(f"No content provided for {file_op.operation}: {file_op.path}")
                return (False, file_op, errors)
            
            success, checksum_before, checksum_after, temp_file = apply_sip_single_file(
                file_path=file_op.path,
                new_content=content,
                operation=file_op.operation
            )
            
            if not success:
                errors.append(f"SIP execution failed: {file_op.path}")
                return (False, file_op, errors)
            
            file_op.checksum_before = checksum_before
            file_op.checksum_after = checksum_after
            file_op.temp_file = temp_file
            file_op.content = content
        
        elif file_op.operation == 'move':
            # Move operation
            source = op.get('source_path', '')
            if not Path(source).is_absolute():
                source = str(luka_root / source)
            if not source:
                errors.append(f"No source_path for move: {file_op.path}")
                return (False, file_op, errors)
            
            file_op.source_path = source
            
            if Path(source).exists():
                checksum_before = compute_file_checksum(source)
                shutil.move(source, file_op.path)
                checksum_after = compute_file_checksum(file_op.path)
                file_op.checksum_before = checksum_before
                file_op.checksum_after = checksum_after
            else:
                errors.append(f"Source file does not exist: {source}")
                return (False, file_op, errors)
        
        file_op.validated = True
        return (True, file_op, errors)
    
    except Exception as e:
        errors.append(f"Operation failed: {e}")
        return (False, file_op, errors)


# ============================================================================
# ROLLBACK HANDLER
# ============================================================================

def apply_rollback(
    wo: WorkOrder,
    execution_result: ExecutionResult
) -> Tuple[bool, List[str]]:
    """
    Apply rollback strategy for a Work Order.
    
    Rollback strategies (AI_OP_001_v5 Section 4.3):
    - git_revert: Use git to revert changes
    - backup_restore: Restore from backup
    - manual_script: Execute rollback script
    - wo_rollback: Create new WO for rollback
    
    Args:
        wo: Work Order
        execution_result: Execution result with checksums
    
    Returns:
        (success, errors)
    """
    errors = []
    
    if not wo.rollback_strategy:
        errors.append("No rollback strategy defined")
        return (False, errors)
    
    strategy = wo.rollback_strategy.lower()
    
    if strategy == "git_revert":
        # Git revert
        try:
            import subprocess
            luka_root = Path(os.environ.get("LUKA_ROOT", os.environ.get("LUKA_SOT", Path.home() / "02luka")))
            # Get commit hash before changes (if available)
            # For now, use git restore
            for path in execution_result.files_modified:
                # Resolve relative path if needed
                if not Path(path).is_absolute():
                    rel_path = str(Path(path).relative_to(luka_root))
                else:
                    rel_path = str(Path(path).relative_to(luka_root))
                subprocess.run(['git', '-C', str(luka_root), 'restore', rel_path], check=True)
        except Exception as e:
            errors.append(f"Git revert failed: {e}")
            return (False, errors)
    
    elif strategy == "backup_restore":
        # Restore from backup
        # TODO: Implement backup restore logic
        errors.append("Backup restore not yet implemented")
        return (False, errors)
    
    elif strategy == "manual_script":
        # Execute rollback script
        # TODO: Implement script execution
        errors.append("Manual script rollback not yet implemented")
        return (False, errors)
    
    elif strategy == "wo_rollback":
        # Create new WO for rollback
        # TODO: Implement WO creation
        errors.append("WO rollback not yet implemented")
        return (False, errors)
    
    else:
        errors.append(f"Unknown rollback strategy: {wo.rollback_strategy}")
        return (False, errors)
    
    return (True, errors)


# ============================================================================
# MAIN EXECUTION ENGINE
# ============================================================================

def execute_work_order(wo_path: str) -> ExecutionResult:
    """
    Main execution function for Work Order.
    
    Execution flow (AI_OP_001_v5 Section 4.3):
    1. Read WO
    2. Validate WO
    3. Re-evaluate zones (defensive)
    4. Process each file operation (SIP)
    5. Post-write verification
    6. Log results
    7. Move WO to outbox
    
    Args:
        wo_path: Path to Work Order file
    
    Returns:
        ExecutionResult
    """
    start_time = datetime.now()
    wo = None
    execution_result = ExecutionResult(
        wo_id="",
        status=WOStatus.FAILED,
        files_modified=[],
        checksums={},
        execution_time=0.0,
        errors=[],
        warnings=[]
    )
    
    try:
        # Step 1: Read Work Order
        wo = read_work_order(wo_path)
        execution_result.wo_id = wo.wo_id
        wo.status = "VALIDATING"
        
        # Step 2: Validate Work Order
        is_valid, validation_errors = validate_work_order(wo)
        if not is_valid:
            execution_result.errors.extend(validation_errors)
            execution_result.status = WOStatus.FAILED
            return execution_result
        
        wo.status = "EXECUTING"
        
        # Step 3: Re-evaluate zones (defensive check)
        for path in wo.target_paths:
            resolved_zone = resolve_zone(path)
            if resolved_zone == "DANGER":
                execution_result.errors.append(f"DANGER zone detected: {path}")
                execution_result.status = WOStatus.FAILED
                return execution_result
        
        # Step 4: Process file operations
        file_operations = []
        
        if wo.operations:
            # Use detailed operations from WO
            for op in wo.operations:
                success, file_op, errors = process_file_operation(op, wo)
                if not success:
                    execution_result.errors.extend(errors)
                    # Continue processing other files
                    continue
                
                file_operations.append(file_op)
                execution_result.files_modified.append(file_op.path)
                if file_op.checksum_before and file_op.checksum_after:
                    execution_result.checksums[file_op.path] = (
                        file_op.checksum_before,
                        file_op.checksum_after
                    )
        else:
            # Fallback: Create operations from target_paths
            # This is a simplified mode - full WO should have operations
            execution_result.warnings.append("No operations specified, using target_paths only")
        
        # Step 5: Post-write verification
        for file_op in file_operations:
            if file_op.checksum_after:
                # Verify file exists and checksum matches
                if not Path(file_op.path).exists():
                    execution_result.errors.append(f"File missing after write: {file_op.path}")
                    continue
                
                current_checksum = compute_file_checksum(file_op.path)
                if current_checksum != file_op.checksum_after:
                    execution_result.errors.append(
                        f"Checksum mismatch for {file_op.path}: "
                        f"expected={file_op.checksum_after}, got={current_checksum}"
                    )
        
        # Step 6: Determine final status
        if execution_result.errors:
            execution_result.status = WOStatus.FAILED
            
            # Apply rollback if needed
            if wo.rollback_strategy:
                rollback_success, rollback_errors = apply_rollback(wo, execution_result)
                if rollback_success:
                    execution_result.status = WOStatus.ROLLED_BACK
                    execution_result.rollback_applied = True
                else:
                    execution_result.errors.extend(rollback_errors)
        else:
            execution_result.status = WOStatus.COMPLETED
            wo.status = "COMPLETED"
        
        # Step 7: Calculate execution time
        end_time = datetime.now()
        execution_result.execution_time = (end_time - start_time).total_seconds()
        
        # Step 8: Write audit log
        audit_log_path = write_audit_log(wo, execution_result)
        execution_result.audit_log_path = audit_log_path
        
        # Step 9: Move WO to outbox
        move_wo_to_outbox(wo_path, wo, execution_result)
        
        return execution_result
    
    except Exception as e:
        execution_result.errors.append(f"Execution failed: {e}")
        execution_result.status = WOStatus.FAILED
        if wo:
            wo.status = "FAILED"
        return execution_result


def write_audit_log(wo: WorkOrder, result: ExecutionResult) -> str:
    """Write audit log entry."""
    luka_root = Path(os.environ.get("LUKA_ROOT", os.environ.get("LUKA_SOT", Path.home() / "02luka")))
    log_dir = luka_root / "g" / "logs" / "clc_execution"
    log_dir.mkdir(parents=True, exist_ok=True)
    
    log_file = log_dir / f"clc_{wo.wo_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    
    audit_entry = {
        "wo_id": wo.wo_id,
        "timestamp": datetime.now().isoformat(),
        "status": result.status.value,
        "execution_time": result.execution_time,
        "files_modified": result.files_modified,
        "checksums": {
            path: {"before": before, "after": after}
            for path, (before, after) in result.checksums.items()
        },
        "errors": result.errors,
        "warnings": result.warnings,
        "rollback_applied": result.rollback_applied,
        "origin": wo.origin,
        "risk_level": wo.risk_level
    }
    
    with open(log_file, 'w', encoding='utf-8') as f:
        json.dump(audit_entry, f, indent=2)
    
    return str(log_file)


def move_wo_to_outbox(wo_path: str, wo: WorkOrder, result: ExecutionResult):
    """Move Work Order to outbox after execution."""
    wo_file = Path(wo_path)
    luka_root = Path(os.environ.get("LUKA_ROOT", os.environ.get("LUKA_SOT", Path.home() / "02luka")))
    
    if result.status == WOStatus.COMPLETED:
        outbox_dir = luka_root / "bridge" / "outbox" / "CLC" / "processed"
    else:
        outbox_dir = luka_root / "bridge" / "outbox" / "CLC" / "failed"
    
    outbox_dir.mkdir(parents=True, exist_ok=True)
    
    # Update WO with execution result
    wo_dict = asdict(wo)
    wo_dict['status'] = result.status.value
    wo_dict['execution_result'] = {
        'files_modified': result.files_modified,
        'checksums': {
            path: {"before": before, "after": after}
            for path, (before, after) in result.checksums.items()
        },
        'errors': result.errors,
        'warnings': result.warnings
    }
    
    outbox_file = outbox_dir / f"{wo.wo_id}.yaml"
    with open(outbox_file, 'w', encoding='utf-8') as f:
        yaml.dump(wo_dict, f, default_flow_style=False)
    
    # Remove from inbox
    wo_file.unlink()


# ============================================================================
# CLI INTERFACE
# ============================================================================

def main():
    """CLI entry point for CLC executor."""
    import argparse
    
    parser = argparse.ArgumentParser(
        description="CLC Enforcement Engine v5 — Background World Executor"
    )
    parser.add_argument("--wo", required=True, help="Path to Work Order file")
    parser.add_argument("--json", action="store_true", help="Output JSON")
    
    args = parser.parse_args()
    
    result = execute_work_order(args.wo)
    
    if args.json:
        output = {
            "wo_id": result.wo_id,
            "status": result.status.value,
            "files_modified": result.files_modified,
            "checksums": {
                path: {"before": before, "after": after}
                for path, (before, after) in result.checksums.items()
            },
            "execution_time": result.execution_time,
            "errors": result.errors,
            "warnings": result.warnings,
            "rollback_applied": result.rollback_applied,
            "audit_log_path": result.audit_log_path
        }
        print(json.dumps(output, indent=2))
    else:
        print(f"🔧 CLC EXECUTION RESULT:")
        print(f"   WO ID    : {result.wo_id}")
        print(f"   STATUS   : {result.status.value}")
        print(f"   FILES    : {len(result.files_modified)}")
        print(f"   TIME     : {result.execution_time:.2f}s")
        if result.errors:
            print(f"   ❌ ERRORS: {len(result.errors)}")
            for error in result.errors:
                print(f"      - {error}")
        if result.warnings:
            print(f"   ⚠️ WARNINGS: {len(result.warnings)}")
            for warning in result.warnings:
                print(f"      - {warning}")
        if result.audit_log_path:
            print(f"   📋 AUDIT : {result.audit_log_path}")


if __name__ == "__main__":
    main()

